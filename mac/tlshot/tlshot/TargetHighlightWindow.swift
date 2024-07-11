//
//  TargetHighlightWindow.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/11/24.
//

import Foundation
import AppKit
import SwiftUI

extension NSApplication {
    var tlDelegate: AppDelegate {
        self.delegate! as! AppDelegate
    }
}

extension NSWindow.Level {
    var shieldWindow: NSWindow.Level {
        NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
    }
}

/// Base class for borderless, invisible windows that render a SwiftUI view
class CaptureOverlayWindow<Content: View>: NSPanel {
    init(
        contentRect: NSRect,
        level: NSWindow.Level = .normal,
        view: (NSPanel) -> Content
    ) {
        super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false)
        
        isFloatingPanel = true
        self.level = level
        
        /// Allow the pannel to be overlaid in a fullscreen space
        collectionBehavior.insert(.fullScreenAuxiliary)
        
        /// A few more things.
        collectionBehavior.insert(.canJoinAllApplications)
        collectionBehavior.insert(.canJoinAllSpaces)
        
        /// Don't show a window title, even if it's set
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        
        /// Hide when unfocused
        hidesOnDeactivate = true
        
        /// Hide all traffic light buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        /// Don't show any window background
        backgroundColor = .clear
        
        /// By default our panel windows shouldn't have animation
        animationBehavior = .none
        
        /// Set the content view.
        /// The safe area is ignored because the title bar still interferes with the geometry
        let newView = view(self)
            .ignoresSafeArea()
            .environmentObject(NSApp.tlDelegate)
        
        let hostingView = NSHostingView(rootView: newView)
        hostingView.setFrameSize(contentRect.size)
        contentView = hostingView
    }
}
