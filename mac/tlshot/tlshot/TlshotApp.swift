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

extension NSEvent.ModifierFlags {
    static var zero: NSEvent.ModifierFlags { Self(rawValue: 0) }
}


final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static var shared = AppDelegate()
    @AppStorage(SettingsKey.hidePermissionWarning) var hidePermissionWarning: Bool = false
    @AppStorage(SettingsKey.saveFolder) var saveFolder: URL = AppDelegate.defaultSaveFolder()
    @AppStorage(SettingsKey.windowIncludeShadow) var windowIncludeShadow: Bool = true
    @AppStorage(SettingsKey.windowIncludeDesktop) var windowIncludeDesktop: Bool = false

    @Published var captureAction: CaptureAction? = nil
    @Published var captureMediaType: CaptureMediaType = .image
    @Published var hasPermission: Bool = false
    @Published var imageWindows: [NSWindow] = []
    @Published var mouseLocation: NSPoint = NSEvent.mouseLocation
    @Published var capturePhase: CapturePhase = .ended
    @Published var dragStart: NSPoint? = nil
    @Published var mouseScreen: NSScreen? = nil
    @Published var modifierFlags: NSEvent.ModifierFlags = .zero
    
    static func openSystemSettings() {
        // https://github.com/feedback-assistant/reports/issues/184
        // https://gist.github.com/iccir/c1da6e537718b99b0c14ef76765aec45
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    lazy var mouseListener = EventMonitor(.leftMouse) { @MainActor [self] event in
        mouseLocation = NSEvent.mouseLocation
        mouseScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
        
        if captureAction == .window {
            WindowPicker.shared.setTarget(for: mouseLocation)
            
            if event.type == .leftMouseUp {
                guard let target = WindowPicker.shared.clearTarget() else {
                    return
                }
                
                onClickWindow(target)
                return
            }
        }
        
        
        if event.type == .leftMouseDragged && dragStart == nil {
            onDragStart()
            return
        }
        
        if event.type == .leftMouseUp && dragStart != nil {
            onDragEnd()
            return
        }
        
        if let rect = dragRect {
            AreaSelectionOverlayManager.shared.show(rect)
        }
    }
    
    lazy var keyboardListener = EventMonitor([.keyDown, .flagsChanged]) { @MainActor [self] event in
        print("\(self).keyboardListener:", event)
        
        // flagsChanged
        if event.type == .flagsChanged {
            modifierFlags = event.modifierFlags
            render()
            return event
        }
        
        // keyDown
        if event.keyCode == Keycode.escape {
            onCaptureClose()
            return nil
        }
        
        if event.characters == " " {
            captureAction = switch captureAction {
            case .area: .window
            case .window: .area
            case nil: nil
            }
            render()
            return nil
        }
        
        return event
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        renderActivationPolicy()
        hasPermission = CGPreflightScreenCaptureAccess()
        print("\(self).hasPermission: \(hasPermission)")
        
        // TODO: not this
        startCapture(.area)
    }
    
    func showErrorAlert(error: Error) {
        let systemPrefsTag = 64
        // https://stackoverflow.com/questions/18417432/how-to-show-alert-pop-up-in-in-cocoa-on-macos
        print("\(self).showErrorAlert: \(error)")
        let alert = NSAlert(error: error)
        if case .captureFailed = error as? TlshotError {
            let button = alert.addButton(withTitle: "Open System Settings")
            button.tag = systemPrefsTag
            alert.addButton(withTitle: "OK")
        }
        let response = alert.runModal()
        if response.rawValue == systemPrefsTag {
            AppDelegate.openSystemSettings()
        }
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
    
    @MainActor func onClickWindow(_ window: ScreenshotService.WindowInfo) {
        do {
            try onCaptureWindows([window], includeDesktop: windowIncludeDesktop)
        } catch {
            showErrorAlert(error: error)
        }
    }
    
    @MainActor func onDragEnd() {
        defer { dragStart = nil }
        guard let rect = dragRect else {
            print("onDragEnd: no rect?")
            return
        }
        print("onDragEnd", rect)
        
        AreaSelectionOverlayManager.shared.hide()
        
        do {
            try onCaptureRect(area: rect)
        } catch {
            showErrorAlert(error: error)
        }
    }
    
    func startCapture(_ action: CaptureAction, mediaType: CaptureMediaType = .image) {
        // Set state
        captureAction = action
        captureMediaType = mediaType
        render()
    }
    
    func onCaptureClose() {
        modifierFlags = .zero
        captureAction = nil
        render()
    }
    
    func render() {
        defer { renderActivationPolicy() }
        defer { renderCursor() }
        
        if captureAction != .window {
            WindowPicker.shared.clearTarget()
        }
        
        if captureAction == nil {
            mouseListener.stop()
            keyboardListener.stop()
            ShieldOverlayManager.shared.stop()
            AreaSelectionOverlayManager.shared.hide()
            return
        }
        
        ShieldOverlayManager.shared.start()
        mouseListener.start()
        keyboardListener.start()
    }
    
    private func renderCursor() {
        Task { @MainActor in
            let cursor = switch captureAction {
            case .area: NSCursor.crosshair
            case .window: if modifierFlags.contains(.shift) {
                NSCursor.dragCopy
            } else {
                NSCursor.pointingHand
            }
            case nil: NSCursor.arrow
            }
            
            cursor.set()
        }
    }
    
    @MainActor func onCaptureRect(area: CGRect) throws {
        onCaptureClose()
        if let image = ScreenshotService.shared.screenshot(area.isNS) {
            print("got image: \(image)")
            editImage(image, frame: area)
        } else {
            throw TlshotError.captureFailed("System didn't return an image")
        }
    }
    
    @MainActor func onCaptureWindows(_ windows: [ScreenshotService.WindowInfo], includeDesktop: Bool) throws {
        onCaptureClose()
        print("\(self).onCaptureWindows:", windows)
        var included = windows
        let bounds = included.map { $0.frame }.union().asCG
        if includeDesktop {
            let desktopWindows = ScreenshotService.shared.desktopWindows()
            let intersectingWindows =  desktopWindows.filter { $0.frame.asCG.intersects(bounds) }
            print("  includeDesktop: bounds: \(bounds)")
            print("  includeDesktop: desktopWindows: \(desktopWindows)")
            print("  includeDesktop: intersectingWindows: \(intersectingWindows)")
            included.append(contentsOf: intersectingWindows)
        }
        if let image = ScreenshotService.shared.screenshot(included) {
            print("onCaptureWindow: got image \(image)")
            editImage(image, frame: bounds.isCG.asNS)
        } else {
            throw TlshotError.captureFailed("System didn't return an image")
        }
    }
    
    @MainActor func onCaptureFullscreen() throws {
        onCaptureClose()
        print("\(self).onCaptureFullscreen")
        if let image = ScreenshotService.shared.screenshotAll() {
            print("onCaptureFullscreen: got image \(image)")
            editImage(image, frame: NSScreen.main?.visibleFrame ?? .zero)
        } else {
            throw TlshotError.captureFailed("System didn't return an image")
        }
    }
    
    func handleErrors(block: () throws -> Void) -> Void {
        do {
            return try block()
        } catch {
            showErrorAlert(error: error)
        }
    }
    
    @MainActor func editImage(_ image: CGImage, frame: CGRect) {
        let window = ImageWindow(rect: frame, image: image)
        imageWindows.append(window)
        render()
        
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    func renderActivationPolicy() {
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
        renderActivationPolicy()
    }
}

extension URL {
    var describeHomedirRelative: String {
        let relative = self.relativePath
        let homedir = FileManager.default.homeDirectoryForCurrentUser.relativePath
        return relative.replacing(homedir, with: "~")
    }
}

struct SettingsKey {
    static let windowIncludeDesktop = "windowIncludeDesktop"
    static let windowIncludeMenuBarWithDesktop = "windowIncludeMenuBarWithDesktop"
    static let windowIncludeShadow = "windowIncludeShadow"
    static let hidePermissionWarning = "hidePermissionWarning"
    static let saveFolder = "saveFolder"
    
    private init() {}
}

@main
struct TlshotApp: App {
    
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @AppStorage(SettingsKey.saveFolder) private var saveFolder: URL = AppDelegate.defaultSaveFolder()
    @AppStorage(SettingsKey.windowIncludeShadow) private var windowIncludeShadow: Bool = true
    @AppStorage(SettingsKey.windowIncludeDesktop) private var windowIncludeDesktop: Bool = false
    @AppStorage(SettingsKey.windowIncludeMenuBarWithDesktop) private var windowIncludeMenuBarWithDesktop = false

    var body: some Scene {
        DocumentGroup(newDocument: TldrawDocument()) { group in
            ContentView(document: group.$document)
        }
        
        MenuBarExtra("tlshot") {
            Button("Capture Area") {
                appDelegate.startCapture(.area)
            }
            Button("Capture Window") {
                appDelegate.startCapture(.window)
            }
            Button("Capture Fullscreen") {
                appDelegate.handleErrors {
                    try appDelegate.onCaptureFullscreen()
                }
            }
//            Button("Record video") {
//                appDelegate.startCapture(.area, mediaType: .video)
//            }
            
            Divider()
            
            Text("Save to \(saveFolder.describeHomedirRelative)")
            Button("Choose folder...") {
                fatalError("Not implemented")
            }
            
            Divider()
            
            Text("When capturing windows...")
            Toggle("Include shadow", isOn: Binding(
                get: { windowIncludeShadow || windowIncludeDesktop },
                set: { windowIncludeShadow = $0 }
            ))
                .disabled(windowIncludeDesktop)
            Toggle("Include desktop", isOn: $windowIncludeDesktop)
            Toggle("Include menu bar with desktop", isOn: $windowIncludeMenuBarWithDesktop)
                .disabled(!windowIncludeDesktop)
            
            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(self)
            }.keyboardShortcut("Q", modifiers: .command)
        }
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
    @State private var showWarningView = true
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
                if !appDelegate.hasPermission && !appDelegate.hidePermissionWarning && showWarningView {
                    PermissionWarningView() {
                        print("Close warning view")
                        showWarningView = false
                    }
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
            .onChanged { @MainActor in
                switch mouse {
                case .drag: break
                default: break
//                default: appDelegate.onDragStart()
                }
                mouse = .drag(start: $0.startLocation, current: $0.location)
            }.onEnded { @MainActor in
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



