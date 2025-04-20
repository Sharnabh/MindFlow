//
//  ContentView.swift
//  MindFlow
//
//  Created by Sharnabh on 14/03/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: CanvasViewModel
    @State private var showingStartupScreen = true
    @State private var showingTemplatePopup = false
    
    var body: some View {
        ZStack {
            // Main canvas view, shown when startup screen is dismissed
            if !showingStartupScreen {
                InfiniteCanvas(viewModel: viewModel)
            } else {
                // Startup screen
                StartupScreenView(showingStartupScreen: $showingStartupScreen)
            }
            
            // Template selection popup (when active)
            if showingTemplatePopup {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // Close popup if tapped outside
                        showingTemplatePopup = false
                    }
                
                TemplateSelectionPopup { templateType in
                    // Handle template selection
                    showingTemplatePopup = false
                    createNewFromTemplate(templateType: templateType)
                }
                .zIndex(100)
            }
        }
        .onAppear {
            // Check if should show startup screen or not
            // For example, if app was launched with a file
            if let fileURL = NSApp.currentEvent?.window?.representedURL {
                showingStartupScreen = false
            }
            
            // Register for notification to show startup screen
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowStartupScreen"),
                object: nil,
                queue: .main) { _ in
                    showingStartupScreen = true
            }
            
            // Register for notification to show template selection popup
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowTemplateSelection"),
                object: nil,
                queue: .main) { _ in
                    showingTemplatePopup = true
            }
        }
    }
    
    // Create new file from template
    func createNewFromTemplate(templateType: TemplateType) {
        // Create a central topic with template type (but don't add it to canvas yet)
        let centralTopic = Topic(
            name: templateType.rawValue, 
            position: CGPoint(x: 0, y: 0),
            templateType: templateType
        )
        
        // Open save dialog first
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = true
        savePanel.title = "Save New Mind Map"
        savePanel.nameFieldStringValue = templateType.rawValue
        savePanel.allowedContentTypes = [UTType.mindFlowType]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                // Close the startup screen and show the canvas
                showingStartupScreen = false
                
                // Clear the canvas
                MindFlowFileManager.shared.newFile()
                NotificationCenter.default.post(name: NSNotification.Name("ClearCanvas"), object: nil)
                
                // Create a new mind map with a template structure
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Add the central topic to the canvas
                    self.viewModel.topicService.addTopic(centralTopic)
                    
                    // Select the topic
                    self.viewModel.topicService.selectTopic(withId: centralTopic.id)
                    
                    // Save the file
                    MindFlowFileManager.shared.saveFile(topics: [centralTopic], to: url) { success, errorMessage in
                        if success {
                            // Set as current file
                            MindFlowFileManager.shared.currentURL = url
                            
                            // Add to recent files
                            let newRecentFile = StartupScreenView.RecentFile(
                                name: url.lastPathComponent,
                                date: Date(),
                                url: url
                            )
                            UserDefaults.standard.addToRecentFiles(newRecentFile)
                        } else if let error = errorMessage {
                            // Display error alert
                            let alert = NSAlert()
                            alert.messageText = "Failed to save file"
                            alert.informativeText = error
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DependencyContainer.shared.makeCanvasViewModel())
}
