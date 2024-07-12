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
    static public private(set) var shared = WindowPicker()
    
    lazy var box = BoxOverlay()
    var target: WindowInfo?
    
    func setTarget(for point: NSPoint) {
        target = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: box.panel.windowNumber)
    }
}
