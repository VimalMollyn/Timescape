//
//  ContentView.swift
//  Timescape
//
//  Created by Vimal Mollyn on 12/8/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .frame(minWidth: 400, minHeight: 150)
    }
}

#Preview {
    ContentView()
}
