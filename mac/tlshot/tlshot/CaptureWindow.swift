//
//  CaptureWindow.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/11/24.
//

import Foundation
import AppKit
import SwiftUI

extension NSEvent {
    var globalLocation: NSPoint {
        guard let window = self.window else {
            return locationInWindow
        }
        
        let localRect = NSRect(origin: locationInWindow, size: .zero)
        let globalRect = window.convertToScreen(localRect)
        return globalRect.origin
    }
}

class CaptureWindow: OverlayPanel<CaptureView> {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var localMouseMonitor: EventMonitor? = nil
    
    init(
         contentRect: NSRect,
         backing: NSWindow.BackingStoreType = .buffered,
         defer flag: Bool = false
    ) {
        super.init(contentRect: contentRect) { CaptureView(window: $0 as! CaptureWindow) }
        
        self.isReleasedWhenClosed = false
        level = .shieldWindow
        
        /// Dim background
        backgroundColor = NSColor(white: 0, alpha: 0.1)
        /// Sets animations accordingly
        animationBehavior = .utilityWindow
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
        let monitor = self.localMouseMonitor ?? EventMonitor(.mouseMoved, monitorEvent: handleMouseMove)
        monitor.start()
        self.localMouseMonitor = monitor
    }
    
    func stopMouseMonitor() {
        self.localMouseMonitor?.stop()
    }
    
    func handleMouseMove(event: NSEvent) {
        if event.window == nil {
            // event.window == nil: point is in screen space
            // Move window to occupy display containing mouse
            if let display = NSScreen.screens.first(where: { $0.frame.contains(event.locationInWindow) }) {
                self.setFrame(display.frame, display: true)
            }
        }
    }
}
