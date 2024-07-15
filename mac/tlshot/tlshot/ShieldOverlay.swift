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
        
        // We want the main window to makeKeyAndOrderFront + orderFrontRegardless
        // last, so it's the actual key window.
        let screensWithMainLast = NSScreen.screens.sorted { l, r in l != NSScreen.main }
        
        for (i, screen) in screensWithMainLast.enumerated() {
            let overlay = overlays[i, orInsert: ShieldOverlay(screen)]
            overlay.screen = screen
            if overlay.panel.frame != screen.frame {
                overlay.panel.setFrame(screen.frame, display: true)
            }
            if !overlay.panel.isVisible {
                overlay.panel.setIsVisible(true)
                // https://stackoverflow.com/questions/46023769/how-to-show-a-window-without-stealing-focus-on-macos
                // https://stackoverflow.com/questions/15077471/show-window-without-activating-keep-application-below-it-active#comment112101726_15079362
                overlay.panel.makeKeyAndOrderFront(nil)
                overlay.panel.orderFrontRegardless()
            }
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
        @State var localMousePosition: CGPoint?
        var useLocalMousePosition = true
        
        var localShiftClickHoverState: AppDelegate.ShiftClickHoverState?
        var shiftClickHoverState: AppDelegate.ShiftClickHoverState? {
            localShiftClickHoverState ?? app.shiftClickHoverState
        }
        
        var mousePosition: CGPoint? {
            if useLocalMousePosition {
                return localMousePosition
            } else if isMouseScreen {
                let nsPoint = props.panel.convertPoint(fromScreen: app.mouseLocation) as CGPoint
                // TODO: is this going to be CGPoint style SwiftUI top-left thingy?
                return props.panel.contentView?.convert(nsPoint, from: nil)
            }
            return nil
        }
        
        var body: some View {
            VStack {
                if let position = mousePosition {
                    let actionSymbol: String? = switch shiftClickHoverState {
                    case .adding(let windowInfo):
                        "plus.circle.fill"
                    case .removing(let windowInfo):
                        "minus.circle.fill"
                    case nil: nil
                    }
                    CursorDecoration(
                        showActionSymbol: actionSymbol,
                        showCrosshairs: app.captureAction == .area
                    )
                    .position(position)
                }
                
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
//            .border(
//                width: 2,
//                edges: Edge.allCases,
//                color: isMouseScreen ? .accentColor : .secondary
//            )
            .cursor(app.desiredCursor)
            .onContinuousHover { event in
                switch event {
                case .active(let point):
                    if !props.panel.isKeyWindow {
                        props.panel.makeKeyAndOrderFront(nil)
                    }
                    
                    if app.captureAction == nil && !app.isSwiftPreview {
                        print("XXX: mouse over ShieldOverlayView, but not capturing!")
                        app.render()
                    }
                    
                    localMousePosition = point
                case .ended:
                    localMousePosition = nil
                }
            }.gesture(DragGesture().onChanged {
                localMousePosition = $0.location
            })
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
    let bg = NSImage(named: "SwiftUIPreviewBackground")
    let delegate = AppDelegate()
    delegate.mouseScreen = screen
    delegate.captureAction = .area
    let props = ShieldOverlay(screen)
    return ShieldOverlay.ShieldView(
        props: props
    )
        .environmentObject(delegate)
        .background {
            Image(nsImage: bg!)
        }
     
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Self.Context) -> NSView { NSVisualEffectView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

}

#Preview("Window") {
    let screen = NSScreen.main!
    let bg = NSImage(named: "SwiftUIPreviewBackground")
    let delegate = AppDelegate()
    delegate.mouseScreen = screen
    delegate.captureAction = .window
    let props = ShieldOverlay(screen)
    return ShieldOverlay.ShieldView(
        props: props,
        localShiftClickHoverState: .adding(ScreenshotService.WindowInfo.mock(id: 1))
    )
        .environmentObject(delegate)
        .background {
            Image(nsImage: bg!)
        }
}


func +(lhs: CGPoint, rhs: CGVector) -> CGPoint {
    CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
}

struct Crosshairs: Shape {
    let max: Double = 10_000.0
    let line: Double = 1.0
    let gap = 1.0
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addRects([
                vertical(in: rect, dx: gap),
                vertical(in: rect, dx: -gap),
                horizontal(in: rect, dy: gap),
                horizontal(in: rect, dy: -gap),
            ])
        }
    }
    
    func vertical(in rect: CGRect, dx: CGFloat) -> CGRect {
        .init(center: rect.center.d(x: dx), size: CGSize(width: line, height: max))
    }
    
    func horizontal(in rect: CGRect, dy: CGFloat) -> CGRect {
        .init(center: rect.center.d(y: dy), size: CGSize(width: max, height: line))
    }
    
}

extension CGPoint {
    func d(x: CGFloat = 0, y: CGFloat = 0) -> CGPoint {
        CGPoint(x: self.x + x, y: self.y + y)
    }
}

struct CursorDecoration: View {
    static let actionOffset = CGSize(width: 18, height: 18)
    let symbolSize: CGFloat = 16
    
    var showActionSymbol: String?
    var showCrosshairs: Bool
    
    var body: some View {
        ZStack {
            crosshairs
            actionIndicator
                .offset(Self.actionOffset)
        }
        .zIndex(1)
    }
    
    // Crosshairs
    @ViewBuilder
    var crosshairs: some View {
        if showCrosshairs {
            Crosshairs()
        }
    }
    
    
    // Action Indicator
    
    @ViewBuilder
    var actionIndicator: some View {
        if let name = showActionSymbol {
            symbol(name)
        }
    }
               
    var plus: some View { symbol("plus.circle.fill") }
    var minus: some View { symbol("minus.circle.fill") }

    func symbol(_ systemName: String) -> some View {
        CursorSymbolBadge(systemName: systemName)
        // Flattens this view, so that the shadow never
        // ends up lagging behind the rest of the views during
        // our frequent re-renders.
            .drawingGroup()
    }
}

struct CursorSymbolBadge: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .symbolRenderingMode(.multicolor)
            .aspectRatio(contentMode: .fill)
            .fontWeight(.bold)
            .frame(width: 14, height: 14)
            .zIndex(1)
    }
}
