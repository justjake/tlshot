//  tlshotApp.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/10/24.
//

import SwiftUI
import UniformTypeIdentifiers
import ScreenCaptureKit
import KeyboardShortcuts
import LaunchAtLogin


enum CaptureAction {
    case area
    case window
}

enum CaptureMediaType {
    case image
    case video
}

enum TlshotError: LocalizedError, Equatable {
    case missingFileData
    case unknownFileType(UTType)
    case invalidJson(Data)
    case invalidData(String)
    case notImplemented(String)
    case captureFailed(String)
    case pickSaveFolderCancelled
    case captureCancelled
    
    var errorDescription: String? {
        "\(self)"
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .captureFailed: "Grant permission in System Settings"
        case .pickSaveFolderCancelled: "Pick a folder to save your captures from the Tlshot menu"
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

enum AfterSaveAction: String {
    case showNotification
    case revealInFinder
    case showNotificationAndCopy
    case none
}

struct SettingsKey {
    static let windowIncludeDesktop = "windowIncludeDesktop"
    static let windowIncludeMenuBarWithDesktop = "windowIncludeMenuBarWithDesktop"
    static let windowIncludeShadow = "windowIncludeShadow"
    static let hidePermissionWarning = "hidePermissionWarning"
    static let saveFolder = "saveFolder"
    static let saveFolderBookmark = "saveFolderBookmark"
    static let afterSaveAction = "afterSaveAction"
    
    private init() {}
}

extension KeyboardShortcuts.Name {
    static let captureAreaDefault = KeyboardShortcuts.Shortcut(.four, modifiers: [.command, .option])
    static let captureWindowDefault = KeyboardShortcuts.Shortcut(.five, modifiers: [.command, .option])
    static let captureFullscreenDefault = KeyboardShortcuts.Shortcut(.six, modifiers: [.command, .option])
    
    static let captureArea = Self("captureArea", default: captureAreaDefault)
    static let captureWindow = Self("captureWindow", default: captureWindowDefault)
    static let captureFullscreen = Self("captureFullscreen", default: captureFullscreenDefault)
}

@main
struct TlshotApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    @StateObject private var areaShortcut: KeyboardShortcuts.ShortcutObservable = .init(name: .captureArea)
    @StateObject private var windowShortcut: KeyboardShortcuts.ShortcutObservable = .init(name: .captureWindow)
    @StateObject private var fullscreenShortcut: KeyboardShortcuts.ShortcutObservable = .init(name: .captureFullscreen)
    
    static var trayImage = {
        let image = NSImage(named: "TrayIcon")!
        image.isTemplate = true
        return image
    }()
    
    var body: some Scene {
        //        DocumentGroup(newDocument: TldrawDocument()) { group in
        //            ContentView(document: group.$document)
        //        }
        Settings {
            SettingsScreen()
                .padding(12)
                .frame(width: 500)
        }.windowResizability(.contentSize)
        
        MenuBarExtra(content: {
            Button("Capture Area") {
                appDelegate.startCapture(.area)
            }.keyboardShortcut(areaShortcut.shortcut?.keyboardShortcut)
            Button("Capture Window") {
                appDelegate.startCapture(.window)
            }.keyboardShortcut(windowShortcut.shortcut?.keyboardShortcut)
            Button("Capture Fullscreen") {
                appDelegate.handleErrors {
                    try appDelegate.onCaptureFullscreen()
                }
            }.keyboardShortcut(fullscreenShortcut.shortcut?.keyboardShortcut)
            //            Button("Record video") {
            //                appDelegate.startCapture(.area, mediaType: .video)
            //            }
            
            
            Divider()
            
            SettingsLink().keyboardShortcut(",")
            
            Button("Quit") {
                NSApplication.shared.terminate(self)
            }.keyboardShortcut("Q", modifiers: .command)
            
        }, label: {
            Label(
                title: { Text("tlshot") },
                icon: { Image(nsImage: Self.trayImage) }
            )
        })
    }
}

struct SettingsScreen: View {
    @EnvironmentObject var appDelegate: AppDelegate
    
    @AppStorage(SettingsKey.windowIncludeShadow) private var windowIncludeShadow: Bool = true
    @AppStorage(SettingsKey.windowIncludeDesktop) private var windowIncludeDesktop: Bool = false
    @AppStorage(SettingsKey.windowIncludeMenuBarWithDesktop) private var windowIncludeMenuBarWithDesktop = false
    @AppStorage(SettingsKey.afterSaveAction) private var afterSaveAction: AfterSaveAction = .none

    var body: some View {
        Form {
            saveFolderSettings
            Divider()
            keyboardShortcutSettings
            Divider()
            permissionSettings
            windowCaptureStyleSettings
            afterSaveSettings
            Divider()
            LaunchAtLogin.Toggle()
        }
    }
    
    @ViewBuilder
    var saveFolderSettings: some View {
        if let chosenSaveFolder = try? appDelegate.getSaveFolder() {
            Text("Save to \(chosenSaveFolder.describeHomedirRelative)")
        } else {
            Text("No save folder chosen")
        }
        Button("Choose folder...") {
            appDelegate.onChooseSaveFolder()
        }
    }
    
    @ViewBuilder
    var windowCaptureStyleSettings: some View {
        Section(header: Text("When capturing windows...")) {
            Toggle("Include shadow", isOn: Binding(
                get: { windowIncludeShadow || windowIncludeDesktop },
                set: { windowIncludeShadow = $0 }
            ))
            .disabled(windowIncludeDesktop)
            Toggle("Include desktop", isOn: $windowIncludeDesktop)
            Toggle("Include menu bar with desktop", isOn: $windowIncludeMenuBarWithDesktop)
                .disabled(!windowIncludeDesktop)
        }
    }
    
    @ViewBuilder
    var afterSaveSettings: some View {
        Picker("After save...", selection: $afterSaveAction) {
            Text("Show notification").tag(AfterSaveAction.showNotification)
            Text("Show notification and copy to clipboard").tag(AfterSaveAction.showNotificationAndCopy)
            Text("Reveal in Finder").tag(AfterSaveAction.revealInFinder)
            Text("Do nothing").tag(AfterSaveAction.none)
        }
    }
    
    @ViewBuilder
    var permissionSettings: some View {
        if !appDelegate.hasPermission {
            Text("Need permissions")
            Button("Grant permissions...") {
                CGRequestScreenCaptureAccess()
                AppDelegate.openSystemSettings()
            }
        }
    }
    
    @ViewBuilder
    var keyboardShortcutSettings: some View {
        KeyboardShortcuts.Recorder("Capture area:", name: .captureArea)
        KeyboardShortcuts.Recorder("Capture window:", name: .captureWindow)
        KeyboardShortcuts.Recorder("Capture full screen:", name: .captureFullscreen)
    }
}

