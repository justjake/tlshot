//
//  tlshotApp.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/10/24.
//

import SwiftUI
import UniformTypeIdentifiers
import ScreenCaptureKit


enum CaptureAction {
    case area
    case window
    case desktop
}

enum CaptureMediaType {
    case image
    case video
}

enum TlshotError: LocalizedError {
    case missingFileData
    case unknownFileType(UTType)
    case invalidJson(Data)
    case notImplemented(String)
    case captureFailed(String)
    
    var errorDescription: String? {
        "\(self)"
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .captureFailed: "Grant permission in System Settings"
        default: nil
        }
    }
}

struct TldrawDocument: FileDocument {
    typealias RawJson = Dictionary<String, Any>
    static var readableContentTypes: [UTType] = [.png, .jpeg, .json]
    
    var backgroundImage: NSImage? = nil
    var json: RawJson = [:]
    
    init() {
        // OK!
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw TlshotError.missingFileData
        }
        switch (configuration.contentType) {
        case .image:
            backgroundImage = NSImage(data: data)
        case .json:
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? RawJson else {
                throw TlshotError.invalidJson(data)
            }
            json = decoded
        default:
            throw TlshotError.unknownFileType(configuration.contentType)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        switch configuration.contentType {
        case .image:
            throw TlshotError.notImplemented("Saving to image")
        case .json:
            let data = try JSONSerialization.data(withJSONObject: json)
            return FileWrapper(regularFileWithContents: data)
        default:
            throw TlshotError.unknownFileType(configuration.contentType)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static var shared = AppDelegate()
    
    @AppStorage("saveFolder") var saveFolder: URL = AppDelegate.defaultSaveFolder()
    @AppStorage("warnWhenScreenRecordingPermissionDenied") var warnIfDenied: Bool = true
    
    @Published var captureAction: CaptureAction? = nil
    @Published var captureMediaType: CaptureMediaType = .image
    @Published var captureWindow: CaptureWindow? = nil
    @Published var hasPermission: Bool = false
    @Published var imageWindows: [NSWindow] = []
    @Published var mouseLocation: NSPoint = NSEvent.mouseLocation
    @Published var capturePhase: CapturePhase = .ended
    @Published var dragStart: NSPoint? = nil
    
    lazy var mouseListener = MouseMonitor { @MainActor [self] event in
        mouseLocation = NSEvent.mouseLocation
        
        if event.type == .leftMouseDragged && dragStart == nil {
            onDragStart()
            return
        }
        
        if event.type == .leftMouseUp && dragStart != nil {
            try! onDragEnd()
            return
        }
        
        if let rect = dragRect {
            print("update captureRect", rect)
            CaptureRectManager.shared.show(rect)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        setActivationPolicy()
        hasPermission = CGPreflightScreenCaptureAccess()
        print("\(self).hasPermission: \(hasPermission)")
        
        // TODO: not this
        startCapture(.area)
    }
    
    @MainActor func onDragStart() {
        dragStart = NSEvent.mouseLocation
        print("onDragStart", dragStart)
    }
    
    var dragRect: NSRect? {
        if let p1 = dragStart {
            return NSRect(p1, mouseLocation)
        }
        return nil
    }
    
    @MainActor func onDragEnd() throws {
        defer { dragStart = nil }
        guard let rect = dragRect else {
            print("onDragEnd: no rect?")
            return
        }
        print("onDragEnd", rect)
        
        CaptureRectManager.shared.hide()
        
        try onCaptureRect(area: rect)
    }
    
    func startCapture(_ action: CaptureAction, mediaType: CaptureMediaType = .image) {
        mouseListener.start()
        captureAction = action
        captureMediaType = mediaType
        var rect: NSRect = .infinite
        if let screen = NSScreen.main {
            rect = screen.frame
        }
        NSApp.activate()
        let captureWindow = self.captureWindow ?? CaptureWindow(contentRect: rect)
        self.captureWindow = captureWindow
        captureWindow.setFrame(rect, display: true)
        captureWindow.makeKeyAndOrderFront(self)
        print(self, "startCapture frame: \(captureWindow.frame), \(captureWindow.becomeFirstResponder())")
    }
    
    func onCaptureClose() {
        if let captureWindow = self.captureWindow {
            print(self, "onCaptureClose", captureWindow)
            self.captureWindow = nil
            captureWindow.close()
        }
        captureAction = nil
        mouseListener.stop()
    }
    
    @MainActor func onCaptureRect(area: CGRect) throws {
        onCaptureClose()
        if let image = CGWindowListCreateImage(area, .optionAll, 0, [.shouldBeOpaque, .bestResolution]) {
            print("got image: \(image)")
            hasPermission = true
            editImage(image, frame: area)
        } else {
            throw TlshotError.captureFailed("System didn't return an image")
        }
    }
    
    @MainActor func editImage(_ image: CGImage, frame: CGRect) {
        let window = ImageWindow(rect: frame, image: image)
        imageWindows.append(window)
        setActivationPolicy()
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(self)
    }
    
    func setActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = if imageWindows.count > 0 {
            .regular
        } else {
            .accessory
        }
        NSApp.setActivationPolicy(policy)
        if policy == .regular {
            NSApp.activate()
        }

    }
    
    static func defaultSaveFolder() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(components: "Pictures", "Screenshots")
    }
    
    func removeImageWindow(_ window: NSWindow) {
        self.imageWindows.removeAll(where: { $0 == window })
        setActivationPolicy()
    }
}

@main
struct tlshotApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        DocumentGroup(newDocument: TldrawDocument()) { group in
            ContentView(document: group.$document)
        }
        
