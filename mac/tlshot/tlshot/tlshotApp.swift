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
    @AppStorage("saveFolder") var saveFolder: URL = AppDelegate.defaultSaveFolder()
    @AppStorage("warnWhenScreenRecordingPermissionDenied") var warnIfDenied: Bool = true
    
    @Published var captureAction: CaptureAction? = nil
    @Published var captureMediaType: CaptureMediaType = .image
    @Published var captureWindow: CaptureWindow? = nil
    @Published var hasPermission: Bool = false
    @Published var imageWindows: [NSWindow] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setActivationPolicy()
        hasPermission = CGPreflightScreenCaptureAccess()
        print("\(self).hasPermission: \(hasPermission)")
        
        // TODO: not this
        startCapture(.area)
    }
    
    func startCapture(_ action: CaptureAction, mediaType: CaptureMediaType = .image) {
        captureAction = action
        captureMediaType = mediaType
        var rect: NSRect = .infinite
        if let screen = NSScreen.main {
            rect = screen.frame
        }
        NSApp.activate()
        let captureWindow = self.captureWindow ?? CaptureWindow(appDelegate: self, view: { CaptureView(window: $0) }, contentRect: rect)
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
        let window = ImageWindow(appDelegate: self, rect: frame, image: image)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(self)
        imageWindows.append(window)
        setActivationPolicy()
    }
    
    func setActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = if imageWindows.count > 0 {
            .regular
        } else {
            .accessory
        }
        NSApp.setActivationPolicy(policy)
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
                guard let screen = window.screen else {
                    throw TlshotError.captureFailed("No screen")
                }
                let flipped = rect.toNS(screen: screen)
                try appDelegate.onCaptureRect(area: flipped)
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
    var appDelegate: AppDelegate? = nil
    
    init(appDelegate: AppDelegate, rect: CGRect, image: CGImage) {
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
        appDelegate?.removeImageWindow(self)
        appDelegate = nil
        super.close()
    }
}
