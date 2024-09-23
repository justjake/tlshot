//
//  ScreencastOverlay.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 9/22/24.
//

import SwiftUI
import ScreenCaptureKit

class ScreencastOverlay: ObservableObject, ScreencastSessionDelegate {
    private let session = ScreencastSession()
    private let picker = SCContentSharingPicker.shared
    private var secureResource: URL?
    
    private var panelLocation: NSRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            print("no screen!?!?")
            return CGRect(square: 500)
        }
        
        return NSRect(x: 0, y: 0, width: screen.visibleFrame.width, height: 50)
    }
    
    private lazy var panel = OverlayPanel(panelLocation, level: .shieldWindow, visible: true) {
        ScreencastOverlayView(props: self, session: self.session)
    }
    
    private lazy var indicator: some NSPanel = WindowPicker.WindowPickerOverlay().panel

    
    @MainActor
    func show(content: SCContentFilter, cropRect: CGRect?) async throws {
        session.delegate = self
        try await session.update(filter: content, cropRect: cropRect)
        panel.orderFrontRegardless()
    }
    
    @MainActor
    func close() async throws {
        try await self.session.stopRecording()
    }
    
    func didWrite(url: URL) async throws {
        AppDelegate.shared.onSceencastComplete(screencastURL: url)
    }
    
    @MainActor
    func didClose() async throws {
        if let secureResource = secureResource {
            secureResource.stopAccessingSecurityScopedResource()
            self.secureResource = nil
        }
        self.indicator.close()
        self.panel.close()
        self.picker.isActive = false
        AppDelegate.shared.onScreencastClose()
    }
    
    @MainActor
    func didUpdate() async throws {
        if let frame = session.contentRect {
            indicator.setFrame(frame.isCG.asNS, display: true)
            indicator.orderFrontRegardless()
        } else {
            indicator.orderOut(nil)
        }
    }
    
    struct ScreencastOverlayView: View {
        @ObservedObject var props: ScreencastOverlay
        @StateObject var session = ScreencastSession()
        @EnvironmentObject var app: AppDelegate
        
        var body: some View {
            HStack {
                if session.isRecording {
                    Button("Stop recording") {
                        app.handleErrorsTask {
                            try await session.stopRecording()
                        }
                    }
                } else {
                    Button("Start recording") {
                        app.handleErrorsTask {
                            let saveFolder = try app.saveDirectory.getOrChooseSaveFolder()
                            props.secureResource = saveFolder
                            
                            _ = saveFolder.startAccessingSecurityScopedResource()
                            let url = saveFolder.appendingPathComponent(app.getVideoName(), conformingTo: .mpeg4Movie)
                            try await session.startRecording(url: url)
                        }
                    }
                    
                    Button("Pick window...") {
                        session.presentPicker(newStyle: .window, config: nil)
                    }
                    
                    Button("Pick display...") {
                        session.presentPicker(newStyle: .display, config: nil)
                    }
                    
                    Button("Record presenter...") {
                        app.handleErrorsTask {
                            try await session.capturePresenter()
                            session.presentPickerForPresenterOverlay()
                        }
                    }
                    
                    Button("Cancel") {
                        session.close()
                    }
                }
                
                if let captureSession = session.presenterCaptureSession {
                    PresenterCaptureView(captureSession: captureSession)
                }
            }
            .background(.gray)
        }
    }
}
