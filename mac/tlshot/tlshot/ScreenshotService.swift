//
//  ScreenshotService.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/12/24.
//

import AppKit
import CoreGraphics
import Foundation

@objc protocol ScreenshotVisible {
    @objc var includeInScreenshot: Bool { get }
}

// Include our app's normal windows in screenshots
// Can be overwritten on subclasses like OverlayPanel
extension NSWindow: ScreenshotVisible {
    var includeInScreenshot: Bool { true }
}


extension CGWindowLevelKey: CaseIterable, CustomStringConvertible {
    public var description: String {
        let name = switch self {
        case .baseWindow: "baseWindow"
        case .minimumWindow: "minimumWindow"
        case .desktopWindow: "desktopWindow"
        case .backstopMenu: "backstopMenu"
        case .normalWindow: "normalWindow"
        case .floatingWindow: "floatingWindow"
        case .tornOffMenuWindow: "tornOffMenuWindow"
        case .dockWindow: "dockWindow"
        case .mainMenuWindow: "mainMenuWindow"
        case .statusWindow: "statusWindow"
        case .modalPanelWindow: "modalPanelWindow"
        case .popUpMenuWindow: "popUpMenuWindow"
        case .draggingWindow: "draggingWindow"
        case .screenSaverWindow: "screenSaverWindow"
        case .maximumWindow: "maximumWindow"
        case .overlayWindow: "overlayWindow"
        case .helpWindow: "helpWindow"
        case .utilityWindow: "utilityWindow"
        case .desktopIconWindow: "desktopIconWindow"
        case .cursorWindow: "cursorWindow"
        case .assistiveTechHighWindow: "assistiveTechHighWindow"
        case .numberOfWindowLevelKeys: "numberOfWindowLevelKeys"
        @unknown default: "unknown"
        }
        
        return "CGWindowLevelKey.\(name)=\(cgLevel)"
    }

    public static var allCases: [CGWindowLevelKey] {
        [
            baseWindow,
            minimumWindow,
            desktopWindow,
            backstopMenu,
            normalWindow,
            floatingWindow,
            tornOffMenuWindow,
            dockWindow,
            mainMenuWindow,
            statusWindow,
            modalPanelWindow,
            popUpMenuWindow,
            draggingWindow,
            screenSaverWindow,
            maximumWindow,
            overlayWindow,
            helpWindow,
            utilityWindow,
            desktopIconWindow,
            cursorWindow,
            assistiveTechHighWindow,
        ].sorted { $0.cgLevel < $1.cgLevel }
    }
    
    var cgLevel: CGWindowLevel {
        CGWindowLevelForKey(self)
    }
    
    var nsLevel: NSWindow.Level {
        NSWindow.Level(Int(cgLevel))
    }
}

extension NSScreen {
    static var total: CoordRect {
        var rect = CGRect.zero
        for screen in NSScreen.screens {
            rect = rect.union(screen.frame)
        }
        return rect.isNS
    }
}

extension Optional {
    var debug: String? {
        switch self {
        case .some(let v): String(reflecting: v)
        case .none: nil
        }
    }
}

// Synchronous alternative to ScreenCaptureKit that allows fetching a rect across >1 display
class ScreenshotService {
    
    // --------------------------------------
    let debug = false
    // --------------------------------------
    
    
    public private(set) static var shared: ScreenshotService = .init()
    private static let cgWindowLevels: [CGWindowLevelKey] = [
        .backstopMenu,
    ]
    
    struct WindowInfo: CustomStringConvertible, Identifiable {
        static func mock(id: Int) -> WindowInfo {
            .init(id: id, layer: 0, windowName: "Some Window", appPID: 12345, appName: "Dog Food Machine", frame: .cg(.zero), isOnScreen: true)
        }
        
        let id: Int
        
        /// Not quite sure what this means
        let layer: Int
        let windowName: String?
        let appPID: Int
        let appName: String?
        let frame: CoordRect
        let isOnScreen: Bool

        var app: NSRunningApplication? {
            NSRunningApplication(processIdentifier: pid_t(appPID))
        }

        var bundleIdentifier: String? {
            app?.bundleIdentifier
        }

        var levelKey: CGWindowLevelKey? {
            CGWindowLevelKey.allCases.first { layer == $0.cgLevel }
        }
        
