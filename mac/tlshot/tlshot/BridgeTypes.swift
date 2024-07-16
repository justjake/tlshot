// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let bridgeEnvironment = try? JSONDecoder().decode(BridgeEnvironment.self, from: jsonData)
//   let bootedNotification = try? JSONDecoder().decode(BootedNotification.self, from: jsonData)
//   let bridgeErrorLike = try? JSONDecoder().decode(BridgeErrorLike.self, from: jsonData)
//   let debugNotification = try? JSONDecoder().decode(DebugNotification.self, from: jsonData)
//   let getNameRequest = try? JSONDecoder().decode(GetNameRequest.self, from: jsonData)
//   let getNameResponse = try? JSONDecoder().decode(GetNameResponse.self, from: jsonData)
//   let bridgeNotificationMap = try? JSONDecoder().decode(BridgeNotificationMap.self, from: jsonData)
//   let bridgeRequestMap = try? JSONDecoder().decode(BridgeRequestMap.self, from: jsonData)
//   let bridgeNotificationType = try? JSONDecoder().decode(BridgeNotificationType.self, from: jsonData)
//   let bridgeRequestType = try? JSONDecoder().decode(BridgeRequestType.self, from: jsonData)

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

import Foundation

// MARK: - BridgeEnvironment
struct BridgeEnvironment: Codable, Hashable {
    let appName: String
    let initialFileURL: String?
    let theme: Theme
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

// MARK: - BridgeRequestMap
struct BridgeRequestMap: Codable, Hashable {
    let getName: GetName
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

enum BridgeNotificationType: String, Codable, Hashable {
    case booted = "booted"
    case debug = "debug"
}

enum BridgeRequestType: String, Codable, Hashable {
    case getName = "getName"
}
