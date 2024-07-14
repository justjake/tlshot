//
//  CursorModifier.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/13/24.
//
// https://stackoverflow.com/questions/77034477/how-to-change-nscursor-permanently-in-app-area

import SwiftUI

extension NSCursor {
    var debugName: String {
        return switch self {
        case NSCursor.arrow: "arrow"
        case NSCursor.pointingHand: "pointingHand"
        case NSCursor.dragCopy: "dragCopy"
        case NSCursor.crosshair: "crosshair"
        default: String(reflecting: self)
        }
    }
}

extension View {
    func cursor(_ cursor: NSCursor?) -> some View {
        self.modifier(CursorModifier(cursor: cursor))
    }
}

struct CursorModifier: ViewModifier {
    let cursor: NSCursor?
    
    func body(content: Content) -> some View {
        // Overlay?
        // Background?
        // It never works consistently... :(
        content
            .overlay { CursorView(cursor: cursor) }
    }
}

private struct CursorView: NSViewRepresentable {
    let cursor: NSCursor?
    
    private var cursorWithDefault: NSCursor {
        cursor ?? NSCursor.arrow
    }
    
    func makeNSView(context: Context) -> NSViewType {
//        print("CursorView: make \(cursorWithDefault.debugName)")
        return NSViewType(cursor: cursorWithDefault)
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
//        print("CursorView: update \(cursorWithDefault.debugName)")
        nsView.cursor = cursorWithDefault
        nsView.window?.invalidateCursorRects(for: nsView)
    }
    
    class NSViewType: NSView {
        var cursor: NSCursor
        
        init(cursor: NSCursor) {
            self.cursor = cursor
            super.init(frame: .zero)
        }
        
        required init?(coder: NSCoder) { fatalError() }
        
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: cursor)
        }
    }
}
