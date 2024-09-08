//
//  AppDelegate.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/13/24.
//

import AppKit
import SwiftUI
import CoreGraphics
import UserNotifications
import KeyboardShortcuts

struct CaptureResult {
    let frame: CGRect
    let image: CGImage
    var action: CaptureAction? = nil
    var windows: [ScreenshotService.WindowInfo]? = nil
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, UNUserNotificationCenterDelegate {
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
    @AppStorage(SettingsKey.windowIncludeShadow) var windowIncludeShadow: Bool = true
    @AppStorage(SettingsKey.windowIncludeDesktop) var windowIncludeDesktop: Bool = false
    @AppStorage(SettingsKey.afterSaveAction) var afterSaveAction: AfterSaveAction = .none

    @Published var cameraCursor: NSCursor?
    @Published var cameraPlusCursor: NSCursor?
    @Published var cameraMinusCursor: NSCursor?
    
    @Published var hasPermission: Bool = false
    @Published var desiredCursor: NSCursor?
    
    // capture state
    @Published var captureAction: CaptureAction? = nil
    @Published var captureMediaType: CaptureMediaType = .image // TODO
    var captureCallback: ((Result<CaptureResult, Error>) -> Void)?

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
    @Published var saveDirectory = SaveDirectory()
    
    let nextEditWindow = EditWindowCache()
    
    static func openSystemSettings() {
        // https://github.com/feedback-assistant/reports/issues/184
        // https://gist.github.com/iccir/c1da6e537718b99b0c14ef76765aec45
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        //        NSWindow.swizzle()
        //        NSCursor.swizzle()
        AppDelegate.shared = self
        Notif.CategoryID.register()
        UNUserNotificationCenter.current().delegate = self
        
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
        
        observeWindowWillClose()
        renderActivationPolicy()
        hasPermission = CGPreflightScreenCaptureAccess()
        
        KeyboardShortcuts.onKeyDown(for: .captureArea) {
            self.startCapture(.area)
        }
        
        KeyboardShortcuts.onKeyDown(for: .captureWindow) {
            self.startCapture(.window)
        }
        
        KeyboardShortcuts.onKeyDown(for: .captureFullscreen) {
            self.handleErrors {
                try self.onCaptureFullscreen()
            }
        }
        
        //#if DEBUG
        //        // TODO: not this
        //        startCapture(.area)
        //#endif
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
    
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        let category = Notif.CategoryID(rawValue: categoryIdentifier)
        await handleErrors {
            switch category {
            case .savedFile: try Notif.SavedFile.fromNotification(response).performResponseAction()
            case .copyAndClose: try Notif.CopyAndClose.fromNotification(response).copyToClipboard()
            case .none:
                throw TlshotError.invalidData("Unknown notification category \(categoryIdentifier)")
            }
            
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return .banner
    }
    
    private let systemPrefsTag = 64
    
    private func buildAlert(error: Error) -> NSAlert {
        let systemPrefsTag = 64
        // https://stackoverflow.com/questions/18417432/how-to-show-alert-pop-up-in-in-cocoa-on-macos
        print("\(self).buildAlert: \(error)")
        let alert = NSAlert(error: error)
        if case .captureFailed = error as? TlshotError {
            let button = alert.addButton(withTitle: "Open System Settings")
            button.tag = systemPrefsTag
            alert.addButton(withTitle: "OK")
        }
        return alert
    }
    
    private func observeWindowWillClose() {
        Task {
            for await _ in await NotificationCenter.default.notifications(named: NSWindow.willCloseNotification) {
                renderActivationPolicyAfterDelay()
                
            }
        }
    }
    
    
    private func handleAlertResponse(_ response: NSApplication.ModalResponse) {
        if response.rawValue == systemPrefsTag {
            AppDelegate.openSystemSettings()
        }
    }
    
    @MainActor
    func showErrorAlert(error: Error) {
        let alert = buildAlert(error: error)
        handleAlertResponse(alert.runModal())
    }
    
    @MainActor
    func showErrorAlert(error: Error, for window: NSWindow) async {
        let alert = buildAlert(error: error)
        let response = await alert.beginSheetModal(for: window)
        handleAlertResponse(response)
    }
    
    func getImageName() -> String {
        var formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss a"
        let now = formatter.string(from: Date.now)
        return "Screenshot \(now)"
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
            onCaptureError(error)
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
            onCaptureError(error)
        }
    }
    
    @MainActor
    func onCaptureError(_ error: Error) {
        if let callback = captureCallback {
            callback(.failure(error))
        } else {
            showErrorAlert(error: error)
        }
    }
    
    func performCapture(_ action: CaptureAction, mediaType: CaptureMediaType = .image) async throws -> CaptureResult {
        guard captureCallback == nil, captureAction == nil else {
            throw TlshotError.captureFailed("Already a capture in progress")
        }
        async let result = withCheckedThrowingContinuation { cont in
            captureCallback = {
                self.captureCallback = nil
                cont.resume(with: $0)
            }
        }
        await startCapture(action, mediaType: mediaType)
        return try await result
    }
    
    @MainActor
    func startCapture(_ action: CaptureAction, mediaType: CaptureMediaType = .image) {
        captureAction = action
        captureMediaType = mediaType
        dragCancelling = false
        updateMouseLocation()
        render()
        Task {
            nextEditWindow.ensureCache()
            render()
        }
    }
    
    @MainActor
    func onCaptureClose() {
        if let callback = captureCallback {
            callback(.failure(TlshotError.captureCancelled))
        }
        
        modifierFlags = .zero
        captureAction = nil
        nextEditWindow.clearCache()
        updateMouseLocation()
        render()
    }
    
    @MainActor
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
//            CursorDecorationOverlay.shared.show(point: mouseLocation)
            ShieldOverlayManager.shared.start()
        } else {
            ShieldOverlayManager.shared.stop()
//            CursorDecorationOverlay.shared.hide()
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
            print("\(self).updateCursor: \(desiredCursor?.debugName ?? "?") -> \(nextCursor.debugName)")
        }
        
