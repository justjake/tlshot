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
    lazy var screenMonitor = ScreenChangeMonitor() { self.render() }
    
    func start() {
        started = true
        screenMonitor.start()
        render()
    }
    
    func stop() {
        started = false
        screenMonitor.stop()
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
                
                HStack(spacing: 16) {
                    switch app.captureAction {
                    case .area:
                        mode("Capture Area")
                        divider
                        action {
                            Text("Drag")
                                .foregroundStyle(.secondary)
                            Text("Capture area")
                        }
                        divider
                        action {
                            Text("Space")
                                .foregroundStyle(.secondary)
                            Text("Capture Window")
                        }
                    case .window:
                        mode("Capture Window")
                        divider
                        action {
                            Text("Click")
                                .foregroundStyle(.secondary)
                            Text("Capture window")
                        }
                        divider
                        action {
                                Text("Shift")
                                .foregroundStyle(app.modifierFlags.contains(.shift) ? .primary :
                                            .secondary)
                            Text("Capture Multiple")
                        }
                        divider
                        action {
                            Text("Control")
                                .foregroundStyle(app.modifierFlags.contains(.control) ? .primary :
                                        .secondary)
                            Text("Include desktop")
                        }
                        divider
                        action {
                            Text("Space")
                                .foregroundStyle(.secondary)
                            Text("Capture Area")
                        }
                    case .none:
                        Text("Canceled")
                    }
                    divider
                    action {
                        Text("Esc")
                            .foregroundStyle(.secondary)
                        Text("Cancel")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.gray.opacity(0.2))
                        .padding(1)
                )
                .background(
                    VisualEffectView()
                        .clipShape(
                            RoundedRectangle(cornerRadius: 15, style: .continuous))
                )
                .shadow(radius: 6)
                .opacity(isMouseScreen ? 0.8 : 0)
                .padding(.all, 20)
                .help(Text("Help window (not included in captures)"))

            }
            .expand()
            .border(
                width: 2,
                edges: Edge.allCases,
                color: isMouseScreen ? .accentColor : .secondary
            )
        }
        
        private var divider: some View {
            Divider().frame(maxHeight: 24)
        }
        
        private func action(
            @ViewBuilder builder: () -> some View
        ) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                builder()
            }
        }
        
        private func mode(_ title: String) -> some View {
            VStack(alignment: .trailing, spacing: 0) {
                Text("tlshot")
                    .font(.custom("Baskerville", size: 16, relativeTo: .headline))
                    .foregroundStyle(.secondary)
            }
            
            
//            let appName = Text("Actions:")
//                .foregroundStyle(.secondary)
//            
//            return Text("Capture Area").font(.body.bold())
//                .overlay(
//                    appName.offset(x: 0, y: 15),
//                    alignment: .leading
//                )
            
//            VStack(alignment: .leading, spacing: 0) {
//                Text("tlshot")
//                    .foregroundStyle(.secondary)
//                    .offset(x: 0, y: 0)
//
//                Text("Capture Area").font(.body.bold()).offset(x: 0, y: -2)
//                    .overlay(
//                        appName.offset(x: 0, y: -15),
//                        alignment: .leading
//                    ).offset(x: 0, y: 4)
//            }.frame(height: 0)
            
        }
    }
    
}

extension View {
    func expand() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Area") {
    let screen = NSScreen.main!
    let bg = ScreenshotService.shared.screenshot(screen.frame.isNS)
    let delegate = AppDelegate()
    delegate.mouseScreen = screen
    delegate.captureAction = .area
    let props = ShieldOverlay(screen)
    return ShieldOverlay.ShieldView(props: props)
        .environmentObject(delegate)
        .background {
            Image(decorative: bg!, scale: 2, orientation: .up)
        }
     
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Self.Context) -> NSView { NSVisualEffectView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

}

#Preview("Window") {
    let screen = NSScreen.main!
    let bg = ScreenshotService.shared.screenshot(screen.frame.isNS)
    let delegate = AppDelegate()
    delegate.mouseScreen = screen
    delegate.captureAction = .window
    let props = ShieldOverlay(screen)
    return ShieldOverlay.ShieldView(props: props)
        .environmentObject(delegate)
        .background {
            Image(decorative: bg!, scale: 2, orientation: .up)
        }
}
