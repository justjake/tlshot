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
    static var shared = AppDelegate()
    @AppStorage(SettingsKey.hidePermissionWarning) var hidePermissionWarning: Bool = false
    @AppStorage(SettingsKey.saveFolder) var saveFolder: URL?
    @AppStorage(SettingsKey.windowIncludeShadow) var windowIncludeShadow: Bool = true
    @AppStorage(SettingsKey.windowIncludeDesktop) var windowIncludeDesktop: Bool = false

    @Published var captureAction: CaptureAction? = nil
    @Published var captureMediaType: CaptureMediaType = .image
    @Published var hasPermission: Bool = false
    @Published var imageWindows: [NSWindow] = []
    @Published var mouseLocation: NSPoint = NSEvent.mouseLocation
    @Published var dragStart: NSPoint? = nil
    @Published var mouseScreen: NSScreen? = nil
    @Published var modifierFlags: NSEvent.ModifierFlags = .zero
    @Published var desiredCursor: NSCursor?
    
    static func openSystemSettings() {
        // https://github.com/feedback-assistant/reports/issues/184
        // https://gist.github.com/iccir/c1da6e537718b99b0c14ef76765aec45
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    lazy var mouseListener = EventMonitor(.leftMouse) { @MainActor [self] event in
        updateMouseLocation()
        defer { render() }
        
        // Window
        if captureAction == .window {
            let hovered = WindowPicker.shared.setHovered(point: mouseLocation)
            
            if event.type == .leftMouseUp, let hovered = hovered {
                if modifierFlags.contains(.shift) {
                    WindowPicker.shared.toggleTarget(hovered)
                    return
                }
                
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
                let targets = WindowPicker.shared.removeAllTargets()
                print("  released shift key: \(targets)")
                if targets.count > 0 {
                    handleErrors {
                        try onCaptureWindows(targets, includeDesktop: windowIncludeDesktop)
                    }
                }
            }

            return event
        }
        
        // keyDown
        if event.keyCode == Keycode.escape {
            let prevTargets = WindowPicker.shared.removeAllTargets()
            if prevTargets.count > 0 {
                print("  esc: removed targets instead of closing: \(prevTargets.count)")
                return event
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
        captureAction = action
        captureMediaType = mediaType
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
        defer { updateCursor() }
        
        defer { renderActivationPolicy() }
        
        if captureAction != .window {
            WindowPicker.shared.reset()
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
    
    private func updateCursor() {
        let nextCursor = switch captureAction {
        case .area: NSCursor.crosshair
        case .window: if modifierFlags.contains(.shift) {
            NSCursor.dragCopy
        } else {
            NSCursor.pointingHand
        }
        case nil: NSCursor.arrow
        }
        
        if nextCursor != desiredCursor {
            print("\(self).updateCursor: \(desiredCursor?.debugName ?? "?") -> \(nextCursor.debugName)")
        }
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
        mouseLocation = NSEvent.mouseLocation
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
}
