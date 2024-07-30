//
//  ImageWindow.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/13/24.
//

import AppKit
import SwiftUI

class ImageDisplayWindow: NSWindowWithCursorLogging {
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

extension NSWindow {
    func setContentFrame(_ rect: NSRect, animate: Bool = false) {
        let frameRect = frameRect(forContentRect: rect)
        setFrame(frameRect, display: true, animate: animate)
    }
}

class ImageEditWindow: NSWindowWithCursorLogging {
    func waitForRender() async {
        await bridge.renderWaiter.wait()
    }
    
    private var bridge: Bridge
    
    init(rect: CGRect) {
        let bridge = Bridge()
        self.bridge = bridge
        
        super.init(
            contentRect: rect,
            styleMask: [.closable, .resizable, .titled, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        let view = ImageEditView(bridge: bridge, window: self).environmentObject(AppDelegate.shared)
        contentView = NSHostingView(rootView: view)
    }
    
    @MainActor
    func addInitialImage(image: CGImage, name: String, frame: CGRect) async throws {
        title = name
        setContentFrame(frame)
        
        bridge.imageName = name
        try await bridge.addImageToCanvas(image)
        try await bridge.zoomToFit()
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
    
    private func onCapture(_ action: CaptureAction) async throws {
        let result = try await app.performCapture(action)
        try await bridge.addImageToCanvas(result.image)
        guard let screen = window.screen else {
            return
        }
        
        let contentRect = window.contentRect(forFrameRect: window.frame)
        var newContentRect = CGRect(
            origin: contentRect.origin,
            size: .init(
                width: min(
                    contentRect.width + BridgeEnvironment.assetOffset + result.frame.width,
                    screen.visibleFrame.width
                ),
                height: min(
                    max(contentRect.height, result.frame.height),
                    screen.visibleFrame.height
                )
            )
        )
        var newFrame = window.frameRect(forContentRect: newContentRect)
        if newFrame.maxX > screen.visibleFrame.maxX {
            newFrame = CGRect(center: screen.visibleFrame.center, size: newFrame.size)
        }
        window.setFrame(newFrame, display: true, animate: false)
        try await bridge.waitForResize(timeoutMS: 100)
        try await bridge.zoomToFit(inset: true, animate: true, delayMS: 0)
    }
    
    private func onCaptureWindow() async throws {
        try await onCapture(.window)
    }
    
    private func onCaptureArea() async throws {
        try await onCapture(.area)
    }
    
    private func onCopyAndDelete() async throws {
        let data = try await getImageData()
        let notification = Notif.CopyAndClose(imageName: bridge.imageName, pngImageData: data)
        notification.copyToClipboard()
        try await onDelete()
        
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
        try await app.saveImage(name: bridge.imageName, data: getImageData())
    }
    
    private func handleErrors(block: @escaping () async throws -> Void) {
        Task {
            do {
                try await block()
            } catch {
                if error as? TlshotError == TlshotError.captureCancelled {
                    // It's okay if the user cancelled a capture
                    return
                }
                
                await app.showErrorAlert(error: error, for: window)
            }
        }
    }
}




