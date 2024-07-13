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

