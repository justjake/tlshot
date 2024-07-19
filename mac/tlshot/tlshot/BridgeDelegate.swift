//
//  BridgeDelegate.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/16/24.
//

import Foundation
import CoreGraphics

protocol BridgeDelegate {
    func onNotification(_ booted: BootedNotification) -> Void
    func onNotification(_ debug: DebugNotification) -> Void
    func onNotification(_ response: ResponseNotification) -> Void
    
    func onRequest(_ request: GetNameRequest) async throws -> GetNameResponse
    func onRequest(_ request: URLRequest) async throws -> BridgeURLResponse
    
    func environment() throws -> BridgeEnvironment
}

extension BridgeDelegate {
    func notSupported() -> BridgeError {
        return .notSupportedByDelegate
    }
}

class BridgeOutgoingRequestRegistry {
    private var httpUploadWaiters: [String : (URLRequest?) -> Void] = [:]
    private var notificationWaiters: [String : (ResponseNotification) -> Void] = [:]
    
    func onNotification(_ response: ResponseNotification) {
        print("<< RESPONSE NOTIFICATION \(response)")
        fulfill(notification: response)
    }

    func onRequest(_ request: URLRequest) async throws -> BridgeURLResponse {
        if request.url?.scheme != BridgeProtocol.tlshotResponse.rawValue {
            throw BridgeError.notSupportedByDelegate
        }
        
        guard let requestID = request.url?.lastPathComponent else {
            throw TlshotError.invalidData("No url.lastPathComponent")
        }
        fulfill(httpUpload: request, forRequest: requestID)
        return .empty
    }
    
    func waitForResponse(requestID: String) async -> (ResponseNotification, URLRequest?) {
        return await withCheckedContinuation { cont in
            var response: ResponseNotification?
            var didHttp = false
            var httpUpload: URLRequest?
            
            httpUploadWaiters[requestID] = {
                didHttp = true
                httpUpload = $0
                if let didGetResponse = response {
                    cont.resume(returning: (didGetResponse, httpUpload))
                }
            }
            
            notificationWaiters[requestID] = {
                response = $0
                if didHttp {
                    cont.resume(returning: ($0, httpUpload))
                }
            }
            
            print("Waiting for request \(requestID)")
        }
    }
    
    private func fulfill(notification: ResponseNotification) {
        if !notification.httpUpload {
            print("Notification: not httpUpload: \(notification)")
            // We don't need to wait for an HTTP upload request in this case.
            fulfill(httpUpload: nil, forRequest: notification.requestID)
        }
        
        guard let handler = notificationWaiters.removeValue(forKey: notification.requestID) else {
            print("Notification: Unknown RequestID: \(notification.requestID) in \(notification)")
            return
        }
        
        handler(notification)
    }
    
    private func fulfill(httpUpload: URLRequest?, forRequest requestID: String) {
        guard let handler = httpUploadWaiters.removeValue(forKey: requestID) else {
            print("httpUpload: Unknown RequestID: \(requestID) in \(httpUpload.debug ?? "(cancellation)")")
            return
        }
        handler(httpUpload)
    }
}

class BridgeBootWaiter {
    @MainActor private var didBoot = false
    @MainActor private var onBootCallbacks: [() -> Void] = []
    
    @MainActor func onNotification(_ booted: BootedNotification) -> Void {
        print("webview booted (time from js): \(Date(timeIntervalSince1970: booted.time/1000))")
        didBoot = true
        let cbs = onBootCallbacks
        onBootCallbacks = []
        for cb in cbs {
            cb()
        }
    }
    
    @MainActor func waitForBoot() async {
        if didBoot {
            return
        }
        print("  (waiting for JS to boot)")
        await withCheckedContinuation { cont in onBootCallbacks.append {
            cont.resume()
        }}
        print("  (js booted)")
    }
}

class BridgeDebugLogger {
    private var logIndex = 0
    
    func onNotification(_ msg: DebugNotification) {
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
    
    @discardableResult
    private func consoleLog(_ msg: String, _ index: Int? = nil) -> Int {
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
}

class BridgeAssetServer {
    private(set) var images: [Int:CGImage] = [:]
    
    func add(image: CGImage) {
        images[image.hashValue] = image
    }
    
    func onRequest(_ request: URLRequest) async throws -> BridgeURLResponse {
        if request.url?.scheme != BridgeProtocol.asset.rawValue {
            throw BridgeError.notSupportedByDelegate
        }
        
        guard let imageIDString = request.url?.lastPathComponent, let imageID = Int(imageIDString) else {
            throw BridgeError.message("Not a valid asset request: \(request)")
        }
        
        guard let image = images[imageID] else {
            throw BridgeError.message("Not found: \(imageID)")
        }
        
        guard let data = image.png else {
            throw TlshotError.invalidData("Cannot convert image to PNG")
        }
        
        return .binary(data, url: request.url!, mimeType: "image/png")
    }
}

class BridgeHelloWorldDelegate {
    func onRequest(_ request: GetNameRequest) async throws -> GetNameResponse {
        return .init(name: "Bob")
    }
}
