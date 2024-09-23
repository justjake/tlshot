//
//  ScreencastOverlay.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 9/22/24.
//

import SwiftUI

class ScreencastOverlay: ObservableObject {
    var panel = OverlayPanel(NSScreen.main?.visibleFrame ?? CGRect(square: 500), level: .shieldWindow, visible: true) {
        ScreencastOverlayView()
    }
    
    struct ScreencastOverlayView: View {
        @StateObject var session = ScreencastSession()
        @EnvironmentObject var app: AppDelegate
        @State var cropRect = CGRect(center: NSScreen.main?.visibleFrame.center ?? .zero, size: CGSize(square: 800)).isNS.asCG
        
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
                    let content = try await ScreenshotService.shared.scContentFilter(cropRect.isCG)
                    try await session.update(filter: content, cropRect: cropRect)
                }
            }
        }
    }
}
