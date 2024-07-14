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
    
    /// Don't include in own screenshots
    override var includeInScreenshot: Bool { false }

    init(
        contentRect: NSRect,
        level: NSWindow.Level = .normal,
        visible: Bool = true,
        view: (NSPanel) -> Content
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        
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
        ///   re-evaluating per https://stackoverflow.com/questions/15077471/show-window-without-activating-keep-application-below-it-active#comment112101726_15079362
//        hidesOnDeactivate = true
        
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
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // No constraint.
        return frameRect
    }
}

extension NSEvent.EventTypeMask {
    static var leftMouse: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged]
}

class ScreenChangeMonitor {
    var onEvent: () -> Void
    private var observer: Any?
    init(_ onEvent: @escaping ()->Void) {
        self.onEvent = onEvent
    }
    
    func start() {
        self.observer = observer
        ?? NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApp,
            queue: OperationQueue.main
        ) {_ in
            self.onEvent()
        }
    }
    
    func stop() {
        if let observer = self.observer  {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }

    }
    
    deinit {
        stop()
    }
}

class EventMonitor {
    let mask: NSEvent.EventTypeMask
    var onEvent: (NSEvent) -> NSEvent?
    
    convenience init (
        _ mask: NSEvent.EventTypeMask,
        monitorEvent: @escaping (NSEvent) -> Void
    ) {
        self.init(mask) {
            monitorEvent($0)
            return $0
        }
    }
    
    init(
        _ mask: NSEvent.EventTypeMask,
        cancelOrModifyEvent: @escaping (NSEvent) -> NSEvent?
    ) {
        self.mask = mask
        self.onEvent = cancelOrModifyEvent
    }
    
    private var systemMonitor: Any? = nil
    
    func start() {
        let localMonitor = systemMonitor ?? NSEvent.addLocalMonitorForEvents(matching: mask, handler: onEvent)
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

