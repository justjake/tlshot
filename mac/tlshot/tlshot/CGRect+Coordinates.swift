//
//  CGRect+Coordinates.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/12/24.
//
import Foundation
import AppKit

enum CoordPoint {
    static func flip(_ point: CGPoint, height: Double) -> CGPoint {
        guard let screen = NSScreen.screens.first else {
            return point
        }
        var result = point
        result.y = screen.frame.maxY - (point.y + height)
        return result
    }
    
    case ns(CGPoint)
    case cg(CGPoint)
    
    var asCG: CGPoint {
        switch self {
        case .ns(let point): CoordPoint.flip(point, height: 0)
        case .cg(let point): point
        }
    }
    
    var asNS: CGPoint {
        switch self {
        case .ns(let point): point
        case .cg(let point): CoordPoint.flip(point, height: 0)
        }
    }
}

extension CGPoint {
    var isNS: CoordPoint { .ns(self) }
    var isCG: CoordPoint { .cg(self) }
    func rounded() -> CGPoint {
        return .init(x: x.rounded(), y: y.rounded())
    }
}

/// CoreGraphics / Quartz uses a coordinate space where the origin (0, 0) is at the top-left of the primary display. Increasing y goes down.
/// Cocoa / NSScreen uses a coordinate space where the origin (0, 0) is the bottom-left of the primary display and increasing y goes up.
/// https://stackoverflow.com/questions/19884363/in-objective-c-os-x-is-the-global-display-coordinate-space-used-by-quartz-d
/// https://developer.apple.com/documentation/coregraphics/1454852-cgwindowlistcreateimage
enum CoordRect {
    // This should work to flip either direction.
    static func flip(_ rect: CGRect) -> CGRect {
        let origin = CoordPoint.flip(rect.standardized.origin, height: rect.standardized.height)
        return CGRect(origin: origin, size: rect.standardized.size)
    }
    
    case ns(CGRect)
    case cg(CGRect)
    
    var asCG: CGRect {
        switch self {
        case .ns(let rect): CoordRect.flip(rect)
        case .cg(let rect): rect
        }
    }
    
    var asSelf: CGRect {
        switch self {
        case .ns(let rect): rect
        case .cg(let rect): rect
        }
    }
    
    var asNS: CGRect {
        switch self {
        case .ns(let rect): rect
        case .cg(let rect): CoordRect.flip(rect)
        }
    }
}

extension Collection where Element == CGRect {
    func union() -> CGRect {
        reduce(CGRect.zero) { $0.union($1) }
    }
}

extension Collection where Element == CoordRect {
    func union() -> CoordRect {
        self.map { $0.asCG }.union().isCG
    }
}

extension CGRect {
    var isNS: CoordRect { .ns(self) }
    var isCG: CoordRect { .cg(self) }
    
    var center : CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
    
    init(_ p1: CGPoint, _ p2: CGPoint) {
        self.init(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p1.x - p2.x),
            height: abs(p1.y - p2.y))
    }
    
    init(center: CGPoint, size: CGSize) {
        let dx = size.width / 2
        let dy = size.height / 2
        self.init(x: center.x - dx, y: center.y - dy, width: size.width, height: size.height)
    }
}

