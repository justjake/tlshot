//
//  AppDelegate.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/13/24.
//

import AppKit
import SwiftUI
import CoreGraphics


final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    typealias WindowInfo = ScreenshotService.WindowInfo
    
    enum ShiftClickHoverState {
        case adding(WindowInfo)
        case removing(WindowInfo)
    }

    static var shared = AppDelegate()
    
    static var isSwiftPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    let isSwiftPreview = AppDelegate.isSwiftPreview
    
    // App state
    @AppStorage(SettingsKey.hidePermissionWarning) var hidePermissionWarning: Bool = false
    @AppStorage(SettingsKey.saveFolder) var saveFolder: URL?
    @AppStorage(SettingsKey.windowIncludeShadow) var windowIncludeShadow: Bool = true
    @AppStorage(SettingsKey.windowIncludeDesktop) var windowIncludeDesktop: Bool = false

    @Published var cameraCursor: NSCursor?
    @Published var cameraPlusCursor: NSCursor?
    @Published var cameraMinusCursor: NSCursor?
    
    @Published var hasPermission: Bool = false
    @Published var imageWindows: [NSWindow] = []
    @Published var desiredCursor: NSCursor?
    
    // capture state
    @Published var captureAction: CaptureAction? = nil
    @Published var captureMediaType: CaptureMediaType = .image // TODO

    @Published var mouseLocation: NSPoint = NSEvent.mouseLocation.rounded()
    @Published var mouseScreen: NSScreen? = nil

    // capture.area state
    @Published var dragStart: NSPoint? = nil
    @Published var dragCancelling = false

    // capture.window state
    @Published var hoveredWindow: WindowInfo?
    @Published var selectedWindows: [WindowInfo] = []
    @Published var modifierFlags: NSEvent.ModifierFlags = .zero
    var shiftClickHoverState: ShiftClickHoverState? {
        hoveredWindow.flatMap { computeShiftClickHoverState(hovered: $0) }
    }
    
    @Published var imageByHash: [Int:CGImage] = [:]
    
    static func openSystemSettings() {
        // https://github.com/feedback-assistant/reports/issues/184
        // https://gist.github.com/iccir/c1da6e537718b99b0c14ef76765aec45
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    lazy var mouseListener = EventMonitor(.leftMouse) { @MainActor [self] event in
        updateMouseLocation()
        if isSwiftPreview {
            return
        }
        
        defer { render() }
        
        // Window
        if captureAction == .window {
            hoveredWindow = ScreenshotService.shared.windowAt(point: mouseLocation.isNS)
            if event.type == .leftMouseUp, let hovered = hoveredWindow {
                onClickWindow(hovered)
                return
            }
            
            return
        }
        
        
        // Area
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
        defer { render() }
        
        // flagsChanged
        if event.type == .flagsChanged {
            let removedShift = modifierFlags.contains(.shift) && !event.modifierFlags.contains(.shift)
            modifierFlags = event.modifierFlags
            
            // Window Shift+Click complete
            if removedShift && captureAction == .window {
                let targets = self.selectedWindows
                self.selectedWindows = []
                print("  released shift key: \(targets)")
                if targets.count > 0 {
                    handleErrors {
                        try onCaptureWindows(targets)
                    }
                }
            }
            return event
        }
        
        // keyDown
        if event.keyCode == Keycode.escape {
            let prevTargets = selectedWindows
            if prevTargets.count > 0 {
                print("  esc: removed targets instead of closing: \(prevTargets.count)")
                selectedWindows = []
                return nil
            }
            
            if let dragStart = dragStart {
                print("  esc: removing drag start instead of closing: \(dragStart)")
                self.dragCancelling = true
                return nil
            }
            
            onCaptureClose()
            return nil
        }
        
        if event.characters == " " {
            captureAction = switch captureAction {
            case .area: .window
            case .window: .area
            case nil: nil
            }
            return nil
        }
        
        return event
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        if isSwiftPreview {
            return
        }
        
        // Build our mouse cursors
        Task {
            let cameraPath = try! await Cursors.cameraPath.buildAsync()
            let cameraViewBuilder = CameraViewBuilder(cameraPath!)
            
            func makeCursor(name: String, image: CGImage?, size: CGSize? = nil, offset: CGSize? = nil) -> NSCursor {
                let nsImage: NSImage = image!.nsImage(size: size)!
                nsImage.setName(name)
                return NSCursor(image: nsImage, hotSpot: nsImage.size.center.d(x: offset?.width ?? 0, y: offset?.height ?? 0))
            }
            
            Task { @MainActor in
                self.cameraCursor = makeCursor(
                    name: "Camera",
                    image: cameraViewBuilder.cameraRenderer.render(),
                    size: .init(square: 28)
                )
                
                let badgeOffset = CGSize(width: -4, height: -4)
                let badgeSize = CGSize(square: 36)
                self.cameraPlusCursor = makeCursor(
                    name: "CameraPlus",
                    image: cameraViewBuilder.cameraPlusRenderer.render(),
                    size: badgeSize,
                    offset: badgeOffset
                )
                self.cameraMinusCursor = makeCursor(
                    name: "CameraMinus",
                    image: cameraViewBuilder.cameraMinusRenderer.render(),
                    size: badgeSize,
                    offset: badgeOffset
                )
            }
        }

        
        renderActivationPolicy()
        hasPermission = CGPreflightScreenCaptureAccess()
        
#if DEBUG
        // TODO: not this
        startCapture(.window)
#endif
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
        if dragCancelling {
            return
        }
        dragStart = NSEvent.mouseLocation.rounded()
        print("onDragStart", dragStart)
    }
    
    var dragRect: NSRect? {
        if dragCancelling {
            return nil
        }
        if let p1 = dragStart {
            return NSRect(p1, mouseLocation)
        }
        return nil
    }
    
    @MainActor func onClickWindow(_ window: ScreenshotService.WindowInfo) {
        // Shift-click: add window to set of windows
        switch shiftClickHoverState {
        case .adding(let windowInfo):
            selectedWindows.append(windowInfo)
            return
        case .removing(let windowInfo):
            selectedWindows.removeAll { $0.id == windowInfo.id }
            return
        case nil: break
        }
        
        // Regular click: pick that win!
        do {
            try onCaptureWindows([window])
        } catch {
            showErrorAlert(error: error)
        }
    }
    
    @MainActor func onDragEnd() {
        defer {
            dragStart = nil
            dragCancelling = false
        }
        guard let rect = dragRect else {
            print("onDragEnd: no rect?")
            return
        }
        print("onDragEnd", rect)
        do {
            try onCaptureRect(area: rect)
        } catch {
            showErrorAlert(error: error)
        }
    }
    
    func startCapture(_ action: CaptureAction, mediaType: CaptureMediaType = .image) {
        captureAction = action
        captureMediaType = mediaType
        dragCancelling = false
        updateMouseLocation()
        render()
    }
    
    func onCaptureClose() {
        modifierFlags = .zero
        captureAction = nil
        updateMouseLocation()
        render()
    }
    
    func render() {
        updateCursor()
        defer { renderActivationPolicy() }
        
        // Render area
        if captureAction == .area, let dragRect = self.dragRect {
            AreaSelectionOverlayManager.shared.show(dragRect)
        } else {
            AreaSelectionOverlayManager.shared.hide()
        }
        
        // Render window picker
        if captureAction == .window {
            WindowPicker.shared.show(
                hovered: hoveredWindow,
                selected: selectedWindows
            )
        } else {
            WindowPicker.shared.hide()
        }
        
        // Render global captureAction stuff
        if captureAction != nil {
            keyboardListener.start()
            mouseListener.start()
            CursorDecorationOverlay.shared.show(point: mouseLocation)
            ShieldOverlayManager.shared.start()
        } else {
            ShieldOverlayManager.shared.stop()
            CursorDecorationOverlay.shared.hide()
            mouseListener.stop()
            keyboardListener.stop()
        }
    }
    
    private func updateCursor() {
        let nextCursor = switch captureAction {
        case .area: NSCursor.crosshair
        case .window: switch shiftClickHoverState {
            case .adding(let windowInfo): cameraPlusCursor ?? NSCursor.dragCopy
            case .removing(let windowInfo): cameraMinusCursor ?? NSCursor.pointingHand
            case nil: cameraCursor ?? NSCursor.pointingHand
        }
        case nil: NSCursor.arrow
        }
        
        if nextCursor != desiredCursor {
//            print("\(self).updateCursor: \(desiredCursor?.debugName ?? "?") -> \(nextCursor.debugName)")
        }
        
        // This should be applied by CursorView
        // in the ShieldWindow overlays over each display.
        // It still flickers sometimes or doesn't stick
        // when first enabled, idk why, leaving it alone
        // for now.
        desiredCursor = nextCursor
    }
    
    @MainActor func onChooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.message = "Tlshot will save all captures here"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            self.saveFolder = url
        }
    }
    
    @MainActor func onCaptureRect(area: CGRect) throws {
        onCaptureClose()
        if let image = ScreenshotService.shared.screenshot(area.isNS) {
            print("\(self).onCaptureRect image: \(image)")
            editImage(image, frame: area)
        } else {
            throw TlshotError.captureFailed("System didn't return an image")
        }
    }
    
    @MainActor func onCaptureWindows(_ windows: [ScreenshotService.WindowInfo]) throws {
        onCaptureClose()
        print("\(self).onCaptureWindows:", windows)
        var included = windows
        let bounds = included.map { $0.frame }.union().asCG
        if windowIncludeDesktop {
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
        self.imageByHash[image.hashValue] = image
        let usable = NSScreen.main?.visibleFrame ?? .infinite
        let width = min(usable.width * 0.9, max(400, frame.width))
        let height = min(usable.height * 0.9, max(400, frame.height))
        let windowFrame = CGRect(center: frame.center, size: CGSize(width: width, height: height))
        let window = ImageWindow(rect: windowFrame, image: image, edit: true)
        imageWindows.append(window)
        render()
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
    }
    
    func renderActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = if imageWindows.count > 0 {
            .regular
        } else {
            .accessory
        }
        
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
            if policy == .regular {
                NSApp.activate()
            }
        }
    }
    
    func removeImageWindow(_ window: NSWindow) {
        self.imageWindows.removeAll(where: { $0 == window })
        renderActivationPolicy()
    }
    
    private func updateMouseLocation() {
        mouseLocation = NSEvent.mouseLocation.rounded()
        mouseScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
        
        // Debugging
        // Confirmed that black rectangle after new display plugged not our fault?
//        let lowLevelEvent = CGEvent(source: .none)
//        if let location = lowLevelEvent?.location {
//            print()
//            print("  mouse NS:      \(mouseLocation)")
//            print("  mouse NS.asCG: \(mouseLocation.isNS.asCG)")
//            print("  mouse CG:      \(location)")
//        }

        
    }
        
    func computeShiftClickHoverState(hovered: WindowInfo) -> ShiftClickHoverState? {
        if captureAction != .window {
            return nil
        }
        
        if !modifierFlags.contains(.shift) {
            return nil
        }
        
        if selectedWindows.contains(where: { $0.id == hovered.id }) {
            return .removing(hovered)
        } else {
            return .adding(hovered)
        }
    }

}
