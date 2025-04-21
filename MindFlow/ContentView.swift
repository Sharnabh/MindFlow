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
    @ObservedObject private var documentManager = DocumentManager.shared
    
    // Panel reference to prevent multiple panels
    private static var currentOpenPanel: NSOpenPanel? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Only show tab bar when not on startup screen
            if !showingStartupScreen {
                DocumentTabBar()
            }
            
            ZStack {
                if !showingStartupScreen {
                    // Main canvas view with active document's topics
                    if let activeDocument = documentManager.activeDocument {
                        // Update view model with current document's topics
                        InfiniteCanvas(viewModel: viewModel)
                            .onAppear {
                                viewModel.topicService.updateAllTopics(activeDocument.topics)
                            }
                            .onChange(of: documentManager.activeDocumentIndex) { _, _ in
                                if let document = documentManager.activeDocument {
                                    viewModel.topicService.updateAllTopics(document.topics)
                                }
                            }
                    } else {
                        // Fallback if no active document
                        Text("No document open")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                } else {
                    // Startup screen
                    StartupScreenView(showingStartupScreen: $showingStartupScreen)
                        .onChange(of: showingStartupScreen) { _, isShowing in
                            if !isShowing && documentManager.documents.isEmpty {
                                // If we're hiding the startup screen but have no documents,
                                // create a default one
                                documentManager.createNewDocument(name: "Untitled")
                            }
                        }
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
        }
        .onAppear {
            // Check if should show startup screen or not
            // For example, if app was launched with a file
            if let fileURL = NSApp.currentEvent?.window?.representedURL {
                showingStartupScreen = false
                documentManager.openDocument(from: fileURL)
            }
            
            // Register for notifications
            registerNotifications()
        }
    }
    
    // Register for all notifications
    private func registerNotifications() {
        // Show startup screen
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowStartupScreen"),
            object: nil,
            queue: .main) { _ in
                showingStartupScreen = true
        }
        
        // Show template selection
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowTemplateSelection"),
            object: nil,
            queue: .main) { _ in
                showingTemplatePopup = true
        }
        
        // Open mind map - this is only for backward compatibility and should NOT be used for file opening
        // It's kept here in case other parts of the app still use this notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenMindMap"),
            object: nil,
            queue: .main) { notification in
                // Only handle if no URL is provided (this should be rare/never happen)
                if notification.object == nil {
                    // We don't call openFilePicker here anymore
                    // That's handled through the menu -> AppDelegate.showOpenPanel
                }
                else if let url = notification.object as? URL {
                    // Direct URL handling (backward compatibility)
                    showingStartupScreen = false
                    documentManager.openDocument(from: url)
                }
        }
        
        // Load document from URL (this is the primary way files are opened)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LoadDocumentFromURL"),
            object: nil,
            queue: .main) { notification in
                if let url = notification.object as? URL {
                    showingStartupScreen = false
                    documentManager.openDocument(from: url)
                }
        }
        
        // Save topics from canvas to document
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SaveTopicsToDocument"),
            object: nil, 
            queue: .main) { notification in
                if let topics = notification.userInfo?["topics"] as? [Topic],
                   let document = documentManager.activeDocument {
                    // Update document with latest topics
                    document.topics = topics
                    document.isModified = true
                }
        }
    }
    
    // This method should only be called directly, not through notifications
    // We're keeping it for completeness but it should not be used in the notification flow
    private func openFilePicker() {
        // If a panel is already open, don't create another one
        guard ContentView.currentOpenPanel == nil else { return }
        
        let openPanel = NSOpenPanel()
        ContentView.currentOpenPanel = openPanel
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [UTType.mindFlowType]
        
        openPanel.begin { response in
            // Clear the reference when done
            ContentView.currentOpenPanel = nil
            
            if response == .OK, let url = openPanel.url {
                showingStartupScreen = false
                documentManager.openDocument(from: url)
            }
        }
    }
    
    // Create new file from template
    func createNewFromTemplate(templateType: TemplateType) {
        // Close startup screen if showing
        showingStartupScreen = false
        
        // Create a new document with the selected template
        documentManager.createNewDocument(
            name: "Untitled \(documentManager.documents.count + 1)",
            templateType: templateType
        )
        
        // Open save dialog
        if let document = documentManager.activeDocument {
            document.save { _, _ in
                // No special handling needed here - errors are handled in the save method
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DependencyContainer.shared.makeCanvasViewModel())
}
