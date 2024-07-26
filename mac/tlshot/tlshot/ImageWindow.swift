//
//  ImageWindow.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/13/24.
//

import AppKit
import SwiftUI

class ImageDisplayWindow: NSWindow {
    init(rect: CGRect, image: NSImage) {
        super.init(
            contentRect: rect,
            styleMask: [.closable, .resizable, .titled],
            backing: .buffered,
            defer: false
        )
        
        title = "Image Preview"
        let imageView = NSImageView(image: image)
        contentView = imageView
        
        isReleasedWhenClosed = false
    }
}

class ImageEditWindow: NSWindow {
    init(rect: CGRect, image: CGImage, name: String) {
        super.init(
            contentRect: rect,
            styleMask: [.closable, .resizable, .titled, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        title = name
        
        let bridge = Bridge()
        bridge.imageName = name
        bridge.assetServer.add(image: image)
        let view = ImageEditView(bridge: bridge, window: self, imageName: name).environmentObject(AppDelegate.shared)
        contentView = NSHostingView(rootView: view)
    }
    
    override var canBecomeKey: Bool {
        true
    }
    
    override var canBecomeMain: Bool {
        true
    }
    
    override func close() {
        AppDelegate.shared.removeImageWindow(self)
        super.close()
    }
}

struct ImageEditView: View {
    @EnvironmentObject var app: AppDelegate
    @StateObject var bridge: Bridge
    var window: NSWindow
    var imageName: String
    
    var body: some View {
        TldrawWebView(bridge: bridge)
            .expand()
            .toolbar {
                TlshotToolbar(
                    onCaptureWindow: withErrorHandling(onCaptureWindow),
                    onCaptureArea: withErrorHandling(onCaptureArea),
                    onCopyAndDelete: withErrorHandling(onCopyAndDelete),
                    onDelete: withErrorHandling(onDelete),
                    onSave: withErrorHandling(onSave)
                )
            }
    }
    
    private func onCaptureWindow() async throws {
        
    }
    
    private func onCaptureArea() async throws {
        
    }
    
    private func onCopyAndDelete() async throws {
        let data = try await getImageData()
        let notification = Notif.CopyAndClose(imageName: imageName, pngImageData: data)
        notification.copyToClipboard()
        switch app.afterSaveAction {
        case .showNotification:
            try await notification.sendNotification()
        case .revealInFinder:
            break
        case .showNotificationAndCopy:
            try await notification.sendNotification()
        case .none:
            break
        }
    }
    
    private func onDelete() async throws {
        window.close()
    }
    
    private func onSave() async throws {
        try await save()
        window.close()
    }
    
    private func withErrorHandling(_ block: @escaping () async throws -> Void) -> () -> Void {
        return { handleErrors(block: block) }
    }
    
    private func getImageData() async throws -> Data {
        let img = try await bridge.getPng()
        guard let data = img.cgImage()?.png else {
            throw TlshotError.invalidData("Cannot create PNG data")
        }
        return data
    }
    
    private func save() async throws {
        try await app.saveImage(name: imageName, data: getImageData())
    }
    
    private func handleErrors(block: @escaping () async throws -> Void) {
        Task {
            do {
                try await block()
            } catch {
                await app.showErrorAlert(error: error, for: window)
            }
        }
    }
}




