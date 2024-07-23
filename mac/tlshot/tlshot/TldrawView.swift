//
//  TldrawView.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/15/24.
//

import SwiftUI
import WebKit

struct TldrawWebView: NSViewRepresentable {
    static var sharedProcessPool = WKProcessPool()
    
    var bridge: Bridge
    @Environment(\.colorScheme) var colorScheme

    class Coordinator: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        }
        
        var userContentController = WKUserContentController()
        var configuration: WKWebViewConfiguration
        var bridge: Bridge

        init(_ bridge: Bridge) {
            self.bridge = bridge
            configuration = WKWebViewConfiguration()
            configuration.userContentController = userContentController
            configuration.processPool = TldrawWebView.sharedProcessPool
            // need to include the word "Safari" to get tldraw to apply WebKit fixes
            // https://github.com/tldraw/tldraw/blob/348ff9f66a24cc41738a2eff10a87ef6b535bf3f/packages/editor/src/lib/editor/managers/EnvironmentManager.ts#L7
            configuration.applicationNameForUserAgent = "tlshot (like Safari)"
            configuration.limitsNavigationsToAppBoundDomains = true
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
            configuration.preferences.isTextInteractionEnabled = true
            userContentController.add(bridge as WKScriptMessageHandler, name: "notify")
            userContentController.addScriptMessageHandler(bridge as WKScriptMessageHandlerWithReply, contentWorld: .page, name: "request")
            userContentController.addUserScript(bridge.getUserScript())
            for scheme in bridge.urlSchemes {
                configuration.setURLSchemeHandler(bridge, forURLScheme: scheme)
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            print("Navigation failed: \(error)")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("Navigation finished")
            print("------------------------------------------------")
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            print("Navigation started")
        }
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // https://stackoverflow.com/questions/65997524/wkwebview-in-swiftui-not-loading-html-string-on-macos
            print("Process terminated")
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(bridge) }
    
    func makeNSView(context: Context) -> WKWebView {
        let webview = WKWebView(frame: .zero, configuration: context.coordinator.configuration)
        webview.isInspectable = true
        webview.navigationDelegate = context.coordinator
        let preview = "http://localhost:5173/"
        webview.load(URLRequest(url: URL(string: preview)!))
        context.coordinator.bridge.webview = webview
        context.coordinator.bridge.colorScheme = colorScheme
        return webview
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.bridge = bridge
        context.coordinator.bridge.webview = nsView
        context.coordinator.bridge.colorScheme = colorScheme
    }
}

#Preview {
    VStack {
        Text("Rendered at \(Date())").padding(6)
        
        let bridge = Bridge()
        TldrawWebView(bridge: bridge) .expand()
    }
}
