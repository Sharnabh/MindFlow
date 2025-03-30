//
//  MindFlowApp.swift
//  MindFlow
//
//  Created by Sharnabh on 14/03/25.
//

import SwiftUI

@main
struct MindFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
                }
        }
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
        // Post a notification that will be caught by the InfiniteCanvas to load a file
        NotificationCenter.default.post(name: NSNotification.Name("LoadMindMap"), object: nil)
    }
    
    private func handleNewMindMap() {
        // Create a new empty mind map
        MindFlowFileManager.shared.newFile()
        
        // Notify the canvas to clear the current topics and create a new mind map
        NotificationCenter.default.post(name: NSNotification.Name("ClearCanvas"), object: nil)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register file type association without using setValue:forKey:
        // The correct way to register file types is through Info.plist, which we've already done
        
        // No need to set documentClassNames, as it's not a valid property on NSDocumentController
        
        // Configure the document controller if needed
        let documentController = NSDocumentController.shared
        documentController.autosavingDelay = 10.0 // Auto save every 10 seconds
    }
    
    // Handle files opened through Finder
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        
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
}