        var maxLevelKey: CGWindowLevelKey? {
            CGWindowLevelKey.allCases.first { layer <= $0.cgLevel }
        }
        
        var isDesktopWindow: Bool {
            layer <= CGWindowLevelKey.desktopWindow.cgLevel
        }
        
        var isMainMenuWindow: Bool {
            layer == CGWindowLevelKey.mainMenuWindow.cgLevel
        }
        
        var isCursorWindow: Bool {
            layer == CGWindowLevelKey.cursorWindow.cgLevel
        }
        
        var description: String {
            let parts: [String] = [
                "\(id) \(frame.asCG)",
                "windowName: \(windowName.debug ?? "?")",
                "\(bundleIdentifier ?? appName ?? String(appPID))",
                "\(levelKey.debug ?? String(layer)) (behind \(maxLevelKey.debug ?? "?"))",
                "isOnScreen: \(isOnScreen)",
                "isDesktopWindow: \(isDesktopWindow)"
            ]
            return "WindowInfo(\(parts.joined(separator: ", ")))"
        }
    }

    func windowAt(point: CoordPoint) -> WindowInfo? {
        var candidate = 0
        repeat {
            candidate = NSWindow.windowNumber(at: point.asNS, belowWindowWithWindowNumber: candidate)
            if candidate == 0 {
                return nil
            }
            if !isScreenshotAble(windowNumber: candidate) {
                continue
            }
            if let info = getWindow(windowNumber: candidate) {
                return info
            }
        } while candidate != 0
        return nil
    }

    func isScreenshotAble(windowNumber: Int) -> Bool {
        if let ownWindow = NSApp.window(withWindowNumber: windowNumber) {
            return ownWindow.includeInScreenshot
        }
        return true
    }

