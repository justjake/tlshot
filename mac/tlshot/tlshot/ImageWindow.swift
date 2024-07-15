//
//  ImageWindow.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/13/24.
//

import AppKit
class ImageWindow: NSWindow {
    init(rect: CGRect, image: CGImage) {
        super.init(
            contentRect: rect,
            styleMask: [.closable, .resizable, .titled],
            backing: .buffered,
            defer: false
        )
        
        title = "Image Preview"
        isReleasedWhenClosed = false
        
        let imageView = NSImageView(image: NSImage(cgImage: image, size: NSSize(width: image.width * 2, height: image.height * 2)))
        contentView = imageView
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




