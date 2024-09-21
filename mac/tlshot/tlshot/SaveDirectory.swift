//
//  SaveDirectory.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/24/24.
//

import SwiftUI

class SaveDirectory: ObservableObject {
    @AppStorage(SettingsKey.saveFolderBookmark) private var bookmark: Data?
    @Published private var cachedUrl: URL?
    
    func saveImage(name: String, data: Data) async throws -> URL {
        let saveFolder = try await getOrChooseSaveFolder()
        let startedAccess = saveFolder.startAccessingSecurityScopedResource()
        defer { saveFolder.stopAccessingSecurityScopedResource() }
        if !startedAccess {
            print("\(self).saveImage: startAccessingSecurityScopedResource returned false. This directory might not need it, or this URL might not be a security scoped URL, or maybe something's wrong?")
        }
        
        let url = saveFolder.appendingPathComponent(name, conformingTo: .png)
        try data.write(to: url, options: .atomic)
        return url
    }
    
    func getSaveFolder() throws -> URL? {
        if let url = cachedUrl {
            return url
        }
        
        if let data = bookmark {
            let url = try restoreAccess(from: data)
            cachedUrl = url
            return url
        }
        
        return nil
    }
    
    @MainActor func getOrChooseSaveFolder() throws -> URL {
        if let url = try getSaveFolder() {
            return url
        }
        
        return try chooseSaveFolder()
    }
    
    @MainActor
    @discardableResult
    func chooseSaveFolder() throws -> URL {
        let newUrl = try presentDirectoryPicker()
        try saveBookmarkData(for: newUrl)
        return newUrl
    }
    
    @MainActor
    private func presentDirectoryPicker() throws -> URL {
        let panel = NSOpenPanel()
        panel.message = "Tlshot will save all captures here"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else {
            throw TlshotError.pickSaveFolderCancelled
        }
        return url
    }
    
    // https://benscheirman.com/2019/10/troubleshooting-appkit-file-permissions.html
    private func saveBookmarkData(for url: URL) throws {
        let data = try url.bookmarkData(options: .withSecurityScope)
        bookmark = data
        cachedUrl = url
    }
    
    private func restoreAccess(from data: Data) throws -> URL {
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        if isStale {
            // bookmarks could become stale as the OS changes
            try saveBookmarkData(for: url)
        }
        return url
    }

    
}
