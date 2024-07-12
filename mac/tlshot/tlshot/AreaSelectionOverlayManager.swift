//
//  CaptureRectManager.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/12/24.
//

import SwiftUI


extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
}

class AreaSelectionOverlayManager {
    static var shared = AreaSelectionOverlayManager()
    
    var windows: [CGDirectDisplayID:BoxOverlay] = [:]
    
    func show(_ rect: NSRect, below: NSWindow? = nil) {
        hide()
        
        for screen in NSScreen.screens {
            guard let id = screen.displayID else {
                continue
            }
            
            let intersection = screen.frame.intersection(rect)
            if intersection.isEmpty {
                continue
            }
            
            let edges = Edge.allCases.filter {
                switch $0 {
                case .top: rect.maxY == intersection.maxY
                case .bottom: rect.minY == intersection.minY
                case .leading: rect.minX == intersection.minX
                case .trailing: rect.maxX == intersection.maxX
                }
            }
            
            let box = windows[id] ?? BoxOverlay()
            box.edges = edges
            box.panel.setFrame(intersection, display: true)
            box.panel.orderFront(self)
            windows[id] = box
        }
    }
    
    func hide() {
        windows.values.forEach { $0.panel.setIsVisible(false) }
    }
}
