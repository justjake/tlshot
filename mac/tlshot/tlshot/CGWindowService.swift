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
class CGWindowService {
    static public private(set) var shared: CGWindowService = CGWindowService()
    
    struct WindowInfo {
        let windowID: Int
        let layer: Int
        let appPID: Int
        let appName: String?
        let frame: CoordRect
        let isOnScreen: Bool
    }
    
    /// https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo
    func allWindows() -> [WindowInfo] {
        guard let raw = CGWindowListCopyWindowInfo(.optionAll, 0) else {
            print("!let raw")
            return []
        }
        guard let dicts = raw as? [NSDictionary] else {
            print("!as [NSDictionary]")
            return []
        }
        return dicts.map { dict in
            WindowInfo(
                windowID: Int(truncating: dict[kCGWindowNumber] as! CFNumber),
                layer: Int(truncating: dict[kCGWindowLayer] as! CFNumber),
                appPID: Int(truncating: dict[kCGWindowOwnerPID] as! CFNumber),
                appName: (dict[kCGWindowOwnerName] as? String),
                frame: CoordRect.cg(.init(dictionaryRepresentation: dict[kCGWindowBounds] as! CFDictionary)!),
                isOnScreen: dict[kCGWindowIsOnscreen] as? Bool ?? false
            )
        }
    }
    
    func getWindow(windowNumber: Int) -> WindowInfo? {
        
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
                if let ownWindow = NSApp.window(withWindowNumber: window.windowID) {
                    print("Matched own window: \(window.windowID)", ownWindow)
                    return ownWindow.includeInScreenshot
                }
            }
            
            return true
        }
    }
    
    func screenshot(_ rect: CGRect) -> CGImage? {
        return CGWindowListCreateImage(rect, .optionAll, 0, .bestResolution)
//        screenshot(rect, windows: windows())
    }
    
    func screenshot(_ rect: CGRect, windows: [WindowInfo]) -> CGImage? {
//        print("ScreenshotService.screenshot: \(rect), \(windows)")
        return screenshot(rect, windows: windows.map { $0.windowID })
    }
    
    // TODO: always returning null :(
    // https://developer.apple.com/documentation/coregraphics/1455730-cgwindowlistcreateimagefromarray
    func screenshot(_ rect: CGRect, windows: [Int]) -> CGImage? {
        let asCG = windows.map { CGWindowID($0) } as CFArray
        return CGImage(windowListFromArrayScreenBounds: rect, windowArray: asCG, imageOption: [.bestResolution, .shouldBeOpaque])
    }
}
