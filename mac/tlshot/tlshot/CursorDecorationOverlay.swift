//
//  CursorDecorationOverlay.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/14/24.
//

import SwiftUI

class CursorDecorationOverlay: ObservableObject {
    static let shared = CursorDecorationOverlay()
    lazy var panel = OverlayPanel(NSRect(center: NSScreen.main?.frame.center ?? .zero, size: size)) {
        CursorDecorationView(props: self)
    }

    @Published var size: NSSize = .init(width: 50, height: 50)
    var active = false
    
    func show(point: NSPoint) {
        return
        
//        active = true
//        if !panel.isVisible {
//            panel.setIsVisible(true)
//        }
//        
//        let frame = CGRect(center: point, size: size)
//        panel.setFrame(frame, display: true)
//        panel.orderFrontRegardless()
    }
    
    func hide() {
        return
//        active = false
//        panel.setIsVisible(false)
    }
    
    struct CursorDecorationView: View {
        @ObservedObject var props: CursorDecorationOverlay
        @EnvironmentObject var app: AppDelegate
        
        var body: some View {
            Text("hi!").expand()
                .background {
                    Rectangle()
                        .stroke(lineWidth: 3)
                        .foregroundStyle(.red)
                }
        }
    }
}
