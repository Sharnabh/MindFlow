//
//  MindFlowApp.swift
//  MindFlow
//
//  Created by Sharnabh on 14/03/25.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct MindFlowApp: App {
    // Use the DependencyContainer to manage service dependencies
    private let dependencies = DependencyContainer.shared
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .environmentObject(dependencies.makeCanvasViewModel())
                .environmentObject(dependencies.makeAuthService())
                .onAppear {
                    // Register for our save notifications
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("SaveMindMap"), object: nil, queue: .main) { _ in
                        self.handleSaveMindMap()
                    }
                    
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("SaveMindMapAs"), object: nil, queue: .main) { _ in
                        self.handleSaveMindMapAs()
                    }
                    
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("NewMindMap"), object: nil, queue: .main) { _ in
                        self.handleNewMindMap()
                    }
                    
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenMindMap"), object: nil, queue: .main) { _ in
                        self.handleOpenMindMap()
                    }
                    
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("SignOut"), object: nil, queue: .main) { _ in
                        self.handleSignOut()
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Mind Map") {
                    NotificationCenter.default.post(name: NSNotification.Name("NewMindMap"), object: nil)
                }
                .keyboardShortcut("n")
                
                Button("Open...") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenMindMap"), object: nil)
                }
                .keyboardShortcut("o")
                
                Divider()
                
                Button("Home") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowStartupScreen"), object: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }
            
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: NSNotification.Name("SaveMindMap"), object: nil)
                }
                .keyboardShortcut("s")
                
                Button("Save As...") {
                    NotificationCenter.default.post(name: NSNotification.Name("SaveMindMapAs"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Export...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ExportMindMap"), object: nil)
                }
                .keyboardShortcut("e")
            }
            
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NotificationCenter.default.post(name: NSNotification.Name("UndoRequested"), object: nil)
                }
                .keyboardShortcut("z")
                
                Button("Redo") {
                    NotificationCenter.default.post(name: NSNotification.Name("RedoRequested"), object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            
            // Add a MindFlow menu group with account commands
            CommandGroup(after: .appInfo) {
                Divider()
                
                Button("Sign Out") {
                    NotificationCenter.default.post(name: NSNotification.Name("SignOut"), object: nil)
                }
                .disabled(!dependencies.makeAuthService().isAuthenticated)
            }
        }
    }
    
    private func handleSaveMindMap() {
        // We need to get the topics from the canvas view model
        // Post a notification that will be caught by the InfiniteCanvas to request the topics
        NotificationCenter.default.post(name: NSNotification.Name("RequestTopicsForSave"), object: nil)
    }
    
    private func handleSaveMindMapAs() {
        // We need to get the topics from the canvas view model
        // Post a notification that will be caught by the InfiniteCanvas to request the topics for Save As
        NotificationCenter.default.post(name: NSNotification.Name("RequestTopicsForSaveAs"), object: nil)
    }
    
    private func handleOpenMindMap() {
        // Call the AppDelegate method directly to open the file picker
        // This is the ONLY place that should trigger the file picker flow
        appDelegate.showOpenPanel()
    }
    
    private func handleNewMindMap() {
        // Show the template selection popup
        NotificationCenter.default.post(name: NSNotification.Name("ShowTemplateSelection"), object: nil)
    }
    
    private func handleSignOut() {
        // Get auth service and sign out
        let authService = dependencies.makeAuthService()
        if authService.isAuthenticated {
            do {
                try authService.signOut()
            } catch {
                // Show an alert for sign out errors
                let alert = NSAlert()
                alert.messageText = "Sign Out Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    // Add a static property to track if an open panel is already showing
    private static var isShowingOpenPanel = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register file type association without using setValue:forKey:
        // The correct way to register file types is through Info.plist, which we've already done
        
        // No need to set documentClassNames, as it's not a valid property on NSDocumentController
        
        // Configure the document controller if needed
        let documentController = NSDocumentController.shared
        documentController.autosavingDelay = 10.0 // Auto save every 10 seconds
        
        // Initialize the export manager
        _ = ExportManager.shared
    }
    
    // Handle files opened through Finder
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Add to recent files
        let newRecentFile = StartupScreenView.RecentFile(
            name: url.lastPathComponent,
            date: Date(),
            url: url
        )
        UserDefaults.standard.addToRecentFiles(newRecentFile)
        
        // Load the file
        MindFlowFileManager.shared.loadFile(from: url) { loadedTopics, errorMessage in
            if let topics = loadedTopics {
                // Notify the canvas view model to load these topics
                NotificationCenter.default.post(
                    name: NSNotification.Name("LoadTopics"),
                    object: nil,
                    userInfo: ["topics": topics]
                )
            } else if let error = errorMessage {
                // Display error alert
                let alert = NSAlert()
                alert.messageText = "Failed to open file"
                alert.informativeText = error
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    @objc func showOpenPanel() {
        // Prevent multiple panels from being shown
        guard !AppDelegate.isShowingOpenPanel else { return }
        
        AppDelegate.isShowingOpenPanel = true
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [UTType.mindFlowType]
        
        openPanel.begin { response in
            // Mark that we're no longer showing the panel
            AppDelegate.isShowingOpenPanel = false
            
            if response == .OK, let url = openPanel.url {
                // Use a different notification name to avoid a loop
                NotificationCenter.default.post(name: Notification.Name("LoadDocumentFromURL"), object: url)
            }
        }
    }
}
