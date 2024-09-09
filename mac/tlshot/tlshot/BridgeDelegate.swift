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

class Waiter {
    let eventName: String
    @MainActor private var didHappen = false
    @MainActor private var callbacks: [() -> Void] = []
    
    init(_ eventName: String) {
        self.eventName = eventName
    }
    
    @MainActor func notify(_ time: Double) -> Void {
        print("\(self): \(eventName) (time from js): \(Date(timeIntervalSince1970: time/1000))")
        didHappen = true
        let cbs = callbacks
        callbacks = []
        for cb in cbs {
            cb()
        }
    }
    
    @MainActor func wait() async {
        if didHappen {
            return
        }
        print("  (\(self) waiting for \(eventName)")
        await withCheckedContinuation { cont in callbacks.append {
            cont.resume()
        }}
        print("  (\(self) \(eventName)")
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
    enum AssetType: String {
        case proxy = "proxy"
        case cgImage = "cgImage"
        case svg = "svg"
    }
    
    private var images: [String:CGImage] = [:]
    private var svgs: [String:String] = [:]
    
    // Returns URL of asset
    @discardableResult
    func add(image: CGImage) -> String {
        images["\(image.hashValue)"] = image
        return url("cgImage/\(image.hashValue)")
    }
    
    func add(svg: CreateSVGRequest) -> String {
        svgs[svg.assetID] = svg.svgText
        return url("svg/\(svg.assetID)")
    }
    
    func getInitialAsset() -> InitialAsset? {
        guard let image = images.values.first else {
            return nil
        }
        
        return InitialAsset(fileSize: Double(image.png?.count ?? 0), h: Double(image.height), isAnimated: false, mimeType: "image/png", name: "Screenshot", src: url("cgImage/\(image.hashValue)"), w: Double(image.width))
    }
    
    func onRequest(_ request: URLRequest) async throws -> BridgeURLResponse {
        guard let url = request.url else {
            throw BridgeError.notSupportedByDelegate
        }
        
        if url.scheme != BridgeProtocol.asset.rawValue {
            throw BridgeError.notSupportedByDelegate
        }
        
        // Expect url.pathComponents = [
        //   "/",
        //   "cgImage" | "svg",
        //   name
        // ]
        guard
            url.pathComponents.count >= 3,
            let assetType = AssetType(rawValue: url.pathComponents[1])
        else {
            throw BridgeError.message("Not a valid asset request: \(request) (\(url.pathComponents))")
        }
        let assetName = url.pathComponents[2]
        
        switch assetType {
        case .cgImage:
            return try serveCgImage(assetName, url: url)
        case .svg:
            return try serveSvg(assetName, url: url)
        case .proxy:
            return try await serveProxy(url)
        }
    }
    
    func serveCgImage(_ imageID: String, url: URL) throws -> BridgeURLResponse {
        guard let image = images[imageID] else {
            throw BridgeError.message("CGImage not found: \(imageID)")
        }
        
        guard let data = image.png else {
            throw TlshotError.invalidData("Cannot convert image to PNG")
        }
        
        return .binary(data, url: url, mimeType: "image/png")
    }
    
    func serveSvg(_ name: String, url: URL) throws -> BridgeURLResponse {
        guard let svgText = svgs[name] else {
            throw BridgeError.message("SVG not found: \(name)")
        }
        
        return .utf8(svgText, url: url, mimeType: "image/svg+xml")
    }
    
    func serveProxy(_ url: URL) async throws -> BridgeURLResponse {
        guard let urlText = url.query(percentEncoded: false) else {
            throw BridgeError.message("not vaid query: \(url)")
        }
        
        guard let proxyUrl = URL(string: urlText) else {
            throw BridgeError.message("not valid url: \(url)")
        }
        
        print("Proxy attempt: \(proxyUrl)")
        let (data, response) = try await URLSession.shared.data(from: proxyUrl)
        print("Proxy ok: \(response.mimeType)")
        return .binary(data, url: url, mimeType: response.mimeType ?? "text/html")
    }
    
    private func url(_ path: String) -> String {
        return "\(BridgeProtocol.asset.rawValue)://assets/\(path)"
    }
}

class BridgeResourceServer {
    func onRequest(_ request: URLRequest) async throws -> BridgeURLResponse {
        let pathComponents = request.url!.relativePath
        guard let
                resourceUrl = Bundle.main.resourceURL?.appending(path: pathComponents).standardized,
              resourceUrl.absoluteString.starts(with: Bundle.main.resourceURL!.absoluteString)
        else {
            return .notFound
        }
        let type = try! resourceUrl.resourceValues(forKeys: [.contentTypeKey]).contentType
        if type?.conforms(to: .data) ?? false {
            return .binary(try Data(contentsOf: resourceUrl), url: resourceUrl, mimeType: type?.preferredMIMEType ?? "application/octet-stream")
        }
        return .utf8(try String(contentsOf: resourceUrl), url: resourceUrl, mimeType: type?.preferredMIMEType ?? "text/plain")
    }
}

class BridgeHelloWorldDelegate {
    func onRequest(_ request: GetNameRequest) async throws -> GetNameResponse {
        return .init(name: "Bob")
    }
}
