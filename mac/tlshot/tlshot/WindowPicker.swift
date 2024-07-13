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
    
    static public private(set) var shared = WindowPicker()
    
    lazy var box = {
        let overlay = BoxOverlay()
        overlay.edges = Edge.allCases
        return overlay
    }()
    
    
    var targets: [ScreenshotService.WindowInfo] = []
    var target: ScreenshotService.WindowInfo?
    
    @discardableResult
    func setTarget(for point: NSPoint) -> ScreenshotService.WindowInfo? {
        target = ScreenshotService.shared.windowAt(point: point.isNS)
        render()
        return target
    }
    
    @discardableResult
    func clearTarget() -> ScreenshotService.WindowInfo? {
        guard let target = self.target else {
            return nil
        }
        self.target = nil
        render()
        return target
    }
    
    private func render() {
        guard let target = self.target else {
            box.panel.setIsVisible(false)
            return
        }
        
        box.panel.setIsVisible(true)
        box.panel.setFrame(target.frame.asNS, display: true)
        box.panel.order(.above, relativeTo: target.windowID)
    }
}
