//
//  ContentView.swift
//  MindFlow
//
//  Created by Sharnabh on 14/03/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        InfiniteCanvas()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    ContentView()
}
