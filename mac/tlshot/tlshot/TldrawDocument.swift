//
//  Document.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/12/24.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct TldrawDocument: FileDocument {
    typealias RawJson = Dictionary<String, Any>
    static var readableContentTypes: [UTType] = [.png, .jpeg, .json]
    
    var backgroundImage: NSImage? = nil
    var json: RawJson = [:]
    
    init() {
        // OK!
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw TlshotError.missingFileData
        }
        switch (configuration.contentType) {
        case .image:
            backgroundImage = NSImage(data: data)
        case .json:
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? RawJson else {
                throw TlshotError.invalidJson(data)
            }
            json = decoded
        default:
            throw TlshotError.unknownFileType(configuration.contentType)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        switch configuration.contentType {
        case .image:
            throw TlshotError.notImplemented("Saving to image")
        case .json:
            let data = try JSONSerialization.data(withJSONObject: json)
            return FileWrapper(regularFileWithContents: data)
        default:
            throw TlshotError.unknownFileType(configuration.contentType)
        }
    }
}
