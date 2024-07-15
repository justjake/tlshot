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
    class Coordinator: NSObject, ObservableObject, WKNavigationDelegate {
        var userContentController = WKUserContentController()
        var configuration: WKWebViewConfiguration
        
        override init() {
            configuration = WKWebViewConfiguration()
            configuration.userContentController = userContentController
            configuration.applicationNameForUserAgent = "tlshot"
            configuration.limitsNavigationsToAppBoundDomains = true
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
            configuration.preferences.isTextInteractionEnabled = true
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            print("Navigation failed: \(error)")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("Navigation finished")
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            print("Navigation started")
        }
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // https://stackoverflow.com/questions/65997524/wkwebview-in-swiftui-not-loading-html-string-on-macos
            print("Process terminated")
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: context.coordinator.configuration)
        view.navigationDelegate = context.coordinator
        
        print("makeNSView")
        
//        view.loadHTMLString("<body><h1>tlshot</h1></body>", baseURL: nil)
        
        return view
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        print("updateNSView")
        nsView.loadHTMLString("<body><h1>tlshot</h1></body>", baseURL: nil)
        // Pass.
    }
}

#Preview {
    TldrawView()
        .expand()
}
