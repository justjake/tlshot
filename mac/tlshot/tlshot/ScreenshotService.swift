//
//  ScreenshotService.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/12/24.
//

import Foundation
import AppKit
import CoreGraphics

@objc protocol ScreenshotVisible {
    @objc var includeInScreenshot: Bool { get }
}

// Include our app's normal windows in screenshots
// Can be overwritten on subclasses like OverlayPanel
extension NSWindow: ScreenshotVisible {
    var includeInScreenshot: Bool { true }
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

// Synchronous alternative to ScreenCaptureKit that allows fetching a rect across >1 display
class ScreenshotService {
    static public private(set) var shared: ScreenshotService = ScreenshotService()
    
    struct WindowInfo {
        let windowID: Int
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
        
//        var layerName: String {
//            let layer = CGWindowLevelKey(rawValue: Int32(layer))!
//            print(String(reflecting: layer))
//            print("\(layer)")
//            return switch layer {
//            case .assistiveTechHighWindow: "assistiveTechHighWindow"
//            case .desktopWindow: "desktopWindow"
//            case .desktopIconWindow: "desktopIconWindow"
//            case .baseWindow: "baseWindow"
//            case .
//            default: "TODO"
//            }
//        }
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
            print("Matched own window: \(windowNumber)", ownWindow)
            return ownWindow.includeInScreenshot
        }
        return true
    }
    
    /// https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo
    func allWindows() -> [WindowInfo] {
        parseWindowInfo(CGWindowListCopyWindowInfo(.optionAll, 0))
    }
    
    func getWindow(windowNumber: Int) -> WindowInfo? {
        parseWindowInfo(
            CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(windowNumber))
        ).first
    }
    
    func windows(
        includeOffscreen: Bool = false,
        includeAppScreenshotInvisible: Bool = false
    ) -> [WindowInfo] {
        allWindows().filter { window in
            if !window.isOnScreen && !includeOffscreen {
                return false
            }
            
            if !includeAppScreenshotInvisible && window.appPID == ProcessInfo.processInfo.processIdentifier {
                return isScreenshotAble(windowNumber: window.windowID)
            }
            
            return true
        }
    }
    
    func screenshot(_ window: WindowInfo) -> CGImage? {
        print("ScreenshotService.screenshot(window): \(window)")
        if let withShadow = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowID),
            .bestResolution
        ) {
            return withShadow
        }
        
        if let withShadowViaArray = screenshot(window.frame.asCG, windows: [window]) {
            return withShadowViaArray
        }
        
        // Finder desktop windows (the desktop background specifically)
        // cannot be captured and will return nil from CGWindowListCreatImage
        // We can detect that and opt into taking a flattened screenshot of the same
        // area, essentially capturing the entire display.
        print("  null window screenshot of window of app \(window.bundleIdentifier ?? "?") \(window.app?.bundleURL.map { String(describing: $0) } ?? "?")")
        
        return screenshot(window.frame)
    }
    
    func screenshot(_ rect: CoordRect) -> CGImage? {
        // Try to screenshot region excluding own windows
        return screenshot(rect.asCG, windows: windows())
            // Fall back to fully flattened image
            ?? CGWindowListCreateImage(rect.asCG, .optionAll, kCGNullWindowID, .bestResolution)
    }
    
    func screenshot(_ rect: CGRect, windows: [WindowInfo]) -> CGImage? {
        return cgWindowListFromArrayScreenBounds(rect, windows: windows.map { $0.windowID })
    }
    
    private func cgWindowListFromArrayScreenBounds(_ rect: CGRect, windows: [Int]) -> CGImage? {
        /// This seems like it would work, but doesn't.
        // let nsNumbers = windows.map { NSNumber(value: CGWindowID($0)) }
        
        // Need to use boxed CGWindowID array. This doesn't look safe.
        // https://stackoverflow.com/questions/28947049/how-to-convert-swift-array-into-cfarray
        let uint32s = windows.map { UInt32($0) }
        let pointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: uint32s.count)
        for (index, window) in windows.enumerated() {
            pointer[index] = UnsafeRawPointer(bitPattern: UInt(window))
        }
        let array: CFArray = CFArrayCreate(kCFAllocatorDefault, pointer, windows.count, nil)
        
        return CGImage(
            windowListFromArrayScreenBounds: rect,
            windowArray: array,
            imageOption: .bestResolution
        )
//        return CGImage(windowListFromArrayScreenBounds: rect, windowArray: asCG, imageOption: [.all .bestResolution, .shouldBeOpaque])
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
        return dicts.map { dict in
            WindowInfo(
                windowID: Int(Int32(truncating: dict[kCGWindowNumber] as! CFNumber)),
                layer: Int(Int32(truncating: dict[kCGWindowLayer] as! CFNumber)),
                windowName: (dict[kCGWindowName] as? String),
                appPID: Int(truncating: dict[kCGWindowOwnerPID] as! CFNumber),
                appName: (dict[kCGWindowOwnerName] as? String),
                frame: CoordRect.cg(.init(dictionaryRepresentation: dict[kCGWindowBounds] as! CFDictionary)!),
                isOnScreen: dict[kCGWindowIsOnscreen] as? Bool ?? false
            )
        }
    }
}
