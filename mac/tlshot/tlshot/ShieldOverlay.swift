//
//  ShieldOverlay.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/12/24.
//

import SwiftUI

extension Array {
    subscript(
        _ index: Index,
        orInsert defaultValue: @autoclosure () -> Element
    ) -> Element {
        mutating get {
            if self.indices.contains(index) {
                return self[index]
            }
            self.append(defaultValue())
            return self[index]
        }
    }
}

class ShieldOverlayManager {
    static public private(set) var shared = ShieldOverlayManager()
    
    var started = false
    var overlays: [ShieldOverlay] = []
    
    func start() {
        started = true
        render()
    }
    
    func stop() {
        started = false
        render()
    }
    
    private func render() {
        if !started {
            overlays.forEach { $0.panel.setIsVisible(false) }
            return
        }
        
        for (i, screen) in NSScreen.screens.enumerated() {
            let overlay = overlays[i, orInsert: ShieldOverlay(screen)]
            overlay.screen = screen
            overlay.panel.setFrame(screen.frame, display: true)
            overlay.panel.setIsVisible(true)
            // https://stackoverflow.com/questions/46023769/how-to-show-a-window-without-stealing-focus-on-macos
            // https://stackoverflow.com/questions/15077471/show-window-without-activating-keep-application-below-it-active#comment112101726_15079362
            overlay.panel.makeKeyAndOrderFront(nil)
            overlay.panel.orderFrontRegardless()
        }
    }
}

class ShieldOverlay: ObservableObject {
    @Published var screen: NSScreen
    
    init(_ screen: NSScreen) {
        self.screen = screen
    }
    
    lazy var panel = {
        let panel = Panel(.zero, level: .shieldWindow) {
            ShieldView(props: self)
        }
        panel.ignoresMouseEvents = false
        return panel
    }()

    class Panel<Content: View>: OverlayPanel<Content> {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }
    
    struct ShieldView: View {
        @EnvironmentObject var app: AppDelegate
        @ObservedObject var props: ShieldOverlay
        var isMouseScreen: Bool { props.screen == app.mouseScreen }
        
        var body: some View {
            VStack {
                Spacer()
                
                Text("Screen \(props.screen.localizedName)")
                
                HStack {
                    switch app.captureAction {
                    case .area:
                        Text("Area mode").font(.body.bold())
                        Text("Click and drag: capture rectangle")
                        Text("Space: window mode")
                    case .window:
                        Text("Window mode").font(.body.bold())
                        Text("Click: capture window")
                        Text("Shift-Click: capture multiple windows")
                        Text("Space: area mode")
                    case .none:
                        Text("Canceled")
                    }
                    Text("Escape: cancel")
                }
                .padding()
                .opacity(isMouseScreen ? 1 : 0)
                
            }
            .expand()
            .border(
                width: 2,
                edges: Edge.allCases,
                color: isMouseScreen ? .accentColor : .secondary
            )
        }
    }
}

extension View {
    func expand() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
