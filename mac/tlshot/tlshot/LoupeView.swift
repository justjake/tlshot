//
//  LoupeView.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/11/24.
//

import SwiftUI

class LoupeViewPanel: ObservableObject  {
    @Published var viewOrigin: NSPoint = .zero
    @Published var viewSize: NSSize = NSSize(width: 100, height: 100)
    @Published var sampleSize: NSSize = NSSize(width: 50, height: 50)
    @Published var sampleCenter: NSPoint = .zero
    
    var sampleRect: NSRect {
        let dx = sampleSize.width / 2
        let dy = sampleSize.height / 2
        return NSRect(origin: sampleCenter.applying(.init(translationX: -dx, y: -dy)), size: sampleSize)
    }
    
    var frameRect: NSRect {
        NSRect(origin: viewOrigin, size: viewSize)
    }
    
    lazy var panel: some NSPanel = OverlayPanel(frameRect) {
        LoupeView(props: self)
    }
    
    func moveTo(_ point: NSPoint) {
        viewOrigin = point
        panel.setFrame(frameRect, display: true)
    }
    
    func sampleImage() -> CGImage? {
        CGWindowListCreateImage(sampleRect, .optionOnScreenBelowWindow, CGWindowID(panel.windowNumber),  [.shouldBeOpaque, .bestResolution])
    }
}

struct LoupeView: View {
    @ObservedObject var props: LoupeViewPanel
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

