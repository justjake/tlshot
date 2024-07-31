//
//  CrosshairPath.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/30/24.
//

import SwiftUI


struct CrosshairShape: Shape {
    // If nil, assumes center of rect
    var centerPoint: CGPoint?
    
    var centerSize: CGSize = .zero
    
    var hairWidth: CGFloat = 1
    var strokeWidth: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let centerPoint = self.centerPoint ?? rect.center
        let cross = self.cross(center: centerPoint, lineWidth: hairWidth, in: rect)
        return cross.subtracting(center(center: centerPoint))
    }
    
    func strokeShape() -> StrokeShape {
        StrokeShape(parent: self)
    }
    
    func strokePath(in rect: CGRect) -> Path {
        let centerPoint = self.centerPoint ?? rect.center
        let cross = self.crossStroke(center: centerPoint, in: rect)
        cross.forEach { print("cross: \($0)") }
        let clip = Path { $0.addRect(rect) }
        let withoutCenter = cross
            .subtracting(center(center: centerPoint))
        withoutCenter.forEach {
            print("stroke: \($0)")
        }
        return withoutCenter
    }
    
    func cross(center: CGPoint, lineWidth: CGFloat, in rect: CGRect) -> Path {
        Path {
            $0.addLines([ CGPoint(x: rect.minX, y: center.y), CGPoint(x: rect.maxX, y: center.y) ])
            $0.addLines([ CGPoint(x: center.x, y: rect.minY), CGPoint(x: center.x, y: rect.maxY) ])
        }.strokedPath(.init(lineWidth: lineWidth))
    }
    
    func crossStroke(center: CGPoint, in rect: CGRect) -> Path {
        cross(center: center, lineWidth: hairWidth, in: rect)
            // strokedPath centers the stroke on the edge.
            // we want an outer stroke, so we double the size,
            // and then use the inside cross to cut it out
            .strokedPath(.init(lineWidth: strokeWidth * 2))
            .subtracting(cross(center: center, lineWidth: hairWidth, in: rect))
    }
    
    func center(center: CGPoint) -> Path {
        Path { $0.addRect(centerRect(center)) }
    }
    
    private func centerRect(_ center: CGPoint) -> CGRect {
        CGRect(center: center, size: centerSize)
    }
    
    struct StrokeShape: Shape {
        let parent: CrosshairShape
        func path(in rect: CGRect) -> Path {
            parent.strokePath(in: rect)
        }
    }
}
