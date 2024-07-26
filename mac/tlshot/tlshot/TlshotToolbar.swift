//
//  TlshotToolbar.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/26/24.
//


import SwiftUI

struct TlshotToolbar: View {
    typealias Action = () -> Void
    let onCaptureWindow: Action
    let onCaptureArea: Action
    let onCopyAndDelete: Action
    let onDelete: Action
    let onSave: Action
    
    var body: some View {
        Button(action: onCaptureWindow) {
            Label("Capture Window...", systemImage: "macwindow.badge.plus")
        }.help("Add more windows to this capture")
        Button(action: onCaptureArea) {
            Label("Capture Area...", systemImage: "rectangle.badge.plus")
        }.help("Add another area to this capture")
        
        Spacer()
        
        Button(action: onCopyAndDelete) {
            Label(
                title: { Text("Copy & Delete") },
                icon: {
                    HStack(spacing: -1) {
                        Image(systemName: "doc.on.doc")
                        Image(systemName: "plus").imageScale(.small)
                        Image(systemName: "trash")
                    }
                }
            )
        }.help("Copy to clipboard then close without saving")
        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            .help("Close without saving")
        
        Spacer()
        
        Button("Save and close", systemImage: "checkmark.circle", action: onSave)
            .help("Save and close")
    }
}

#Preview {
    let toolbar = TlshotToolbar(onCaptureWindow: {}, onCaptureArea: {}, onCopyAndDelete: {}, onDelete: {}, onSave: {})

    return VStack {
        Spacer()
        HStack {
            toolbar
        }
        .padding()
        .background(.bar)
    }
    .background(.windowBackground)
    .expand()
    .toolbar {
        toolbar
    }
    
}
