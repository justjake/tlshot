//
//  TldrawView.swift
//
//  Created by Jake Teton-Landis on 7/15/24.
//

import SwiftUI
import WebKit

struct TldrawWebView: NSViewRepresentable {
    static var sharedProcessPool = WKProcessPool()
    
    var bridge: Bridge
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var app: AppDelegate

    class Coordinator: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        }
        
        var userContentController = WKUserContentController()
        var configuration: WKWebViewConfiguration
        var bridge: Bridge

        init(_ bridge: Bridge, _ app: AppDelegate) {
            self.bridge = bridge
            bridge.app = app
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
            Task { await bridge.app.showErrorAlert(error: error) }
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
        
        @MainActor
        func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
            guard let window = webView.window else {
                return nil
            }
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = parameters.allowsMultipleSelection
            panel.canChooseDirectories = parameters.allowsDirectories
            guard await panel.beginSheetModal(for: window) == .OK else {
                return nil
            }
            return panel.urls
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(bridge, app)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let webview = WKWebView(frame: .zero, configuration: context.coordinator.configuration)
        webview.underPageBackgroundColor = .clear
        webview.uiDelegate = context.coordinator
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
        context.coordinator.bridge.app = app
        context.coordinator.bridge.webview = nsView
        context.coordinator.bridge.colorScheme = colorScheme
    }
}

#Preview {
    VStack {
        Text("Rendered at \(Date())").padding(.top, 8)
        
        let bridge = Bridge()
        TldrawWebView(bridge: bridge)
            .toolbar {
                ToolbarItemGroup {
                    Button(action: {}) {
                        Label("Capture Window", systemImage: "macwindow.badge.plus")
                    }
                    Button(action: {}) {
                        Label("Capture Area", systemImage: "rectangle.badge.plus")
                    }
                    
                    Spacer(minLength: 100)

                    Button(action: {}) {
                        HStack(spacing: -1) {
                            Image(systemName: "doc.on.doc")
                            Image(systemName: "plus").imageScale(.small)
                            Image(systemName: "trash")
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {}

                    Button(action: {}) {
                        HStack(spacing: -1) {
                            Image(systemName: "doc.on.doc")
                            Image(systemName: "plus").imageScale(.small)
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    
                    Button("Done", systemImage: "checkmark.circle") {}
                    //                    Button(action: {}) {
                    //                        HStack(spacing: -1) {
                    //                            Image(systemName: "square.and.arrow.down")
                    //                            Image(systemName: "plus").imageScale(.small)
                    //                            Image(systemName: "xmark.circle")
                    //                        }
                    //                    }

                    
                }
            }
            .expand()
    }.environmentObject(AppDelegate.shared)
}
