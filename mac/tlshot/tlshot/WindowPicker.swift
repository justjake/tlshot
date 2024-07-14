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
            renderFor(window: nil, index: i, hovered: false)
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
            renderFor(window: window, index: i, hovered: window?.id == hovered?.id)
        }
    }
    
    private func renderFor(window: ScreenshotService.WindowInfo?, index: Int, hovered: Bool) {
        let overlay = overlays[index, orInsert: WindowPickerOverlay()]
        
        guard let window = window else {
            if overlay.panel.isVisible {
                overlay.panel.setIsVisible(false)
            }
            overlay.isHovered = false
            return
        }
        
        overlay.isHovered = hovered
        overlay.panel.level = NSWindow.Level(rawValue: window.layer + 1)
        overlay.panel.setIsVisible(true)
        overlay.panel.setFrame(window.frame.asNS, display: true)
        overlay.panel.order(.above, relativeTo: window.id)
    }
    
    class WindowPickerOverlay: ObservableObject {
        @Published var isHovered: Bool = false
        
        lazy var panel: some NSPanel = OverlayPanel(.zero) { OverlayView(props: self) }
        
        struct OverlayView: View {
            @ObservedObject var app: AppDelegate = AppDelegate.shared
            @ObservedObject var props: WindowPickerOverlay
            
            var color: Color {
                props.isHovered ? Color.accentColor : .primary
            }
            
            var body: some View {
                Rectangle()
                    .stroke(color, lineWidth: 2)
                    .expand()
                    .cursor(app.desiredCursor)
            }
        }
    }
}
