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
    @AppStorage(SettingsKey.saveFolder) private var saveFolder: URL?
    @AppStorage(SettingsKey.windowIncludeShadow) private var windowIncludeShadow: Bool = true
    @AppStorage(SettingsKey.windowIncludeDesktop) private var windowIncludeDesktop: Bool = false
    @AppStorage(SettingsKey.windowIncludeMenuBarWithDesktop) private var windowIncludeMenuBarWithDesktop = false

    var body: some Scene {
//        DocumentGroup(newDocument: TldrawDocument()) { group in
//            ContentView(document: group.$document)
//        }
        
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
            
            if let chosenSaveFolder = saveFolder {
                Text("Save to \(chosenSaveFolder.describeHomedirRelative)")
            } else {
                Text("No save folder chosen")
            }
            Button("Choose folder...") {
                appDelegate.onChooseSaveFolder()
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

