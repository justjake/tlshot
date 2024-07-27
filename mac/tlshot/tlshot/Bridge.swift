//
//  Bridge.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/15/24.
//

import Foundation
import WebKit
import SwiftUI

extension BridgeEnvironment {
    static var urlProtcol: String { "asset" }
    
    static var assetOffset: CGFloat { 20 }
    
    static var scaleFactor: CGFloat { NSScreen.main?.backingScaleFactor ?? 2 }
    
    static func defaults(_ bridgeAsset: InitialAsset?) -> BridgeEnvironment {
        BridgeEnvironment(
            appName: "tlshot", assetOffsetX: assetOffset, backingScaleFactor: scaleFactor, initialAsset: bridgeAsset, theme: .dark
        )
    }
}

extension Data {
    func asString(encoding: String.Encoding = .utf8) -> String? {
        String(data: self, encoding: encoding)
    }
}

extension Encodable {
    func toJSON() throws -> Data {
        try JSONEncoder().encode(self)
    }
    
    func toJSONString() throws -> String {
        let data = try toJSON()
        guard let string = data.asString() else {
            // TODO: wrong?
            throw TlshotError.invalidJson(data)
        }
        return string
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

struct BridgeOutgoingEnvelope {
    let requestId: UUID = UUID()
    let type: BridgeIncomingType
    let json: String
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
    
    @MainActor static func fromWebKit(_ message: WKScriptMessage) throws -> BridgeEnvelope {
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

enum BridgeError: Error {
    case noDelegate(Any)
    case notSupportedByDelegate
    case message(String)
}

enum BridgeResponseError: Error {
    case bridge(Error)
    case js(BridgeErrorLike)
}

extension ResponseNotification {
    func result<T: Decodable>() -> Result<T, BridgeResponseError> {
        guard let okJson = self.responseNotificationJSON else {
            guard let jsError = self.error else {
                return .failure(.bridge(TlshotError.invalidData("Contained neither .json or .error")))
            }
            return .failure(.js(jsError))
        }
        
        do {
            return try .success(T.fromJSON(string: okJson))
        } catch {
            return .failure(.bridge(error))
        }
    }
}

extension String {
    func reverseString() -> String {
        String(reversed())
    }
}

// https://stackoverflow.com/questions/48312161/how-to-save-cgimage-to-data-in-swift
extension CGImage {
    var png: Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}

protocol IncomingEncodableRequest: Encodable {
    static var requestType: BridgeIncomingType { get }
}

extension SaveRequest: IncomingEncodableRequest {
    static var requestType: BridgeIncomingType { .save }
}

extension BridgeImageAssetProps: IncomingEncodableRequest {
    static var requestType: BridgeIncomingType { .addAsset }
}

extension ZoomToFitRequest: IncomingEncodableRequest {
    static var requestType: BridgeIncomingType { .zoomToFit }
}

extension WaitForResizeRequest: IncomingEncodableRequest {
    static var requestType: BridgeIncomingType { .waitForResize }
}

enum BridgeURLResponse {
    case binary(Data, url: URL, mimeType: String)
    case utf8(String, url: URL, mimeType: String)
    case empty
}


protocol BridgeIncomingAPI {
    func save(_ request: SaveRequest) async throws -> SaveResponse
}


class Bridge: NSObject, ObservableObject, WKScriptMessageHandler, WKScriptMessageHandlerWithReply, WKURLSchemeHandler {
    
    var colorScheme: ColorScheme?
    @MainActor weak var webview: WKWebView?
    
    var urlSchemes = [BridgeProtocol.asset.rawValue, BridgeProtocol.tlshotResponse.rawValue]
    var assetServer = BridgeAssetServer()
    var bootWaiter = Waiter("js boot")
    var renderWaiter = Waiter("tldraw render image")
    var outgoingResponses = BridgeOutgoingRequestRegistry()
    var debugLogger = BridgeDebugLogger()
    var helloWorldDelegate = BridgeHelloWorldDelegate()
    var imageName = ""
    var app: AppDelegate = AppDelegate.shared
    
    var env: BridgeEnvironment {
        BridgeEnvironment(
            appName: "tlshot",
            assetOffsetX: BridgeEnvironment.assetOffset,
            backingScaleFactor: BridgeEnvironment.scaleFactor,
            initialAsset: assetServer.getInitialAsset(),
            theme: {switch colorScheme {
            case .light: .light
            case .dark: .dark
            case nil: .dark
            default: .dark
            }}()
        )
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        // HTTP request start
        schemeHandler(urlSchemeTask)
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // HTTP request end
    }

    
    private func schemeHandler(_ urlSchemeTask: any WKURLSchemeTask) {
        Task { @MainActor in
            let request = urlSchemeTask.request
            print("<< REQUEST \(request.httpMethod ?? "?") \(request.url.debug ?? "(no url)")")
            print("   headers: \(request.allHTTPHeaderFields.debug ?? "?")")
            print("   body: \((request.httpBody?.count).debug ?? "?")")
            print("   bodyStream: \(request.httpBodyStream.debug ?? "?")")
            do {
                guard let scheme = urlSchemeTask.request.url?.scheme.flatMap({ BridgeProtocol(rawValue: $0) }) else {
                    throw TlshotError.invalidData("Invalid scheme: \(urlSchemeTask.request)")
                }
                
                let response = switch scheme {
                case .asset: try await assetServer.onRequest(request)
                case .tlshotResponse: try await outgoingResponses.onRequest(request)
                }
                
                switch response {
                case .binary(let data, url: _, mimeType: let mimeType):
                    let response = httpResponse(request: request, mimeType: mimeType, expectedContentLength: data.count)
                    urlSchemeTask.didReceive(response)
                    urlSchemeTask.didReceive(data)
                    urlSchemeTask.didFinish()
                case .utf8(let text, url: _, mimeType: let mimeType):
                    let response = httpResponse(request: request, mimeType: mimeType, expectedContentLength: text.lengthOfBytes(using: .utf8))
                    urlSchemeTask.didReceive(response)
                    guard let data = text.data(using: .utf8) else {
                        throw TlshotError.invalidData("Cannot encode text respnse")
                    }
                    urlSchemeTask.didReceive(data)
                    urlSchemeTask.didFinish()
                case .empty:
                    let response = httpResponse(request: request, mimeType: "text/plain", expectedContentLength: 0)
                    urlSchemeTask.didReceive(response)
                    urlSchemeTask.didFinish()
                }
            } catch {
                urlSchemeTask.didFailWithError(error)
                print(">> ERROR \(error)")
            }
        }
    }
    
    private func httpResponse(
        request: URLRequest,
        mimeType: String?,
        expectedContentLength: Int
    ) -> HTTPURLResponse {
        var headers: [String:String] = [:]
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Content-Type"] = mimeType
        headers["Content-Length"] = String(expectedContentLength)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: headers)
        return response!
    }
    
    
    // Notification
    typealias Notification = BridgeEnvelope<BridgeNotificationType>
    @MainActor
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        do {
            let message = try Notification.fromWebKit(message)
            switch message.type {
            case .booted:
                try bootWaiter.notify(BootedNotification.fromJSON(string: message.json).time)
            case .rendered:
                try renderWaiter.notify(RenderedNotification.fromJSON(string: message.json).time)
            case .debug:
                try debugLogger.onNotification(DebugNotification.fromJSON(string: message.json))
            case .response:
                try outgoingResponses.onNotification(ResponseNotification.fromJSON(string: message.json))
            case .prepareSave:
                let req = try SaveRequest.fromJSON(string: message.json)
                Task {
                    await app.handleErrors {
                        let img = try await getPng()
                        guard let data = img.cgImage()?.png else {
                            throw TlshotError.captureFailed("PNG creation failed")
                        }
                        try await app.saveImage(name: imageName, data: data)
                    }
                }
            }
        } catch {
            print("\(self).didReceive error: \(error)")
        }
    }
    
    // Request/Reply
    typealias Request = BridgeEnvelope<BridgeRequestType>
    @MainActor
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        do {
            let msg = try Request.fromWebKit(message)
            let response: Encodable = try await { switch msg.type {
            case .getName:
                return try await helloWorldDelegate.onRequest(.fromJSON(string: msg.json))
            case .createSVGAsset:
                let url = try assetServer.add(svg: .fromJSON(string: msg.json))
                return CreateSVGResponse(assetURL: url)
            } }()
            
            return try (response.toJSON().asString(), nil)
        } catch {
            print("\(self).didReceive error: \(error)")
            let nativeError = String(reflecting: error)
            return (nil, nativeError)
        }
    }
    
    // Swift -> WebView requests
    private func sendRequest<Req: IncomingEncodableRequest, Res: Decodable>(req: Req) async throws -> (Res, Data?) {
        let requestID = UUID().uuidString
        let requestJson = try req.toJSONString()
        let envelope = BridgeIncomingEnvelope(
            bridgeIncomingEnvelopeJSON: requestJson,
            requestID: requestID,
            type: Req.requestType
        )
        let envelopeJson = try envelope.toJSONString()
        await bootWaiter.wait()
        async let (responseEnvelope, responseHttp) = outgoingResponses.waitForResponse(requestID: requestID)
        try await evalJS("globalThis.webkit.incomingMessageHandler(\(envelopeJson))")
        let response: Res = try await responseEnvelope.result().get()
        let responseData = await responseHttp?.httpBody
        return (response, responseData)
    }
    
    
    @MainActor
    func evalJS(_ js: String) throws {
        guard let webview = self.webview else {
            throw BridgeResponseError.bridge(TlshotError.notImplemented("no webview to send to"))
        }
        webview.evaluateJavaScript(js)
    }
    
    func getPng() async throws -> NSImage {
        let msg = SaveRequest(saveID: Date.now.formatted())
        let (res, data) = try await sendRequest(req: msg) as (SaveResponse, Data?)
        guard let data = data else {
            throw TlshotError.invalidData("No data for response: \(res)")
        }
        guard let image = NSImage(data: data) else {
            throw TlshotError.invalidData("Data didn't produce valid NSImage")
        }
        return image
    }
    
    func addImageToCanvas(_ image: CGImage) async throws {
        let url = assetServer.add(image: image)
        let request = BridgeImageAssetProps(fileSize: Double(image.png?.count ?? 0), h: Double(image.height), isAnimated: false, mimeType: "image/png", name: image.hashValue.description, src: url, w: Double(image.width))
        (_, _) = try await sendRequest(req: request) as (EmptyResponse, Data?)
        // Ok.
    }
    
    func zoomToFit(inset: Bool = false, animate: Bool = false, delayMS: Double = 0) async throws {
        (_, _) = try await sendRequest(req: ZoomToFitRequest(animate: animate, delayMS: delayMS, inset: inset)) as (EmptyResponse, Data?)
    }
    
    func waitForResize(timeoutMS: Double) async throws {
        (_, _) = try await sendRequest(req: WaitForResizeRequest(timeoutMS: timeoutMS)) as (EmptyResponse, Data?)
    }

    func getUserScript() -> WKUserScript {
        let script = """
        globalThis.__BRIDGE_ENVIRONMENT__ = \(try! env.toJSON().asString()!)
        """
        
        return WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
}

