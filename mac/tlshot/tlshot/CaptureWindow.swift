//
//  CaptureWindow.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/11/24.
//

import Foundation
import AppKit
import SwiftUI

// https://cindori.com/developer/floating-panel
class CaptureWindow: NSPanel {
    static var id = 0
    static func nextId() -> Int {
        id += 1
        return id
    }
    
    let id = CaptureWindow.nextId()
    let appDelegate: AppDelegate
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var localMouseMonitor: Any? = nil
    
    init(appDelegate: AppDelegate,
         view: (CaptureWindow) -> CaptureView,
         contentRect: NSRect,
         backing: NSWindow.BackingStoreType = .buffered,
         defer flag: Bool = false
    ) {
        self.appDelegate = appDelegate
        
        
        /// Init the window as usual
        super.init(contentRect: contentRect,
                   styleMask: [ .borderless, ],
                   backing: backing,
                   defer: flag)
        
        /// Allow the panel to be on top of other windows
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGShieldingWindowLevel()))
        
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
        
        // Don't show any window background
        backgroundColor = NSColor(white: 0, alpha: 0.1)

        /// Sets animations accordingly
        animationBehavior = .utilityWindow
        
        /// Set the content view.
        /// The safe area is ignored because the title bar still interferes with the geometry
        let newView = view(self)
            .ignoresSafeArea()
            .environmentObject(appDelegate)
        
        let hostingView = NSHostingView(rootView: newView)
        hostingView.setFrameSize(contentRect.size)
        contentView = hostingView
        
        startMouseMonitors()
    }
    
    override func becomeKey() {
        startMouseMonitors()
        super.becomeKey()
    }
    
    override func resignKey() {
        print("\(self).resignKey", self.frame)
        super.resignKey()
        close()
    }
    
    override func close() {
        stopMouseMonitor()
        appDelegate.onCaptureClose()
        super.close()
    }
    
    func startMouseMonitors() {
        let localMonitor = localMouseMonitor ?? NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) {
            self.handleMouseMove(event: $0, isGlobal: false)
            return $0
        }
        localMouseMonitor = localMonitor
    }
    
    func stopMouseMonitor() {
        if let monitor = self.localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            self.localMouseMonitor = nil
        }
    }
    
    func handleMouseMove(event: NSEvent, isGlobal: Bool) {
        if event.window == nil {
            // event.window == nil: point is in screen space
            // Move window to occupy display containing mouse
            if let display = NSScreen.screens.first(where: { $0.frame.contains(event.locationInWindow) }) {
                self.setFrame(display.frame, display: true)
            }
        }
    }
}
