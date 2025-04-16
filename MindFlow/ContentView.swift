//
//  ContentView.swift
//  MindFlow
//
//  Created by Sharnabh on 14/03/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CanvasViewModel
    
    var body: some View {
        InfiniteCanvas(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
        .environmentObject(DependencyContainer.shared.makeCanvasViewModel())
}
