//
//  TargetHighlightWindow.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/11/24.
//

import Foundation
import AppKit
import SwiftUI

extension NSWindow {
    var appDelegate: AppDelegate {
        AppDelegate.shared
    }
}

extension NSWindow.Level {
    public static var shieldWindow: NSWindow.Level {
        NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
    }
}

/// Base class for borderless, invisible windows that render a SwiftUI view
/// https://cindori.com/developer/floating-panel
class OverlayPanel<Content: View>: NSPanel {
    convenience init(
        _ contentRect: NSRect,
        level: NSWindow.Level = .normal,
        visible: Bool = true,
        view: () -> Content
    ) {
        self.init(
            contentRect: contentRect,
            level: level,
            visible: visible,
            view: { _ in view() }
        )
    }
    
    convenience init(
        contentRect: NSRect,
        level: NSWindow.Level = .normal,
        visible: Bool = true,
        view: () -> Content
    ) {
        self.init(
            contentRect: contentRect,
            level: level,
            visible: visible,
            view: { _ in view() }
        )
    }

    init(
        contentRect: NSRect,
        level: NSWindow.Level = .normal,
        visible: Bool = true,
        view: (NSPanel) -> Content
    ) {
        super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false)
        
        isFloatingPanel = true
        self.level = level
        setIsVisible(visible)
        
        /// https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior
        collectionBehavior = [
            // Stage Manager & full screen
            .canJoinAllApplications,
            
            // Spaces
            .canJoinAllSpaces,
            
            // Mission Control
            .stationary,
            
            // No cmd-tilde for special windows
            .ignoresCycle
        ]
        /// Allow the pannel to be overlaid in a fullscreen space
//        collectionBehavior.insert(.fullScreenAuxiliary)
//        
//        /// A few more things.
//        collectionBehavior.insert(.canJoinAllApplications)
//        collectionBehavior.insert(.canJoinAllSpaces)
        
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
            .environmentObject(appDelegate)
        
        let hostingView = NSHostingView(rootView: newView)
        hostingView.setFrameSize(contentRect.size)
        contentView = hostingView
    }
    
//    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
//        // No constraint.
//        // Doesn't seem to work?
//        return frameRect
//    }
}


class MouseMonitor {
    static let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged]
    
    var onEvent: (NSEvent) -> Void
    
    init(_ handler: @escaping (NSEvent) -> Void) {
        onEvent = handler
    }
    
    private var systemMonitor: Any? = nil
    
    func start() {
        let handler = self.onEvent
        let localMonitor = systemMonitor ?? NSEvent.addLocalMonitorForEvents(matching: Self.mask) {
            handler($0)
            return $0
        }
        systemMonitor = localMonitor
    }
    
    func stop() {
        if let monitor = self.systemMonitor {
            NSEvent.removeMonitor(monitor)
            self.systemMonitor = nil
        }
    }
    
    deinit {
        stop()
    }
}