        // This should be applied by CursorView
        // in the ShieldWindow overlays over each display.
        // It still flickers sometimes or doesn't stick
        // when first enabled, idk why, leaving it alone
        // for now.
        desiredCursor = nextCursor
    }
    
    func saveImage(name: String, data: Data) async throws {
        print("\(self).saveImage(\(name))")
        // Ensure we have a folder, if we don't, cancel.
        do {
            _ = try await saveDirectory.getOrChooseSaveFolder()
        } catch {
            if let tlerror = error as? TlshotError, tlerror == .pickSaveFolderCancelled {
                print("\(self).saveImage: Picking save folder cancelled, abort save")
                return
            }
            throw error
        }
        
        let url = try await saveDirectory.saveImage(name: name, data: data)
        let context = Notif.SavedFile(fileURL: url, pngImageData: data, responseAction: nil)
        
        print("\(self).saveImage(\(name)): afterSaveAction \(afterSaveAction)")
        switch afterSaveAction {
        case .showNotification:
            try await context.sendNotification()
        case .revealInFinder:
            context.revealInFinder()
        case .showNotificationAndCopy:
            context.copyToClipboard()
            try await context.sendNotification()
        case .none:
            return
        }
    }
    
    func getSaveFolder() throws -> URL? {
        return try saveDirectory.getSaveFolder()
    }
    
    @MainActor func onChooseSaveFolder() {
        do {
            try saveDirectory.chooseSaveFolder()
        } catch {
            print("onChooseSaveFolder: \(error)")
        }
    }
    
    @MainActor func onCaptureRect(area: CGRect) throws {
        defer { onCaptureClose() }
//        print("onCaptureRect(\(area)")
//        let screen = NSScreen.screens.first { $0.frame.intersects(area) }
//        if let screen = screen {
//            print("  screen: \(screen)")
//            print("  screen.frame: \(screen.frame)")
//            print("  info: \(screen.deviceDescription)")
//            print("  backingRect: \(screen.convertRectToBacking(area))")
//            print("  backingScaleFactor: \(screen.backingScaleFactor)")
//        }
        if let image = ScreenshotService.shared.screenshot(area.isNS) {
            print("\(self).onCaptureRect image: \(image)")
            onCaptureSuccess(image, frame: area, windows: nil)
        } else {
            throw TlshotError.captureFailed("System didn't return an image")
        }
    }
    
    @MainActor func onCaptureWindows(_ windows: [ScreenshotService.WindowInfo]) throws {
        defer { onCaptureClose() }
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
            onCaptureSuccess(image, frame: bounds.isCG.asNS, windows: included)
        } else {
            throw TlshotError.captureFailed("System didn't return an image")
        }
    }
    
    @MainActor func onCaptureFullscreen() throws {
        defer { onCaptureClose() }
        print("\(self).onCaptureFullscreen")
        if let image = ScreenshotService.shared.screenshotAll() {
            print("onCaptureFullscreen: got image \(image)")
            onCaptureSuccess(image, frame: NSScreen.main?.visibleFrame ?? .zero, windows: nil)
        } else {
            throw TlshotError.captureFailed("System didn't return an image")
        }
    }
    
    @MainActor
    func handleErrors(block: () throws -> Void) -> Void {
        do {
            return try block()
        } catch {
            showErrorAlert(error: error)
        }
    }
    
    func handleErrors(block: () async throws -> Void) async -> Void {
        do {
            return try await block()
        } catch {
            await showErrorAlert(error: error)
        }
    }
    
    @MainActor func onCaptureSuccess(_ image: CGImage, frame: CGRect, windows: [WindowInfo]?) {
        if let callback = captureCallback {
            let result = CaptureResult(frame: frame, image: image, action: captureAction, windows: windows)
            callback(.success(result))
            return
        }
        editImage(image, frame: frame)
    }

    @MainActor func editImage(_ image: CGImage, frame: CGRect) {
        let usable = NSScreen.main?.visibleFrame ?? .infinite
        let width = min(usable.width * 0.9, max(400, frame.width))
        let height = min(usable.height * 0.9, max(400, frame.height))
        let windowFrame = CGRect(center: frame.center, size: CGSize(width: width, height: height))
        let window = nextEditWindow.getWindow()
        let imageName = getImageName()
        Task {
            await handleErrors { @MainActor in
                await window.waitForRender()
                try await window.addInitialImage(image: image, name: imageName, frame: windowFrame)
                withForegroundActivation {
                    window.makeKeyAndOrderFront(nil)
                    window.makeMain()
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    func renderActivationPolicyAfterDelay() {
        Task {
            try await Task.sleep(for: .milliseconds(100))
            await renderActivationPolicy()
        }
        
    }
    
    @MainActor
    var forceForeground = 0
    
    @MainActor
    func withForegroundActivation(block: () -> Void) {
        forceForeground += 1
        render()
        block()
        forceForeground -= 1
        render()
    }
    
    @MainActor
    func renderActivationPolicy() {
        let normalWindows = NSApp.windows.filter {
            if $0.level == .normal && $0.canBecomeMain && $0.isVisible && !$0.isFloatingPanel {
                return true
            }
            return false
        }
        print("renderActivationPolicy: have windows", normalWindows)
        
        let policy: NSApplication.ActivationPolicy = if forceForeground > 0 || normalWindows.count > 0 {
            .regular
        } else {
            .accessory
        }
        
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
            if policy == .regular {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func debugWindows() {
        var seen = Set<Int>()
        for (i, window) in NSApp.orderedWindows.enumerated() {
            seen.insert(window.windowNumber)
            print("[\(i)] \(window.tldebug)")
        }
        
        for (i, window) in NSApp.windows.enumerated() {
            if seen.contains(window.windowNumber) {
                continue
            }
            print("[\(i)] unordered \(window.tldebug)")
        }
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

class EditWindowCache {
    var cachedWindow: ImageEditWindow? = nil
        
    func ensureCache() {
        cachedWindow = cachedWindow ?? createWindow()
    }
    
    func clearCache() {
        popWindow()?.close()
    }
    
    func getWindow() -> ImageEditWindow {
        popWindow() ?? createWindow()
    }
    
    private func popWindow() -> ImageEditWindow? {
        guard let window = cachedWindow else {
            return nil
        }
        
        cachedWindow = nil
        return window
    }
    
    private func createWindow() -> ImageEditWindow {
        let window = ImageEditWindow(rect: NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 800, height: 600))
        window.orderOut(nil)
        return window
    }
}
