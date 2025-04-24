import SwiftUI
import UniformTypeIdentifiers

class MindFlowDocument: Identifiable, ObservableObject {
    let id = UUID()
    let filename: String
    let url: URL?
    @Published var topics: [Topic]
    @Published var isModified: Bool = false
    
    init(filename: String, url: URL? = nil, topics: [Topic] = []) {
        self.filename = filename
        self.url = url
        self.topics = topics
    }
    
    // Helper to save the document
    func save(completion: @escaping (Bool, String?) -> Void) {
        if let url = url {
            // Save to existing URL
            MindFlowFileManager.shared.saveFile(topics: topics, to: url, completion: completion)
        } else {
            // Need to show save dialog first
            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = true
            savePanel.title = "Save Mind Map"
            savePanel.nameFieldStringValue = filename
            savePanel.allowedContentTypes = [UTType.mindFlowType]
            
            savePanel.begin { result in
                if result == .OK, let newURL = savePanel.url {
                    // Save to the selected URL
                    MindFlowFileManager.shared.saveFile(topics: self.topics, to: newURL) { success, errorMessage in
                        if success {
                            // Update our URL
                            DispatchQueue.main.async {
                                // We can't directly update the URL property as it's let, but we
                                // can update through the DocumentManager
                                DocumentManager.shared.updateDocumentURL(self, newURL: newURL)
                            }
                        }
                        completion(success, errorMessage)
                    }
                } else {
                    // User cancelled
                    completion(false, "Save operation cancelled")
                }
            }
        }
    }
} 
