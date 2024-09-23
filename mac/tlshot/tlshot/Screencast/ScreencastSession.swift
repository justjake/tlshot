//
//  ScreencastSession.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 9/22/24.
//

import ScreenCaptureKit

protocol ScreencastSessionDelegate {
    func didWrite(url: URL) async throws
    func didClose() async throws
    func didUpdate() async throws
}

class ScreencastSession: NSObject, ObservableObject, SCContentSharingPickerObserver, SCStreamDelegate {
    var delegate: ScreencastSessionDelegate?
    
    @Published var stream: SCStream?
    @Published var isCapturing = false
    @Published var isRecording = false
    @Published var hasPresenterOverlay = false
    
    var source: SCContentFilter?
    var cropRect: CGRect?
    var config: SCStreamConfiguration?
    var recorder: ScreenRecorder?
    
    @Published var presenterCaptureSession: AVCaptureSession?
    
    var contentRect: CGRect? {
        cropRect ?? source?.contentRect
    }
    
    var recordAudio = false
    var videoFormat: RecordMode = .h264_sRGB
    
    override init() {
        super.init()
        SCContentSharingPicker.shared.add(self)
    }
    
    @MainActor
    func capturePresenter() async throws {
        if presenterCaptureSession == nil {
            let helper = PresenterCapture()
            let isAuthorized = await helper.authorize(for: .video)
            if isAuthorized {
                let aVCaptureSession = try helper.setupCaptureSession()
                aVCaptureSession.startRunning()
                self.presenterCaptureSession = aVCaptureSession
            } else {
                print("Not authorized to capture presenter")
            }
        }
    }
    
    func presentPickerForPresenterOverlay() {
        var config = SCContentSharingPickerConfiguration()
        config.allowedPickerModes = []
        config.allowsChangingSelectedContent = false
        config.excludedBundleIDs = [NSRunningApplication.current.bundleIdentifier].compactMap { $0 }
        presentPicker(newStyle: nil, config: config)
    }
    
    func presentPicker(newStyle: SCShareableContentStyle?, config: SCContentSharingPickerConfiguration?) {
        let picker = SCContentSharingPicker.shared
        picker.isActive = true
        
        if let stream = stream {
            picker.setConfiguration(config, for: stream)
            picker.present(for: stream)
        } else {
            let style = newStyle ?? source?.style ?? .display
            print("picker.present(using: \(style))")
            picker.present(using: style)
        }
    }
    
    func update(filter: SCContentFilter, cropRect: CGRect?) async throws {
        try await updateStream(newStream: nil, newContentFilter: filter, cropRect: cropRect, close: false)
    }
    
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        print("contentSharingPicker didCancelFor:", stream.debug ?? "nil")
        // TODO: ???
    }
    
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        updateStream(newStream: stream, newContentFilter: filter, cropRect: nil, close: true)
    }
    
    func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        print("contentSharingPickerStartDidFailWithError:", error)
        Task { @MainActor in AppDelegate.shared.onCaptureError(error) }
    }
    
    func outputVideoEffectDidStart(for stream: SCStream) {
        print("hasPresenterOverlay=true", stream == self.stream)
        if stream == self.stream {
            Task { @MainActor in
                hasPresenterOverlay = true
            }
        }
    }
    
    func outputVideoEffectDidStop(for stream: SCStream) {
        print("hasPresenterOverlay=false", stream == self.stream)
        if stream == self.stream {
            Task { @MainActor in
                hasPresenterOverlay = false
            }
        }
    }
    
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor in
            
            // The stream already stopped, we shouldn't try to stop it ourselves.
            isCapturing = false
            
            if let error = error as? SCStreamError, error.code == .userStopped {
                // User explicitly stopped, no need to report an error
            } else {
                // Unexpected.
                AppDelegate.shared.onCaptureError(error)
            }
            
            await AppDelegate.shared.handleErrors {
                try await self.stopRecording()
            }
        }
    }
    
    private func updateStream(newStream: SCStream?, newContentFilter: SCContentFilter, cropRect: CGRect?, close: Bool) {
        Task {
            await AppDelegate.shared.handleErrors {
                try await self.updateStream(newStream: newStream, newContentFilter: newContentFilter, cropRect: cropRect, close: close)
            }
        }
    }

    @MainActor
    private func updateStream(newStream: SCStream?, newContentFilter: SCContentFilter, cropRect: CGRect?, close: Bool) async throws {
        defer {
            if close {
                SCContentSharingPicker.shared.isActive = false
            }
        }
        
        if isRecording {
            print("ScreencastSession: cannot update during recording")
            return
        }
        
        print("ScreencastSession.updateStream: existing=\(stream.debug ?? "nil") newStream=\(newStream.debug ?? "nil")")
        
        self.source = newContentFilter
        self.cropRect = cropRect
        let config = ScreenRecorder.streamConfiguration(for: newContentFilter, cropRect: cropRect, recordAudio: recordAudio, videoFormat: videoFormat)
        self.config = config

        let initialStream = self.stream
        let stream = newStream ?? self.stream ?? SCStream(filter: newContentFilter, configuration: config, delegate: self)
        self.stream = stream
        
        if initialStream != nil {
            // Update stream
            try await stream.updateConfiguration(config)
            try await stream.updateContentFilter(newContentFilter)
        }
        try await self.setupRecorder(stream: stream, config: config)
        try await self.delegate?.didUpdate()
    }
    
    @MainActor
    private func setupRecorder(stream: SCStream, config: SCStreamConfiguration) async throws {
        guard let recorder = self.recorder else {
            let newRecorder = try await ScreenRecorder(config: config, mode: videoFormat)
            try newRecorder.setInput(stream: stream)
            self.recorder = newRecorder
            try await stream.startCapture()
            isCapturing = true
            return
        }
        
        if recorder.stream != stream {
            throw RecordingError("Cannot change stream")
        }
        
        try recorder.update(config: config, videoFormat: videoFormat)
    }
    
    @MainActor
    func startRecording(url: URL) async throws {
        print("\(self).startRecording")
        guard let recorder = self.recorder else {
            throw RecordingError("Stream not configured")
        }
        try await recorder.startRecording(url: url)
        isRecording = true
    }
    
    @MainActor
    func stopRecording() async throws {
        print("\(self).stopRecording")
        if isCapturing {
            try await self.stream?.stopCapture()
            isCapturing = false
        }
        if isRecording {
            guard let recorder = recorder else {
                throw RecordingError("Unexpected state: isRecording, but no recorder")
            }
            let url = try await recorder.stopRecording()
            isRecording = false
            try await delegate?.didWrite(url: url)
        }
        close()
    }
    
    @MainActor
    func close() {
        presenterCaptureSession?.stopRunning()
        presenterCaptureSession = nil
        SCContentSharingPicker.shared.remove(self)
        SCContentSharingPicker.shared.isActive = false
        AppDelegate.shared.handleErrorsTask {
            try await self.delegate?.didClose()
        }
    }
}
