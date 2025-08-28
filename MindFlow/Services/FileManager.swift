import Foundation
import SwiftUI
import UniformTypeIdentifiers

class MindFlowFileManager {
    static let shared = MindFlowFileManager()
    
    private var _currentURL: URL?
    var currentURL: URL? {
        get { return _currentURL }
        set { _currentURL = newValue }
    }
    
    private init() {}
    
    func saveCurrentFile(topics: [Topic], completion: @escaping (Bool, String?) -> Void) {
        // If we have a current file URL, save to it
        if let fileURL = _currentURL {
            saveFile(topics: topics, to: fileURL, completion: completion)
        } else {
            // Otherwise, prompt for a save location
            saveFileAs(topics: topics, completion: completion)
        }
    }
    
    func saveFileAs(topics: [Topic], completion: @escaping (Bool, String?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = true
        savePanel.title = "Save Mind Map"
        savePanel.nameFieldStringValue = "Untitled"
        savePanel.allowedContentTypes = [UTType.mindFlowType]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                self._currentURL = url
                self.saveFile(topics: topics, to: url, completion: completion)
                
                // Add to recent files
                let newRecentFile = StartupScreenView.RecentFile(
                    name: url.lastPathComponent,
                    date: Date(),
                    url: url
                )
                UserDefaults.standard.addToRecentFiles(newRecentFile)
            } else {
                completion(false, "Save operation cancelled")
            }
        }
    }
    
    func saveFile(topics: [Topic], to url: URL, completion: @escaping (Bool, String?) -> Void) {
        do {
            // Create the file content with our custom format
            print("Attempting to encode \(topics.count) topics")
            
            // Try each topic individually to find the problematic one
            for (index, topic) in topics.enumerated() {
                do {
                    let encoder = JSONEncoder()
                    _ = try encoder.encode(topic)
                } catch {
                    print("Error encoding topic at index \(index): \(error.localizedDescription)")
                    completion(false, "Error encoding topic at index \(index): \(error.localizedDescription)")
                    return
                }
            }
            
            let fileData = try encodeTopics(topics)
            
            // Write the data to the file
            try fileData.write(to: url)
            
            // Update the current URL
            self._currentURL = url
            
            // Call the completion handler
            completion(true, nil)
        } catch {
            print("Failed to save file: \(error)")
            completion(false, "Failed to save file: \(error.localizedDescription)")
        }
    }
    
    func loadFile(completion: @escaping ([Topic]?, String?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Open Mind Map"
        openPanel.allowedContentTypes = [UTType.mindFlowType]
        
        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                self.loadFile(from: url, completion: completion)
            } else {
                completion(nil, "Open operation cancelled")
            }
        }
    }
    
    func loadFile(from url: URL, completion: @escaping ([Topic]?, String?) -> Void) {
        do {
            // Read the file data
            let fileData = try Data(contentsOf: url)
            
            // Decode the topics
            let topics = try decodeTopics(from: fileData)
            
            // Update the current URL
            self._currentURL = url
            
            // Call the completion handler
            completion(topics, nil)
        } catch {
            completion(nil, "Failed to load file: \(error.localizedDescription)")
        }
    }
    
    func newFile() {
        // Clear the current URL so the next save will prompt for location
        _currentURL = nil
    }
    
    // MARK: - Data Encoding/Decoding
    
    private func encodeTopics(_ topics: [Topic]) throws -> Data {
        // Create a deep copy without relations to prevent circular references
        let topicsForEncoding = topics.map { topic -> Topic in
            var topicCopy = topic.deepCopy()
            topicCopy.relations = [] // Clear relations to prevent circular references
            return topicCopy
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let topicData = try encoder.encode(topicsForEncoding)
        return topicData
    }
    
    private func decodeTopics(from data: Data) throws -> [Topic] {
        let decoder = JSONDecoder()
        let topics = try decoder.decode([Topic].self, from: data)
        return topics
    }
}

// Extension to define the UTType for MindFlow files
extension UTType {
    static var mindFlowType: UTType {
        // Use a direct file extension approach for better compatibility
        UTType(filenameExtension: "mindflow", conformingTo: .data)!
    }
} 