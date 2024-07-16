//
//  Bridge.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/15/24.
//

import Foundation
import WebKit

extension Data {
    func asString(encoding: String.Encoding = .utf8) -> String? {
        String(data: self, encoding: encoding)
    }
}

extension Encodable {
    func toJSON() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

extension Decodable {
    static func fromJSON(string: String) throws -> Self {
        guard let data = string.data(using: .utf8) else {
            throw TlshotError.invalidData(string)
        }
        return try self.fromJSON(data: data)
    }
    
    static func fromJSON(data: Data) throws -> Self {
        try JSONDecoder().decode(self, from: data)
    }
}

struct BridgeEnvelope<T: RawRepresentable<String>> {
    enum Err: Error {
        case notDictionary(Any)
        case noType(debug: String)
        case unknownType(String, debug: String)
        case noJson(T, debug: String)
    }
    
    var type: T
    var json: String
    
    static func fromWebKit(_ message: WKScriptMessage) throws -> BridgeEnvelope {
        guard let dictionary = message.body as? NSDictionary else {
            throw Err.notDictionary(message.body)
        }
        guard let typeString = dictionary["type"] as? String else {
            throw Err.noType(debug: String(reflecting: dictionary))
        }
        guard let keyType = T(rawValue: typeString) else {
            throw Err.unknownType(typeString, debug: String(reflecting: dictionary))
        }
        guard let jsonString = dictionary["json"] as? String else {
            throw Err.noJson(keyType, debug: String(reflecting: dictionary))
        }
        return BridgeEnvelope(type: keyType, json: jsonString)
    }
}

extension String {
    func reverseString() -> String {
        String(reversed())
    }
}

class BridgeMessageDelegate: NSObject, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {
    typealias Notification = BridgeEnvelope<BridgeNotificationType>
    
    init (_ view: TldrawWebView ) {
        self.view = view
    }
    
    var view: TldrawWebView
    
    // Notification
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        do {
            let message = try Notification.fromWebKit(message)
            switch message.type {
            case .booted:
                try onBooted(BootedNotification.fromJSON(string: message.json))
            case .debug:
                try onDebug(DebugNotification.fromJSON(string: message.json))
            }
        } catch {
            print("\(self).didReceive error: \(error)")
        }
    }
    
    var logIndex = 0
    @discardableResult
    func consoleLog(_ msg: String, _ index: Int? = nil) -> Int {
        logIndex = index ?? logIndex + 1
        let number = String(logIndex).reverseString().padding(toLength: 5, withPad: " ", startingAt: 0).reverseString()
        let prefix = "[\(number)] JS: "
        let msg = msg.split(separator: "\n").map { prefix + $0 }.joined(separator: "\n")
        if index == nil {
            print("/ -- \(Date()) --\\")
        }
        print(msg)
        return logIndex
    }

    func onDebug(_ msg: DebugNotification) {
        switch msg.type {
        case .console:
            consoleLog("console.\(msg.method?.rawValue ?? "?"): \(msg.message?.joined(separator: " ") ?? "")")
        case .error:
            let log = consoleLog("ERROR: \(msg.error?.name ?? "?"): \(msg.error?.message ?? "?")")
            if let stack = msg.error?.stack {
                consoleLog(stack, log)
            }
        case .unhandledRejection:
            let log = consoleLog("ASYNC ERROR: \(msg.error?.name ?? "?"): \(msg.error?.message ?? "?")")
            if let stack = msg.error?.stack {
                consoleLog(stack, log)
            }
        }
    }
    
    func onBooted(_ msg: BootedNotification) {
        print("webview booted (time from js): \(Date(timeIntervalSince1970: msg.time/1000))")
    }
    
    // Request/Reply
    typealias Request = BridgeEnvelope<BridgeRequestType>
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        do {
            let message = try Request.fromWebKit(message)
            let response = try await onRequest(message)
            return try (response.toJSON().asString(), nil)
        } catch {
            print("\(self).didReceive error: \(error)")
            let nativeError = String(reflecting: error)
            return (nil, nativeError)
        }
    }
    
    func onRequest(_ msg: Request) async throws -> Encodable {
        switch msg.type {
        case .getName:
            return GetNameResponse(name: "Doug")
        }
    }
    
    func getUserScript() -> WKUserScript {
        let bridgeEnv = view.bridgeEnvironment
        let script = """
        globalThis.__BRIDGE_ENVIRONMENT__ = \(try! bridgeEnv.toJSON().asString()!)
        """
        
        return WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
}

