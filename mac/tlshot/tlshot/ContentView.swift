//
//  ContentView.swift
//  tlshot
//
//  Created by Jake Teton-Landis on 7/10/24.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: TldrawDocument
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView(document: Binding.constant(TldrawDocument()))
}
