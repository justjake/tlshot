//
//  WindowPicker.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/12/24.
//

import Foundation
import AppKit
import SwiftUI

class WindowPicker: ObservableObject {
    enum TargetMode {
        case set
        case add
    }
    
    static public private(set) var shared = WindowPicker()
    
    @Published var targets: [ScreenshotService.WindowInfo] = []
    @Published var hovered: ScreenshotService.WindowInfo?
    var overlays: [WindowPickerOverlay] = []
    
    @discardableResult
    func setHovered(point: NSPoint) -> ScreenshotService.WindowInfo? {
        hovered = ScreenshotService.shared.windowAt(point: point.isNS)
        render()
        return hovered
    }
    
    func toggleTarget(_ window: ScreenshotService.WindowInfo) {
        if addTarget(window) {
            return
        }
        
        removeTarget(window)
        render()
    }

    @discardableResult
    func addTarget(_ window: ScreenshotService.WindowInfo) -> Bool {
        if !targets.contains(where: { $0.id == window.id }) {
            targets.append(window)
            render()
            return true
        }
        return false
    }
    
    func removeTarget(_ window: ScreenshotService.WindowInfo) {
        targets.removeAll { $0.id == window.id }
        render()
    }
    
    func removeAllTargets() -> [ScreenshotService.WindowInfo] {
        let result = targets
        targets = []
        render()
        return result
    }
    
    @discardableResult
    func reset() -> (ScreenshotService.WindowInfo?, [ScreenshotService.WindowInfo]) {
        let result = (hovered, targets)
        hovered = nil
        targets = []
        render()
        return result
    }
    
    private func render() {
        var renderable = targets
        if let hovered = self.hovered, !renderable.contains(where: { $0.id == hovered.id }) {
            renderable.append(hovered)
        }
        
        for i in 0..<max(renderable.count, overlays.count) {
            let window = i < renderable.count ? renderable[i] : nil
            renderFor(window: window, index: i)
        }
    }
    
    private func renderFor(window: ScreenshotService.WindowInfo?, index: Int) {
        let overlay = overlays[index, orInsert: WindowPickerOverlay()]
        
        guard let window = window else {
            if overlay.panel.isVisible {
                overlay.panel.setIsVisible(false)
            }
            overlay.windowID = nil
            return
        }
        
        overlay.windowID = window.id
        overlay.panel.level = NSWindow.Level(rawValue: window.layer)
        overlay.panel.setIsVisible(true)
        overlay.panel.setFrame(window.frame.asNS, display: true)
        overlay.panel.order(.above, relativeTo: window.id)
    }
    
    class WindowPickerOverlay: ObservableObject {
        @Published var windowID: Int?
        lazy var panel: some NSPanel = OverlayPanel(.zero) { OverlayView(props: self) }
        
        struct OverlayView: View {
            @ObservedObject var app: AppDelegate = AppDelegate.shared
            @ObservedObject var props: WindowPickerOverlay
            @ObservedObject var picker: WindowPicker = WindowPicker.shared
            
            var isHovered: Bool {
                props.windowID == picker.hovered?.id
            }
            
            var body: some View {
                Rectangle()
                    .stroke(lineWidth: 1)
                    .foregroundStyle(isHovered ? Color.accentColor : .primary)
                    .expand()
                    .cursor(app.desiredCursor)
            }
        }
    }
}
