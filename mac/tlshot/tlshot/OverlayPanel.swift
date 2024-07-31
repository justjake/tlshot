//
//  TargetHighlightWindow.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/11/24.
//

import Foundation
import AppKit
import SwiftUI

extension NSWindow.Level {
    public static var shieldWindow: NSWindow.Level {
        NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
    }
}

var cursorDebugCount = 0
var cursorDebugTime = Date.now

func nextCursorDebugPrefix() -> String {
    cursorDebugCount += 1
    cursorDebugTime = Date.now
    let currentEvent = NSApp.currentEvent.debug ?? "(?event?)"
    return "[\(cursorDebugCount) \(cursorDebugTime) \(currentEvent)]"
}

func printCursorUpdateInfo(window: NSWindow, eventName: String) {
    let prefix = nextCursorDebugPrefix()
    print("\(prefix) \(window)@\(window.frame): \(eventName)")
    AppDelegate.shared.debugWindows()
    Thread.callStackSymbols.forEach { print("\(prefix) \($0)") }
}

func printCursorUpdateInfo(cursor: NSCursor, eventName: String) {
    let prefix = nextCursorDebugPrefix()
    print("\(prefix) \(cursor.debugName): \(eventName)")
    Thread.callStackSymbols.forEach { print("\(prefix) \($0)") }
}

func swizzleMethod(_ klass: AnyClass, newMethod: Selector, originalMethod: Selector) {
    let originalMethod = class_getInstanceMethod(klass, originalMethod)
    let swizzledMethod = class_getInstanceMethod(klass, newMethod)
    method_exchangeImplementations(originalMethod!, swizzledMethod!)
}

extension NSCursor {
    @objc func _tracked_set() {
        printCursorUpdateInfo(cursor: self, eventName: "NSCursor.set")
        _tracked_set()
    }
    
    @objc func _tracked_push() {
        printCursorUpdateInfo(cursor: self, eventName: "NSCursor.push")
        _tracked_push()
    }
    
    @objc func _tracked_pop() {
        printCursorUpdateInfo(cursor: self, eventName: "NSCursor.pop")
        _tracked_pop()
    }

    static func swizzle() {
        swizzleMethod(self, newMethod: #selector(NSCursor._tracked_set),  originalMethod: #selector(NSCursor.set))
        swizzleMethod(self, newMethod: #selector(NSCursor._tracked_push), originalMethod: #selector(NSCursor.push))
        swizzleMethod(self, newMethod: #selector(NSCursor._tracked_pop),  originalMethod: #selector(NSCursor.pop))
    }
}

/// Debug cursorUpdate calls
extension NSWindow {
    @objc func _tracked_cursorUpdate(with event: NSEvent) {
        printCursorUpdateInfo(window: self, eventName: "NSWindow.cursorUpdate")
        // We'll end up swapping...
        _tracked_cursorUpdate(with: event)
    }
    
    // https://medium.com/@pallavidipke07/method-swizzling-in-swift-5c9d9ab008e4
    static func swizzle() {
        let originalSelector = #selector(NSWindow.cursorUpdate(with:))
        let originalMethod = class_getInstanceMethod(self, originalSelector)
        
        let swizzledSelector = #selector(NSWindow._tracked_cursorUpdate(with:))
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
        
        method_exchangeImplementations(originalMethod!, swizzledMethod!)
    }
}



class NSWindowWithCursorLogging: NSWindow {
//    override func cursorUpdate(with event: NSEvent) {
//        printCursorUpdateInfo(window: self, eventName: "cursorUpdate")
//        super.cursorUpdate(with: event)
//    }
}

class FirstClickHostingView<Content>: NSHostingView<Content> where Content : View {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
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
        if !visible {
            orderOut(nil)
        }
        
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
            .environmentObject(AppDelegate.shared)
        
        let hostingView = FirstClickHostingView(rootView: newView)
        hostingView.setFrameSize(contentRect.size)
        contentView = hostingView
    }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // No constraint.
        return frameRect
    }
    
//    override func cursorUpdate(with event: NSEvent) {
//        guard let cursor = AppDelegate.shared.desiredCursor else {
//            super.cursorUpdate(with: event)
//            return
//        }
//        printCursorUpdateInfo(window: self, eventName: "OverlayPanel.cursorUpdate")
//        cursor.set()
//    }
    
//    override func becomeKey() {
//        print("\(self).super.becomeKey")
//        super.becomeKey()
//        print("\(self).becomeKey")
//        AppDelegate.shared.desiredCursor?.set()
//    }
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

