//
//  ImageWindow.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/13/24.
//

import AppKit
import SwiftUI

class ImageWindow: NSWindow {
    var bridge: Bridge?
    
    init(rect: CGRect, image: CGImage, edit: Bool) {
        
        super.init(
            contentRect: rect,
            styleMask: [.closable, .resizable, .titled],
            backing: .buffered,
            defer: false
        )
        
        isReleasedWhenClosed = false
        if edit {
            title = "Image Editor"
            
            let ourBridge = Bridge()
            ourBridge.assetServer.add(image: image)

            let view = TldrawWebView(bridge: ourBridge)
                .expand()
            
            Task {
                do {
                    let result = try await ourBridge.saveReq(.init(saveID: "0"))
                    print("XXX: save \(result)")

                    let nextWindow = ImageWindow(rect: self.frame, image: result.1.cgImage(forProposedRect: nil, context: nil, hints: nil)!, edit: false)
                    AppDelegate.shared.imageWindows.append(nextWindow)
                    nextWindow.orderFront(nil)
                    nextWindow.becomeMain()
                    
                } catch {
                    print("XXX: error wit image \(error)")
                }
            }
            
            bridge = ourBridge
            contentView = NSHostingView(rootView: view)
        } else {
            title = "Image Preview"
            let imageView = NSImageView(image: NSImage(cgImage: image, size: NSSize(width: image.width * 2, height: image.height * 2)))
            contentView = imageView
        }
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




