//
//  PermissionWarningView.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/11/24.
//

import SwiftUI

struct PermissionWarningView: View {
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
        }
    }
    
    // https://github.com/feedback-assistant/reports/issues/184
    // https://gist.github.com/iccir/c1da6e537718b99b0c14ef76765aec45
    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    PermissionWarningView()
}