        MenuBarExtra("tlshot") {
            Button("Capture Area") {
                appDelegate.startCapture(.area)
            }
            Button("Capture Fullscreen") {
                // TODO
            }
            Button("Record video") {
                appDelegate.startCapture(.area, mediaType: .video)
            }
            
            Divider()
            
            Text("Save to ~/Pictures/Screenshots")
            
            Button("Choose folder...") {
                // TODO
            }
            Button("Quit") {
                NSApplication.shared.terminate(self)
            }.keyboardShortcut("Q", modifiers: .command)
        }
    }
    
}

extension CGRect {
    init(_ p1: CGPoint, _ p2: CGPoint) {
        self.init(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p1.x - p2.x),
            height: abs(p1.y - p2.y))
    }
    
    func toNS(screen: NSScreen) -> CGRect {
        let flippedY = screen.frame.size.height - self.origin.y
        return CGRect(x: origin.x, y: flippedY, width: width, height: height)
    }
}

enum CapturePhase: CustomDebugStringConvertible {
    case ended
    case hover(current: CGPoint)
    case drag(start: CGPoint, current: CGPoint)
    case complete(start: CGPoint, current: CGPoint)
    
    var rect: CGRect? {
        return switch self {
        case .ended: nil
        case .hover: nil
        case .drag(start: let start, current: let current):
            CGRect(start, current)
        case .complete(start: let start, current: let current):
            CGRect(start, current)
        }
    }
    
    var debugDescription: String {
        switch self {
        case .ended: "CapturePhase.ended"
        case .hover(current: let point): "CapturePhase.hover(\(point))"
        case .drag: "CapturePhase.drag(\(rect!)))"
        case .complete: "CapturePhase.complete(\(rect!)))"
        }
    }
}

struct CaptureView: View {
    let window: CaptureWindow
    @EnvironmentObject var appDelegate: AppDelegate
    @FocusState private var focused: Bool
    @State private var mouse: CapturePhase = .ended
    @State private var error: Error? = nil
    
    var body: some View {
//        let _ = print("SwiftUI mouse: \(mouse)")
        HStack() {
            Spacer()
            
            VStack() {
                Spacer()
                Text("Capture View!")
                Text("more views?")
                Text("focused: \(focused)")
                if !appDelegate.hasPermission && appDelegate.warnIfDenied {
                    PermissionWarningView()
                }
                Spacer()
            }
            
            Spacer()
        }
        .focusable()
        .focused($focused)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                mouse = .hover(current: location)
            case .ended:
                mouse = .ended
            }
        }
        .onAppear {
            print("CaptureView.onAppear", window)
            focused = true
        }
        .onDisappear {
            print("CaptureView.onDisappear", window)
            window.close()
        }
        .onKeyPress(.escape) {
            print("CaptureView.onKeyPress escape", window)
            window.close()
            return .handled
        }
        .onKeyPress(.space) {
            print("CaptureView.onKeyPress space", window)
            if appDelegate.captureAction == .area {
                appDelegate.captureAction = .window
            } else {
                appDelegate.captureAction = .area
            }
            return .handled
        }
        .gesture(dragGesture)
        .errorAlert(error: $error, buttonTitle: "Okay")
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged {
                switch mouse {
                case .drag: break
                default: break
//                default: appDelegate.onDragStart()
                }
                mouse = .drag(start: $0.startLocation, current: $0.location)
            }.onEnded {
                mouse = .complete(start: $0.startLocation, current: $0.location)
                onDragComplete(CGRect($0.startLocation, $0.location))
            }
    }
    
    func onDragComplete(_ rect: CGRect) {
        print("onCaptureComplete: \(rect)")
        if appDelegate.captureAction == .area {
            do {
//                try appDelegate.onDragEnd()
            } catch {
                print("onDragComplete: error:", error)
                self.error = error
            }
        }
    }
}


