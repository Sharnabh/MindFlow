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
    @State private var showShareView = false
    @ObservedObject private var documentManager = DocumentManager.shared
    
    // Get authentication service from dependency container
    private let authService = DependencyContainer.shared.makeAuthService()
    
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
                    StartupScreenView(showingStartupScreen: $showingStartupScreen, authService: authService)
                        .environmentObject(viewModel)
                        .environmentObject(authService)
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
            
            // User authentication/profile indicator in toolbar
            HStack {
                Spacer()
                
                // Share/Collaborate button
                if !showingStartupScreen, let document = documentManager.activeDocument {
                    Button(action: {
                        showShareView = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.accentColor)
                            
                            Text("Collaborate")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!authService.isAuthenticated)
                    .popover(isPresented: $showShareView) {
                        if let document = documentManager.activeDocument,
                           let viewModel = ShareViewModel.create(for: document) {
                            ShareView(viewModel: viewModel)
                                .frame(width: 400, height: 500)
                                .padding()
                        } else {
                            Text("Cannot share document. Please make sure you're signed in and the document has been saved.")
                                .padding()
                                .frame(width: 300)
                        }
                    }
                    .padding(.trailing, 12)
                }
                
                Menu {
                    if authService.isAuthenticated, let user = authService.currentUser {
                        Text(user.displayName)
                            .font(.headline)
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Button("Sign Out") {
                            do {
                                try authService.signOut()
                            } catch {
                                print("Failed to sign out: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        Button("Sign In") {
                            if let authState = authState {
                                authState.presentAuthFlow()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if authService.isAuthenticated, let user = authService.currentUser {
                            // Show user's profile pic/initials
                            if let photoURL = user.photoURL {
                                AsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Text(String(user.displayName.prefix(1)))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                            } else {
                                Text(String(user.displayName.prefix(1)))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.accentColor))
                                    .foregroundColor(.white)
                            }
                            
                            Text(user.displayName)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.accentColor)
                            
                            Text("Sign In")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
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
        // Add auth flow to ContentView
        .withAuthFlow(authService: authService)
    }
    
    // Environment value to access the auth state
    @Environment(\.authState) private var authState
    
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
        
        // Collaboration notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowShareView"),
            object: nil,
            queue: .main) { _ in
                if !showingStartupScreen, documentManager.activeDocument != nil {
                    showShareView = true
                }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowCollaboratorsView"),
            object: nil,
            queue: .main) { _ in
                if !showingStartupScreen, documentManager.activeDocument != nil {
                    // We'll use the same share view which includes collaborators
                    showShareView = true
                }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EnableCollaboration"),
            object: nil,
            queue: .main) { _ in
                if !showingStartupScreen, let document = documentManager.activeDocument {
                    viewModel.topicService.enableCollaboration(documentId: document.id.uuidString)
                }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DisableCollaboration"),
            object: nil,
            queue: .main) { _ in
                if !showingStartupScreen {
                    viewModel.topicService.disableCollaboration()
                }
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
