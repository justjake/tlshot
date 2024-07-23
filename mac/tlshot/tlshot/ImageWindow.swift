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
    var bridge: Bridge?
    
    init(rect: CGRect, image: CGImage) {
        super.init(
            contentRect: rect,
            styleMask: [.closable, .resizable, .titled],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        title = "Image Editor"
        
        let ourBridge = Bridge()
        let assetURL = ourBridge.assetServer.add(image: image)

        let view = TldrawWebView(bridge: ourBridge)
            .expand()
        
//        Task {
//            do {
//                let result = try await ourBridge.saveReq(.init(saveID: "0"))
//                print("XXX: save \(result)")
//
//                let nextWindow = ImageDisplayWindow(rect: self.frame, image: result.1)
//                AppDelegate.shared.imageWindows.append(nextWindow)
//                nextWindow.orderFront(nil)
//                nextWindow.becomeMain()
//            } catch {
//                print("XXX: error wit image \(error)")
//            }
//        }
        
        bridge = ourBridge
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




