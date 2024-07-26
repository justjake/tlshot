// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let bridgeEnvironment = try? JSONDecoder().decode(BridgeEnvironment.self, from: jsonData)
//   let bootedNotification = try? JSONDecoder().decode(BootedNotification.self, from: jsonData)
//   let bridgeErrorLike = try? JSONDecoder().decode(BridgeErrorLike.self, from: jsonData)
//   let debugNotification = try? JSONDecoder().decode(DebugNotification.self, from: jsonData)
//   let getNameRequest = try? JSONDecoder().decode(GetNameRequest.self, from: jsonData)
//   let getNameResponse = try? JSONDecoder().decode(GetNameResponse.self, from: jsonData)
//   let saveRequest = try? JSONDecoder().decode(SaveRequest.self, from: jsonData)
//   let saveResponse = try? JSONDecoder().decode(SaveResponse.self, from: jsonData)
//   let responseNotification = try? JSONDecoder().decode(ResponseNotification.self, from: jsonData)
//   let bridgeNotificationMap = try? JSONDecoder().decode(BridgeNotificationMap.self, from: jsonData)
//   let bridgeRequestMap = try? JSONDecoder().decode(BridgeRequestMap.self, from: jsonData)
//   let bridgeIncomingMap = try? JSONDecoder().decode(BridgeIncomingMap.self, from: jsonData)
//   let bridgeIncomingEnvelope = try? JSONDecoder().decode(BridgeIncomingEnvelope.self, from: jsonData)
//   let bridgeNotificationType = try? JSONDecoder().decode(BridgeNotificationType.self, from: jsonData)
//   let bridgeRequestType = try? JSONDecoder().decode(BridgeRequestType.self, from: jsonData)
//   let bridgeIncomingType = try? JSONDecoder().decode(BridgeIncomingType.self, from: jsonData)
//   let bridgeImageAssetProps = try? JSONDecoder().decode(BridgeImageAssetProps.self, from: jsonData)
//   let bridgeProtocol = try? JSONDecoder().decode(BridgeProtocol.self, from: jsonData)
//   let createSVGRequest = try? JSONDecoder().decode(CreateSVGRequest.self, from: jsonData)
//   let createSVGResponse = try? JSONDecoder().decode(CreateSVGResponse.self, from: jsonData)

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

import Foundation

// MARK: - BridgeEnvironment
struct BridgeEnvironment: Codable, Hashable {
    let appName: String
    let initialAsset: InitialAsset?
    let theme: Theme
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - InitialAsset
struct InitialAsset: Codable, Hashable {
    let fileSize, h: Double
    let isAnimated: Bool
    let mimeType, name, src: String
    let w: Double
}

enum Theme: String, Codable, Hashable {
    case dark = "dark"
    case light = "light"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - BridgeNotificationMap
struct BridgeNotificationMap: Codable, Hashable {
    let booted: BootedNotification
    let debug: DebugNotification
    let prepareSave: SaveRequest
    let response: ResponseNotification
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - BootedNotification
struct BootedNotification: Codable, Hashable {
    let time: Double
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - DebugNotification
struct DebugNotification: Codable, Hashable {
    let message: [String]?
    let method: Method?
    let type: TypeEnum
    let error: BridgeErrorLike?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - BridgeErrorLike
struct BridgeErrorLike: Codable, Hashable {
    let message, name, stack: String
}

enum Method: String, Codable, Hashable {
    case debug = "debug"
    case error = "error"
    case log = "log"
}

enum TypeEnum: String, Codable, Hashable {
    case console = "console"
    case error = "error"
    case unhandledRejection = "unhandledRejection"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - SaveRequest
struct SaveRequest: Codable, Hashable {
    let saveID: String

    enum CodingKeys: String, CodingKey {
        case saveID = "saveId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - ResponseNotification
struct ResponseNotification: Codable, Hashable {
    let error: BridgeErrorLike?
    let httpUpload: Bool
    let responseNotificationJSON: String?
    let requestID: String
    let type: BridgeIncomingType

    enum CodingKeys: String, CodingKey {
        case error, httpUpload
        case responseNotificationJSON = "json"
        case requestID = "requestId"
        case type
    }
}

enum BridgeIncomingType: String, Codable, Hashable {
    case save = "save"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - BridgeRequestMap
struct BridgeRequestMap: Codable, Hashable {
    let createSVGAsset: CreateSVGAsset
    let getName: GetName

    enum CodingKeys: String, CodingKey {
        case createSVGAsset = "createSvgAsset"
        case getName
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CreateSVGAsset
struct CreateSVGAsset: Codable, Hashable {
    let request: CreateSVGRequest
    let response: CreateSVGResponse
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CreateSVGRequest
struct CreateSVGRequest: Codable, Hashable {
    let assetID, svgText: String

    enum CodingKeys: String, CodingKey {
        case assetID = "assetId"
        case svgText
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CreateSVGResponse
struct CreateSVGResponse: Codable, Hashable {
    let assetURL: String

    enum CodingKeys: String, CodingKey {
        case assetURL = "assetUrl"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - GetName
struct GetName: Codable, Hashable {
    let request: GetNameRequest
    let response: GetNameResponse
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - GetNameRequest
struct GetNameRequest: Codable, Hashable {
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - GetNameResponse
struct GetNameResponse: Codable, Hashable {
    let name: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - BridgeIncomingMap
struct BridgeIncomingMap: Codable, Hashable {
    let save: Save
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - Save
struct Save: Codable, Hashable {
    let request: SaveRequest
    let response: SaveResponse
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - SaveResponse
struct SaveResponse: Codable, Hashable {
    let height: Double?
    let svg: String?
    let width: Double?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - BridgeIncomingEnvelope
struct BridgeIncomingEnvelope: Codable, Hashable {
    let bridgeIncomingEnvelopeJSON, requestID: String
    let type: BridgeIncomingType

    enum CodingKeys: String, CodingKey {
        case bridgeIncomingEnvelopeJSON = "json"
        case requestID = "requestId"
        case type
    }
}

enum BridgeNotificationType: String, Codable, Hashable {
    case booted = "booted"
    case debug = "debug"
    case prepareSave = "prepareSave"
    case response = "response"
}

enum BridgeRequestType: String, Codable, Hashable {
    case createSVGAsset = "createSvgAsset"
    case getName = "getName"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - BridgeImageAssetProps
struct BridgeImageAssetProps: Codable, Hashable {
    let fileSize, h: Double
    let isAnimated: Bool
    let mimeType, name, src: String
    let w: Double
}

enum BridgeProtocol: String, Codable, Hashable {
    case asset = "asset"
    case tlshotResponse = "tlshot-response"
}
