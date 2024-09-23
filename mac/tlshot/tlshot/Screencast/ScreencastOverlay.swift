//
//  ScreencastOverlay.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 9/22/24.
//

import SwiftUI
import ScreenCaptureKit

class ScreencastOverlay: ObservableObject {
    @Published var content: SCContentFilter?
    @Published var cropRect: CGRect?
    
    func show(content: SCContentFilter?, cropRect: CGRect?) {
        self.content = content
        self.cropRect = cropRect
        if let cropRect = cropRect ?? content?.contentRect {
            indicator.setFrame(cropRect.isCG.asNS, display: true)
            indicator.orderFrontRegardless()
        }
        panel.orderFrontRegardless()
    }
    
    func close() {
        self.indicator.close()
        self.panel.close()
    }
    
    var panelLocation: NSRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            print("no screen!?!?")
            return CGRect(square: 500)
        }
        
        return NSRect(
            x: 0, y: 0, width: screen.visibleFrame.width, height: 50
        )
    }
    
    lazy var panel = OverlayPanel(panelLocation, level: .shieldWindow, visible: true) {
        ScreencastOverlayView(props: self)
    }
    
    lazy var indicator: some NSPanel = WindowPicker.WindowPickerOverlay().panel
    
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
                            _ = saveFolder.startAccessingSecurityScopedResource()
                            let url = saveFolder.appendingPathComponent(app.getVideoName(), conformingTo: .mpeg4Movie)
                            
                            session.cleanup = { didFinish in
                                saveFolder.stopAccessingSecurityScopedResource()
                                if didFinish {
                                    app.onSceencastComplete(screencastURL: url)
                                }
                            }
                            
                            try await session.startRecording(url: url)
                        }
                    }
                    
                    Button("Pick window...") {
                        session.presentPicker(newStyle: .window)
                    }
                    
                    Button("Pick display...") {
                        session.presentPicker(newStyle: .display)
                    }
                    
                    Button("Record presenter...") {
                        app.handleErrorsTask {
                            try await session.capturePresenter()
                            session.presentPicker(newStyle: nil)
                        }
                    }
                    
                    Button("Cancel") {
                        session.cancelPresenter(didFinish: false)
                        app.onScreencastCancel()
                    }
                }
                
                if let captureSession = session.presenterCaptureSession {
                    PresenterCaptureView(captureSession: captureSession)
                }
            }
            .background(.gray)
            .onAppear {
                app.handleErrorsTask {
                    if let content = props.content {
                        try await session.update(filter: content, cropRect: props.cropRect)
                    } else {
                        let content = try await ScreenshotService.shared.scContentFilter()
                        try await session.update(filter: content, cropRect: props.cropRect)
                    }
                }
            }
        }
    }
}