//struct CustomizeWindowView: NSViewRepresentable {
//    
//    class EffectView: NSView {
//        override func viewDidMoveToWindow() {
//            super.viewDidMoveToWindow()
//            print("CustomizeWindowView.viewDidMoveToWindow: window", String(describing: window))
//            window?.titleVisibility = .hidden
//            window?.backgroundColor = .clear
//            window?.titlebarAppearsTransparent = true
//        }
//    }
//    
//    func makeNSView(context: Context) -> EffectView {
////        var view = NSVisualEffectView()
////        view.state = .active // Remain transparent even if unfocused
////        return view
//        let view = EffectView()
//        return view
//    }
//    
//    func updateNSView(_ nsView: EffectView, context: Context) {
//        // Nothing
//    }
//}
//
extension View {
    func errorAlert(error: Binding<Error?>, buttonTitle: String = "OK") -> some View {
        let localizedAlertError = LocalizedAlertError(error: error.wrappedValue)
        return alert(isPresented: .constant(localizedAlertError != nil), error: localizedAlertError) { _ in
            Button(buttonTitle) {
                error.wrappedValue = nil
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "")
        }
    }
}

struct LocalizedAlertError: LocalizedError {
    let underlyingError: LocalizedError
    var errorDescription: String? {
        underlyingError.errorDescription
    }
    var recoverySuggestion: String? {
        underlyingError.recoverySuggestion
    }
    
    init?(error: Error?) {
        guard let localizedError = error as? LocalizedError else {
            if error != nil {
                print("Error not localized: \(String(describing: error))")
            }
            return nil
        }
        underlyingError = localizedError
    }
}

class ImageWindow: NSWindow {
    init(rect: CGRect, image: CGImage) {
        super.init(
            contentRect: rect,
            styleMask: [.closable, .resizable, .titled],
            backing: .buffered,
            defer: false
        )
        
        title = "Image Preview"
        isReleasedWhenClosed = false
        
        let imageView = NSImageView(image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
        contentView = imageView
    }
    
    override var canBecomeKey: Bool {
        true
    }
    
    override var canBecomeMain: Bool {
        true
    }
    
    override func close() {
        appDelegate.removeImageWindow(self)
        super.close()
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
}

class CaptureRectManager {
    static var shared = CaptureRectManager()
    
    class BoxProps: ObservableObject {
        @Published var edges: [Edge] = []
    }
    
    struct BoxView: View {
        @ObservedObject var props: BoxProps
        
        var body: some View {
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(width: 1, edges: props.edges, color: .white)
        }
    }
    
    var windows: [CGDirectDisplayID:(NSPanel, BoxProps)] = [:]
    
    func show(_ rect: NSRect, below: NSWindow? = nil) {
        hide()
        
        for screen in NSScreen.screens {
            guard let id = screen.displayID else {
                continue
            }
            
            let intersection = screen.frame.intersection(rect)
            if intersection.isEmpty {
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
            
            let pair = windows[id] ?? box()
            let (panel, props) = pair
            props.edges = edges
            panel.setFrame(intersection, display: true)
            panel.orderFront(self)
            windows[id] = pair
        }
    }
    
    func hide() {
        windows.values.forEach { $0.0.setIsVisible(false) }
    }
    
    
    
    
    func box() -> (some NSPanel, BoxProps) {
        let props = BoxProps()
        let panel = OverlayPanel(.zero) {
            BoxView(props: props)
        }
        return (panel, props)
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