    func getWindow(windowNumber: Int) -> WindowInfo? {
        parseWindowInfo(
            CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(windowNumber))
        ).first
    }

    func windows(
        includeAppScreenshotInvisible: Bool = false,
        // Including offscreen windows means CGWindowListCopyWindowInfo
        // returns windows in an undefined order. Trying to use that order for
        // screenshots leads to black rectangles over the image, like after
        // attaching a new display.
        includeOffscreenAndScrambleOrder: Bool = false
    ) -> [WindowInfo] {
        /// https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo
        let windowInfo = parseWindowInfo(CGWindowListCopyWindowInfo(
            includeOffscreenAndScrambleOrder
            // List all windows, including both onscreen and offscreen windows
            // https://developer.apple.com/documentation/coregraphics/cgwindowlistoption/1455377-optionall
            ? .optionAll
            // List all windows that are currently onscreen. Windows are returned in order from front to back.
            // https://developer.apple.com/documentation/coregraphics/cgwindowlistoption/1454105-optiononscreenonly
            : .optionOnScreenOnly, kCGNullWindowID))
        
        if includeAppScreenshotInvisible {
            return windowInfo
        }
        
        return windowInfo.filter { window in
            if window.appPID == ProcessInfo.processInfo.processIdentifier {
                return isScreenshotAble(windowNumber: window.id)
            }
            if window.isCursorWindow {
                // We don't seem to hit this ever, but keeping it in just in case,
                // since I thought I saw some cases where we included the cursor.
                print("exclude cursor window \(window)")
                return false
            }
            return true
        }
    }
    
    func desktopWindows() -> [WindowInfo] {
        return windows().filter { $0.isDesktopWindow }
    }
    
    func screenshot(_ windows: [WindowInfo]) -> CGImage? {
        print("ScreenshotService.screenshot(windows): \(windows)")
        
        if let withShadowViaArray = screenshot(.null, windows: windows) {
            return withShadowViaArray
        }
        
        let union = windows.map { $0.frame.asCG }.reduce(CGRect.zero) { $0.union($1) }
        return screenshot(union.isCG)
    }

    func screenshot(_ window: WindowInfo) -> CGImage? {
        print("ScreenshotService.screenshot(window): \(window)")
        if let withShadow = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.id),
            windowImageOptions
        ) {
            return withShadow
        }

        if let withShadowViaArray = screenshot(.null, windows: [window]) {
            return withShadowViaArray
        }

        // Finder desktop windows (the desktop background specifically)
        // cannot be captured and will return nil from CGWindowListCreatImage
        // We can detect that and opt into taking a flattened screenshot of the same
        // area, essentially capturing the entire display.
        //
        // We could check that window.levelKey === .desktopIconWindow, or we could always
        // try this fallback for any type of window, which seems nicer.
        return screenshot(window.frame)
    }

    func screenshot(_ rect: CoordRect) -> CGImage? {
        // Try to screenshot region excluding own windows
        if let regular = screenshot(rect.asCG, windows: windows()) {
            return regular
        }
        print("screenshoot \(rect): first attempt null, fall back to CGWindowListCreateImage")
        // Fall back to fully flattened image
        return CGWindowListCreateImage(rect.asCG, .optionAll, kCGNullWindowID, baseImageOptions)
    }
    
    func screenshotAll() -> CGImage? {
        screenshot(NSScreen.total)
    }

    private func screenshot(_ rect: CGRect?, windows: [WindowInfo]) -> CGImage? {
        /// This seems like it would work, but doesn't.
        // let nsNumbers = windows.map { NSNumber(value: CGWindowID($0)) }

        // Need to use boxed CGWindowID array. This doesn't look safe.
        // https://stackoverflow.com/questions/28947049/how-to-convert-swift-array-into-cfarray
        let uint32s = windows.map { UInt32($0.id) }
        let pointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: uint32s.count)
        for (index, uint32) in uint32s.enumerated() {
            pointer[index] = UnsafeRawPointer(bitPattern: UInt(uint32))
        }
        let array: CFArray = CFArrayCreate(kCFAllocatorDefault, pointer, uint32s.count, nil)

        let result = CGImage(
            windowListFromArrayScreenBounds: rect ?? .zero,
            windowArray: array,
            imageOption: windowImageOptions
        )
        
        if debug {
            print("ScreenshotService.screenshot(windowArray) rect: \(rect.debug ?? ".null"), windows: \(windows.count)")
            for (index, uint32) in uint32s.enumerated() {
                print("  [\(index)] uint32=\(uint32), info: \(windows[index])")
            }
            print("image:")
            print("  \(result.debug ?? "nil")")
        }
        
        return result
    }

    private func parseWindowInfo(_ cfarray: CFArray?) -> [WindowInfo] {
        guard let raw = cfarray else {
            print("!let raw")
            return []
        }

        guard let dicts = raw as? [NSDictionary] else {
            print("!as [NSDictionary]")
            return []
        }
        
        /*
         // required keys:
         let kCGWindowNumber: CFString
         let kCGWindowStoreType: CFString
         let kCGWindowLayer: CFString
         let kCGWindowBounds: CFString
         let kCGWindowSharingState: CFString
         let kCGWindowAlpha: CFString
         let kCGWindowOwnerPID: CFString
         let kCGWindowMemoryUsage: CFString
         
         // optional keys:
         let kCGWindowWorkspace: CFString // deprecated
         let kCGWindowOwnerName: CFString
         let kCGWindowName: CFString
         let kCGWindowIsOnscreen: CFString
         let kCGWindowBackingLocationVideoMemory: CFString
         */
        return dicts.map { dict in
            WindowInfo(
                id: Int(Int32(truncating: dict[kCGWindowNumber] as! CFNumber)),
                layer: Int(Int32(truncating: dict[kCGWindowLayer] as! CFNumber)),
                windowName: (dict[kCGWindowName] as? String),
                appPID: Int(truncating: dict[kCGWindowOwnerPID] as! CFNumber),
                appName: (dict[kCGWindowOwnerName] as? String),
                frame: CoordRect.cg(.init(dictionaryRepresentation: dict[kCGWindowBounds] as! CFDictionary)!),
                isOnScreen: dict[kCGWindowIsOnscreen] as? Bool ?? false
            )
        }
    }
    
    private var baseImageOptions: CGWindowImageOption {
        return .bestResolution
    }
    
    private var windowImageOptions: CGWindowImageOption {
        var base = baseImageOptions
        if !AppDelegate.shared.windowIncludeShadow {
            base.insert(.boundsIgnoreFraming)
        }
        return base
    }
}
