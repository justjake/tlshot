//
//  CGRect+Coordinates.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/12/24.
//
import Foundation
import AppKit

/// CoreGraphics / Quartz uses a coordinate space where the origin (0, 0) is at the top-left of the primary display. Increasing y goes down.
/// Cocoa / NSScreen uses a coordinate space where the origin (0, 0) is the bottom-left of the primary display and increasing y goes up.
/// https://stackoverflow.com/questions/19884363/in-objective-c-os-x-is-the-global-display-coordinate-space-used-by-quartz-d
/// https://developer.apple.com/documentation/coregraphics/1454852-cgwindowlistcreateimage
enum CoordRect {
    static func toCG(nsRect: CGRect) -> CGRect {
        guard let screen = NSScreen.screens.first else {
            return nsRect
        }
        var rect = nsRect
        rect.origin.y = screen.frame.maxY - rect.maxY
        return rect
    }
    
    case ns(CGRect)
    case cg(CGRect)
    
    var asCG: CGRect {
        switch self {
        case .ns(let rect): CoordRect.toCG(nsRect: rect)
        case .cg(let rect): rect
        }
    }
    
    var asSelf: CGRect {
        switch self {
        case .ns(let rect): rect
        case .cg(let rect): rect
        }
    }
}

extension CGRect {
    var isNS: CoordRect { .ns(self) }
    var isCG: CoordRect { .cg(self) }
}

extension CGRect {
    init(_ p1: CGPoint, _ p2: CGPoint) {
        self.init(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p1.x - p2.x),
            height: abs(p1.y - p2.y))
    }
}
