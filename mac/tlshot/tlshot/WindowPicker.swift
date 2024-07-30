//
//  WindowPicker.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/12/24.
//

import Foundation
import AppKit
import SwiftUI

class WindowPicker {
    enum TargetMode {
        case set
        case add
    }
    
    typealias WindowInfo = ScreenshotService.WindowInfo
    
    static public private(set) var shared = WindowPicker()
    var overlays: [WindowPickerOverlay] = []
    
    func hide() {
        for i in 0..<overlays.count {
            renderFor(window: nil, index: i, hovered: false, selected: false)
        }
    }
    
    func show(
        hovered: WindowInfo?,
        selected targets: [WindowInfo]
    ) {
        var renderable = targets
        if let hovered = hovered, !renderable.contains(where: { $0.id == hovered.id }) {
            renderable.append(hovered)
        }
        
        for i in 0..<max(renderable.count, overlays.count) {
            let window = i < renderable.count ? renderable[i] : nil
            renderFor(window: window, index: i, hovered: window?.id == hovered?.id, selected: i < targets.count)
        }
    }
    
    private func renderFor(window: ScreenshotService.WindowInfo?, index: Int, hovered: Bool, selected: Bool) {
        let overlay = overlays[index, orInsert: WindowPickerOverlay()]
        
        guard let window = window else {
            if overlay.panel.isVisible {
                overlay.panel.orderOut(nil)
            }
            overlay.isHovered = false
            overlay.isSelected = false
            return
        }
        
        overlay.isHovered = hovered
        overlay.isSelected = selected
        overlay.window = window
        overlay.panel.setFrame(window.frame.asNS, display: true)
        overlay.panel.level = if window.layer == CGWindowLevelKey.mainMenuWindow.cgLevel {
            // The system doesn't allow ordering in front of mainMenuWindow withing the same level.
            // We need to go to the next level.
            // There doesn't appear to be any way to order behind the existing status windows.
            CGWindowLevelKey.statusWindow.nsLevel
        } else {
            // Stack within the same level of the window, we'll order just above it.
            NSWindow.Level(rawValue: window.layer)
        }
        overlay.panel.order(.above, relativeTo: window.id)
    }
    
    class WindowPickerOverlay: ObservableObject {
        @Published var window: ScreenshotService.WindowInfo?
        @Published var isHovered: Bool = false
        @Published var isSelected: Bool = false
        
        lazy var panel: some NSPanel = OverlayPanel(.zero) { OverlayView(props: self) }
        
        struct OverlayView: View {
            @EnvironmentObject var app: AppDelegate
            @ObservedObject var props: WindowPickerOverlay
            
            var activeCoverColor: Color {
                Color(NSColor.selectedContentBackgroundColor).opacity(0.6)
            }
            
            var backgroundCoverColor: Color {
                activeCoverColor.opacity(0.4)
            }
            
            var coverColor: Color {
                props.isHovered ? activeCoverColor : backgroundCoverColor
            }
            
            var cornerRadius: CGFloat {
                if props.window?.layer ?? 0 == CGWindowLevelKey.normalWindow.cgLevel {
                    // Normal windows are probably rounded, 9px seems to match
                    // macOS big sur+ window border radius.
                    return 9
                }
                
                return 0
            }
            
            var body: some View {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(coverColor)
                    .expand()
                    .cursor(app.desiredCursor)
            }
        }
    }
}
