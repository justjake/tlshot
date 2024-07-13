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
                
                HStack {
                    switch app.captureAction {
                    case .area:
                        Text("Capture Area").font(.body.bold())
                        Divider().frame(maxHeight: 24)
                        HStack {
                            Text("Click+Drag:")
                                .foregroundStyle(.secondary)
                            Text("Capture")
                        }
                        Divider().frame(maxHeight: 24)
                        HStack {
                            Text("Space:")
                                .foregroundStyle(.secondary)
                            Text("Capture Window")
                        }
                    case .window:
                        Text("Capture Window").font(.body.bold())
                        Divider().frame(maxHeight: 24)
                        HStack {
                            Text("Click:")
                                .foregroundStyle(.secondary)
                            Text("Capture")
                        }
                        Divider().frame(maxHeight: 24)
                        HStack {
                            Text("Shift+Click")
                                .foregroundStyle(app.shiftKey ? .primary :
                                    .secondary)
                            Text("Capture Multiple")
                        }
                        Divider().frame(maxHeight: 24)
                        HStack {
                            Text("Space")
                                .foregroundStyle(.secondary)
                            Text("Capture Area")
                        }
                    case .none:
                        Text("Canceled")
                    }
                    Divider().frame(maxHeight: 24)
                    HStack {
                        Text("Escape:")
                            .foregroundStyle(.secondary)
                        Text("Cancel")
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(radius: 10)
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
