import SwiftUI
import UniformTypeIdentifiers

class DocumentManager: ObservableObject {
    static let shared = DocumentManager()
    
    @Published var documents: [MindFlowDocument] = []
    @Published var activeDocumentIndex: Int = -1
    
    private init() {
        // Initialize with an empty document if needed
        createNewDocument(name: "Untitled")
        
        // Register for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSaveDocument),
            name: NSNotification.Name("SaveActiveDocument"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSaveAsDocument),
            name: NSNotification.Name("SaveAsActiveDocument"),
            object: nil
        )
    }
    
    @objc private func handleSaveDocument() {
        saveActiveDocument { _, _ in }
    }
    
    @objc private func handleSaveAsDocument() {
        saveActiveDocumentAs()
    }
    
    // Create a new document with the given template type
    func createNewDocument(name: String, templateType: TemplateType = .mindMap) {
        let centralTopic = Topic(
            name: templateType.rawValue,
            position: CGPoint(x: 0, y: 0),
            templateType: templateType
        )
        
        let newDocument = MindFlowDocument(filename: name, topics: [centralTopic])
        documents.append(newDocument)
        activeDocumentIndex = documents.count - 1
    }
    
    // Open an existing document from URL
    func openDocument(from url: URL) {
        // Check if the document is already open
        if let existingIndex = documents.firstIndex(where: { $0.url == url }) {
            // Just switch to it
            activeDocumentIndex = existingIndex
            return
        }
        
        MindFlowFileManager.shared.loadFile(from: url) { loadedTopics, errorMessage in
            if let topics = loadedTopics {
                // Create new document
                let filename = url.lastPathComponent
                let newDocument = MindFlowDocument(filename: filename, url: url, topics: topics)
                
                DispatchQueue.main.async {
                    self.documents.append(newDocument)
                    self.activeDocumentIndex = self.documents.count - 1
                    
                    // Add to recent files
                    let newRecentFile = StartupScreenView.RecentFile(
                        name: filename,
                        date: Date(),
                        url: url
                    )
                    UserDefaults.standard.addToRecentFiles(newRecentFile)
                }
            } else {
                // Show error
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Failed to open file"
                    alert.informativeText = errorMessage ?? "Unknown error"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    // Close a document
    func closeDocument(at index: Int) {
        guard index >= 0 && index < documents.count else { return }
        
        let documentToClose = documents[index]
        
        // If document is modified, prompt to save
        if documentToClose.isModified {
            let alert = NSAlert()
            alert.messageText = "Save changes to \(documentToClose.filename)?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn: // Save
                documentToClose.save { success, _ in
                    if success {
                        DispatchQueue.main.async {
                            self.performClose(at: index)
                        }
                    }
                }
                return
            case .alertSecondButtonReturn: // Don't Save
                // Continue with close
                break
            default: // Cancel
                return
            }
        }
        
        performClose(at: index)
    }
    
    private func performClose(at index: Int) {
        documents.remove(at: index)
        
        // Update active document index
        if documents.isEmpty {
            // Create a new empty document if all are closed
            createNewDocument(name: "Untitled")
        } else if activeDocumentIndex >= documents.count {
            activeDocumentIndex = documents.count - 1
        } else if activeDocumentIndex > index {
            // If we closed a document before the active one, shift the index
            activeDocumentIndex -= 1
        }
    }
    
    // Save the active document
    func saveActiveDocument(completion: @escaping (Bool, String?) -> Void) {
        guard activeDocumentIndex >= 0 && activeDocumentIndex < documents.count else {
            completion(false, "No active document")
            return
        }
        
        documents[activeDocumentIndex].save(completion: completion)
    }
    
    // Update document URL after save
    func updateDocumentURL(_ document: MindFlowDocument, newURL: URL) {
        // Since we can't modify the URL property directly, we need to create a new document
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            let newDocument = MindFlowDocument(
                filename: newURL.lastPathComponent,
                url: newURL,
                topics: document.topics
            )
            documents[index] = newDocument
        }
    }
    
    // Get the active document
    var activeDocument: MindFlowDocument? {
        guard activeDocumentIndex >= 0 && activeDocumentIndex < documents.count else {
            return nil
        }
        return documents[activeDocumentIndex]
    }
    
    // Save the active document with Save As dialog
    func saveActiveDocumentAs() {
        guard activeDocumentIndex >= 0 && activeDocumentIndex < documents.count else {
            return
        }
        
        let document = documents[activeDocumentIndex]
        
        // Create a new URL via Save As dialog
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = true
        savePanel.title = "Save Mind Map As"
        savePanel.nameFieldStringValue = document.filename
        savePanel.allowedContentTypes = [UTType.mindFlowType]
        
        savePanel.begin { result in
            if result == .OK, let newURL = savePanel.url {
                // Save to the selected URL
                MindFlowFileManager.shared.saveFile(topics: document.topics, to: newURL) { success, errorMessage in
                    if success {
                        // Update our URL
                        DispatchQueue.main.async {
                            self.updateDocumentURL(document, newURL: newURL)
                            
                            // Add to recent files
                            let newRecentFile = StartupScreenView.RecentFile(
                                name: newURL.lastPathComponent,
                                date: Date(),
                                url: newURL
                            )
                            UserDefaults.standard.addToRecentFiles(newRecentFile)
                        }
                    } else if let error = errorMessage {
                        // Show error
                        DispatchQueue.main.async {
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
