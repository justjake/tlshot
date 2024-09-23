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
        for screen in NSScreen.screens {
            guard let id = screen.displayID else {
                continue
            }
            let maybeBox = windows[id]
            
            let intersection = screen.frame.intersection(rect)
            if intersection.isEmpty {
                maybeBox?.panel.orderOut(nil)
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
            
            let box = maybeBox ?? BoxOverlay()
            if box.edges != edges {
                box.edges = edges
            }
            box.panel.setFrame(intersection, display: true)
            box.panel.orderFront(self)
            windows[id] = box
        }
    }
    
    func hide() {
        windows.values.forEach { $0.panel.orderOut(nil) }
    }
}

class BoxOverlay: ObservableObject {
    @Published var edges: [Edge] = Edge.allCases
    
    struct BoxView: View {
        @ObservedObject var props: BoxOverlay
        @EnvironmentObject var app: AppDelegate
        
        var body: some View {
            Rectangle()
                .fill(.white.opacity(0.05))
                .border(width: 1, edges: props.edges, color: .white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cursor(app.desiredCursor)
        }
    }
    
    lazy var panel: some NSPanel = OverlayPanel(.zero, level: .shieldWindow) {
        BoxView(props: self)
    }
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}


struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]
    
    func path(in rect: CGRect) -> Path {
        edges.map { edge -> Path in
            switch edge {
            case .top: return Path(.init(x: rect.minX, y: rect.minY, width: rect.width, height: width))
            case .bottom: return Path(.init(x: rect.minX, y: rect.maxY - width, width: rect.width, height: width))
            case .leading: return Path(.init(x: rect.minX, y: rect.minY, width: width, height: rect.height))
            case .trailing: return Path(.init(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height))
            }
        }.reduce(into: Path()) { $0.addPath($1) }
    }
}
