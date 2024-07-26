//
//  NotificationSupport.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/24/24.
//

import Foundation
import UserNotifications
import AppKit

protocol TlshotNotification {
    static var identifier: String { get }
    static var category: UNNotificationCategory { get }
    func toNotification() -> UNNotificationRequest
    static func fromNotification(_ response: UNNotificationResponse) throws -> Self
}

extension TlshotNotification {
    func sendNotification() async throws {
        let center = UNUserNotificationCenter.current()
        
        var settings = await center.notificationSettings()
        
        if settings.authorizationStatus == .notDetermined {
            try await center.requestAuthorization(options: [.provisional, .alert])
            settings = await center.notificationSettings()
        }
        
        // Verify the authorization status.
        guard (settings.authorizationStatus == .authorized) ||
                (settings.authorizationStatus == .provisional) else {
            print("\(self).afterSaveActionShowNotification: not authorized: \(settings.authorizationStatus)")
            return
        }
        
        try await center.add(toNotification())
    }
    
    static func assertCategory(_ response: UNNotificationResponse) throws {
        guard response.notification.request.content.categoryIdentifier == identifier else {
            throw TlshotError.invalidData("not \(self.identifier)")
        }
    }
}


struct Notif {
    enum CategoryID: String, CaseIterable {
        case savedFile
        case copyAndClose
        
        var category: UNNotificationCategory {
            switch self {
            case .savedFile: SavedFile.category
            case .copyAndClose: CopyAndClose.category
            }
        }
        
        static func register() {
            let center = UNUserNotificationCenter.current()
            let categories = Set(allCases.map { $0.category })
            center.setNotificationCategories(categories)
        }
    }
    
    enum ActionID: String {
        case revealInFinder
        case copyToClipboard
        
        var action: UNNotificationAction {
            switch self {
            case .copyToClipboard:
                UNNotificationAction(identifier: rawValue, title: "Copy to clipboard")
            case .revealInFinder:
                UNNotificationAction(identifier: rawValue, title: "Reveal in Finder")
            }
        }
    }
    
    struct CopyAndClose: TlshotNotification {
        var imageName: String
        var pngImageData: Data
        
        static var identifier = CategoryID.copyAndClose.rawValue
        static var category = UNNotificationCategory(
            identifier: identifier,
            actions: [ActionID.copyToClipboard.action],
            intentIdentifiers: []
        )
        
        func copyToClipboard() {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(pngImageData, forType: .png)
        }

        func toNotification() -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = imageName
            content.body = "Copied to clipboard"
            content.userInfo["imageName"] = imageName
            content.userInfo["pngImageData"] = pngImageData
            content.sound = nil
            content.interruptionLevel = .active
            content.categoryIdentifier = Self.identifier
            return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        }
        
        static func fromNotification(_ response: UNNotificationResponse) throws -> Notif.CopyAndClose {
            try assertCategory(response)
            let content = response.notification.request.content
            guard let data = content.userInfo["pngImageData"] as? Data else {
                throw TlshotError.invalidData("No pngImageData")
            }
            guard let imageName = content.userInfo["imageName"] as? String else {
                throw TlshotError.invalidData("No imageName")
            }
            return Self(imageName: imageName, pngImageData: data)
        }
    }

    struct SavedFile: TlshotNotification {
        let fileURL: URL
        let pngImageData: Data
        let responseAction: ActionID?
        
        func revealInFinder() {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        }
        
        func copyToClipboard() {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(pngImageData, forType: .png)
            pasteboard.setString(fileURL.formatted(), forType: .fileURL)
            pasteboard.setString(fileURL.absoluteString, forType: .string)
        }
        
        func performResponseAction() {
            switch responseAction {
            case .revealInFinder:
                revealInFinder()
            case .copyToClipboard:
                copyToClipboard()
            case nil:
                revealInFinder()
            }
        }
        
        func toNotification() -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = fileURL.lastPathComponent
            content.body = "Saved to \(fileURL.deletingLastPathComponent().relativePath)"
            content.userInfo["fileURL"] = fileURL.formatted()
            content.userInfo["pngImageData"] = pngImageData
            content.sound = nil
            content.interruptionLevel = .active
            content.threadIdentifier = "file:\(fileURL.lastPathComponent)"
            content.categoryIdentifier = Self.identifier
            content.interruptionLevel = .active
            return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        }
        
        static func fromNotification(_ response: UNNotificationResponse) throws -> Notif.SavedFile {
            try assertCategory(response)
            let content = response.notification.request.content
            guard let fileURLString = content.userInfo["fileURL"] as? String, let fileURL = URL(string: fileURLString) else {
                throw TlshotError.invalidData("no fileURL")
            }
            guard let pngImageData = content.userInfo["pngImageData"] as? Data else {
                throw TlshotError.invalidData("no pngImageData")
            }
            let actionId = ActionID(rawValue: response.actionIdentifier)
            return SavedFile(fileURL: fileURL, pngImageData: pngImageData, responseAction: actionId)
        }
        
        static var identifier = CategoryID.savedFile.rawValue
        static var category = UNNotificationCategory(
            identifier: identifier,
            actions: [
                ActionID.revealInFinder.action,
                ActionID.copyToClipboard.action,
            ],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Created file"
        )

    }
}


