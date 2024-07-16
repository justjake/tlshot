//
//  TldrawView.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/15/24.
//

import SwiftUI
import WebKit

struct TldrawView: View {
    var body: some View {
        TldrawWebView()
            .expand()
    }
}

struct TldrawWebView: NSViewRepresentable {
    var bridgeEnvironment: BridgeEnvironment = BridgeEnvironment(appName: "tlshot", initialFileURL: nil, theme: .light)
    @Environment(\.colorScheme) var colorScheme

    class Coordinator: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        }
        
        var view: TldrawWebView {
            get { _view }
            set {
                _view = newValue
                bridge.view = newValue
            }
        }
        
        private var _view: TldrawWebView
        var userContentController = WKUserContentController()
        var configuration: WKWebViewConfiguration
        var bridge: BridgeMessageDelegate

        init(_ view: TldrawWebView) {
            self._view = view
            bridge = BridgeMessageDelegate(view)
            configuration = WKWebViewConfiguration()
            configuration.userContentController = userContentController
            configuration.applicationNameForUserAgent = "tlshot"
            configuration.limitsNavigationsToAppBoundDomains = true
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
            configuration.preferences.isTextInteractionEnabled = true
            userContentController.add(bridge as WKScriptMessageHandler, name: "notify")
            userContentController.addScriptMessageHandler(bridge as WKScriptMessageHandlerWithReply, contentWorld: .page, name: "request")
            userContentController.addUserScript(bridge.getUserScript())
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
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.view = self
        let view = WKWebView(frame: .zero, configuration: context.coordinator.configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: URL(string: "http://localhost:5173/")!))
        return view
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.view = self
    }
}

#Preview {
    VStack {
        Text("Rendered at \(Date())").padding(6)
        
    TldrawView()
        .expand()
    }
}
