//
//  PresenterCapture.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 9/21/24.
//

import Foundation
import AVKit
import SwiftUI

class PresenterCapture {
    func authorize(for type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: type)
        case .restricted:
            return false
        case .denied:
            return false
        case .authorized:
            return true
        @unknown default:
            return false
        }
    }
    
    func camera() throws -> AVCaptureDevice {
        guard let camera = AVCaptureDevice.default(for: .video) else {
            throw TlshotError.captureFailed("No video camera")
        }
        return camera
    }
    
    func microphone() throws -> AVCaptureDevice {
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            throw TlshotError.captureFailed("No microphone")
        }
        return microphone
    }
    
    func setupCaptureSession() throws -> AVCaptureSession {
        let captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        captureSession.sessionPreset = .hd1920x1080

        let camera = try camera()
        let videoInput = try AVCaptureDeviceInput(device: camera)
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let microphone = try microphone()
        let micInput = try AVCaptureDeviceInput(device: camera)
        if captureSession.canAddInput(micInput) {
            captureSession.addInput(micInput)
        }
        
//        let output = AVCaptureMovieFileOutput()
//        if captureSession.canAddOutput(output) {
//            captureSession.addOutput(output)
//        }
        
        return captureSession
    }
}

struct PresenterCaptureView: NSViewRepresentable {
    @ObservedObject var props: PresenterCaptureOverlay
    typealias NSViewType = CaptureNSView

    func makeNSView(context: Context) -> NSViewType {
        let view = NSViewType()
        view.session = props.captureSession
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.session = props.captureSession
    }
    
    final class CaptureNSView: NSView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        
        var session: AVCaptureSession? {
            get { previewLayer?.session }
            set {
                previewLayer = previewLayer ?? setupPreviewLayer()
                previewLayer?.session = newValue
            }
        }
        
        private func setupPreviewLayer() -> AVCaptureVideoPreviewLayer {
            let newLayer = AVCaptureVideoPreviewLayer()
            self.layer = newLayer
            self.wantsLayer = true
            return newLayer
        }
    }
    
}

class PresenterCaptureOverlay: ObservableObject {
    static let shared = PresenterCaptureOverlay()
    
    @Published var captureSession: AVCaptureSession?
    var helper = PresenterCapture()
    
    lazy var panel = OverlayPanel(NSRect(origin: .zero, size: CGSize(square: 400)), level: .shieldWindow) {
        PresenterCaptureView(props: self)
    }
    
    @MainActor func show() throws {
        try captureSession = captureSession ?? helper.setupCaptureSession()
        panel.orderFront(nil)
        captureSession?.startRunning()
    }
    
    @MainActor func hide() {
        captureSession?.stopRunning()
        panel.orderOut(nil)
    }
}

