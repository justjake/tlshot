//
//  PermissionWarningView.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/11/24.
//

import SwiftUI

struct PermissionWarningView: View {
    let onClose: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("Screen recording permission denied").font(.headline).foregroundStyle(.orange)
            Text("tlshot needs permission to take screenshots and record your screen")
            Text("In Security > Screen & System Audio Recording, find 'tlshot' and turn on the switch")
            Text("You may need to restart tlshot afterwards")
            Button("Open Screen Capture Settings") {
                openSystemSettings()
            }
            Button("Close") {
                onClose()
            }
        }
    }
    
    func openSystemSettings() {
        AppDelegate.openSystemSettings()
    }
}

class PermissionWarningOverlay {
    static let size = CGSize(width: 400, height: 800)
    static var center: CGPoint {
        NSScreen.main?.frame.center ?? .zero
    }
    
    lazy var panel: some NSPanel = {
        let panel = OverlayPanel(
            contentRect: .init(center: Self.center, size: Self.size)
        ) {
            PermissionWarningView(onClose: self.handleCloseClick).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        
        panel.backgroundColor = .none
        panel.animationBehavior = .alertPanel
        panel.styleMask = [.hudWindow]
        
        return panel
    }()
    
    func handleCloseClick() {
        panel.close()
    }
    
}

#Preview {
    PermissionWarningView() {}
}
