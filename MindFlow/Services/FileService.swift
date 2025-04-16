import Foundation
import SwiftUI
import AppKit

// Protocol defining file operations
protocol FileServiceProtocol {
    // File operations
    func saveCurrentFile(topics: [Topic], completion: @escaping (Bool, String?) -> Void)
    func saveFileAs(topics: [Topic], completion: @escaping (Bool, String?) -> Void)
    func loadFile(completion: @escaping ([Topic]?, String?) -> Void)
    
    // Export operations
    func exportAsPNG(topics: [Topic], scale: CGFloat, offset: CGPoint, backgroundColor: Color, backgroundStyle: BackgroundStyle, selectedTopicId: UUID?)
    func exportAsPDF(topics: [Topic], scale: CGFloat, offset: CGPoint, backgroundColor: Color, backgroundStyle: BackgroundStyle, selectedTopicId: UUID?)
    
    // Current file state
    var currentFileName: String? { get }
    var currentFileURL: URL? { get }
    var hasUnsavedChanges: Bool { get set }
}

// Main implementation of the FileService
class FileService: FileServiceProtocol, ObservableObject {
    // Current file information
    @Published private(set) var currentFileURL: URL? = nil
    @Published private(set) var currentFileName: String? = nil
    @Published var hasUnsavedChanges: Bool = false
    
    // File type information
    private let fileExtension = "mindflow"
    private let fileType = "MindFlow Document"
    
    // MARK: - File Operations
    
    func saveCurrentFile(topics: [Topic], completion: @escaping (Bool, String?) -> Void) {
        // If we have a current file, save to it
        if let fileURL = currentFileURL {
            saveFile(topics: topics, to: fileURL, completion: completion)
        } else {
            // Otherwise, prompt for a location
            saveFileAs(topics: topics, completion: completion)
        }
    }
    
    func saveFileAs(topics: [Topic], completion: @escaping (Bool, String?) -> Void) {
        // Configure save panel
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = currentFileName ?? "Untitled"
        savePanel.title = "Save Mind Map"
        savePanel.allowedFileTypes = [fileExtension]
        savePanel.message = "Choose a location to save your mind map"
        
        // Show save panel
        savePanel.beginSheetModal(for: NSApp.mainWindow!) { result in
            if result == .OK, let url = savePanel.url {
                self.saveFile(topics: topics, to: url) { success, error in
                    if success {
                        // Update current file information
                        DispatchQueue.main.async {
                            self.currentFileURL = url
                            self.currentFileName = url.lastPathComponent
                            self.hasUnsavedChanges = false
                        }
                    }
                    completion(success, error)
                }
            } else {
                completion(false, "Save canceled")
            }
        }
    }
    
    func loadFile(completion: @escaping ([Topic]?, String?) -> Void) {
        // Configure open panel
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Open Mind Map"
        openPanel.allowedFileTypes = [fileExtension]
        openPanel.message = "Choose a mind map file to open"
        
        // Show open panel
        openPanel.beginSheetModal(for: NSApp.mainWindow!) { result in
            if result == .OK, let url = openPanel.url {
                self.loadFile(from: url) { topics, error in
                    if let topics = topics {
                        // Update current file information
                        DispatchQueue.main.async {
                            self.currentFileURL = url
                            self.currentFileName = url.lastPathComponent
                            self.hasUnsavedChanges = false
                        }
                    }
                    completion(topics, error)
                }
            } else {
                completion(nil, "Open canceled")
            }
        }
    }
    
    // MARK: - Export Operations
    
    func exportAsPNG(topics: [Topic], scale: CGFloat, offset: CGPoint, backgroundColor: Color, backgroundStyle: BackgroundStyle, selectedTopicId: UUID?) {
        // Configure export panel
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = (currentFileName ?? "MindMap").replacingOccurrences(of: ".\(fileExtension)", with: "")
        savePanel.title = "Export Mind Map as PNG"
        savePanel.allowedFileTypes = ["png"]
        savePanel.message = "Choose a location to export your mind map"
        
        // Show save panel
        savePanel.beginSheetModal(for: NSApp.mainWindow!) { result in
            if result == .OK, let url = savePanel.url {
                self.renderAndExport(as: .png, to: url, topics: topics, scale: scale, offset: offset, backgroundColor: backgroundColor, backgroundStyle: backgroundStyle, selectedTopicId: selectedTopicId)
            }
        }
    }
    
    func exportAsPDF(topics: [Topic], scale: CGFloat, offset: CGPoint, backgroundColor: Color, backgroundStyle: BackgroundStyle, selectedTopicId: UUID?) {
        // Configure export panel
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = (currentFileName ?? "MindMap").replacingOccurrences(of: ".\(fileExtension)", with: "")
        savePanel.title = "Export Mind Map as PDF"
        savePanel.allowedFileTypes = ["pdf"]
        savePanel.message = "Choose a location to export your mind map"
        
        // Show save panel
        savePanel.beginSheetModal(for: NSApp.mainWindow!) { result in
            if result == .OK, let url = savePanel.url {
                self.renderAndExport(as: .pdf, to: url, topics: topics, scale: scale, offset: offset, backgroundColor: backgroundColor, backgroundStyle: backgroundStyle, selectedTopicId: selectedTopicId)
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func saveFile(topics: [Topic], to url: URL, completion: @escaping (Bool, String?) -> Void) {
        do {
            // Create a serializable copy of the topics
            let serializableTopics = topics.map { $0.deepCopy() }
            
            // Encode topics
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(serializableTopics)
            
            // Write to file
            try data.write(to: url)
            
            // Update state
            DispatchQueue.main.async {
                self.hasUnsavedChanges = false
            }
            
            completion(true, nil)
        } catch {
            completion(false, "Failed to save file: \(error.localizedDescription)")
        }
    }
    
    private func loadFile(from url: URL, completion: @escaping ([Topic]?, String?) -> Void) {
        do {
            // Read file data
            let data = try Data(contentsOf: url)
            
            // Decode topics
            let decoder = JSONDecoder()
            let topics = try decoder.decode([Topic].self, from: data)
            
            completion(topics, nil)
        } catch {
            completion(nil, "Failed to load file: \(error.localizedDescription)")
        }
    }
    
    private enum ExportFormat {
        case png
        case pdf
    }
    
    private func renderAndExport(as format: ExportFormat, to url: URL, topics: [Topic], scale: CGFloat, offset: CGPoint, backgroundColor: Color, backgroundStyle: BackgroundStyle, selectedTopicId: UUID?) {
        // This is a simplified implementation - in a real app, you would render the mind map to an image
        // For now, we'll create a placeholder image
        
        // Calculate the bounds of the mind map
        var bounds = CGRect.zero
        for topic in topics {
            let topicBounds = calculateTopicBounds(topic)
            if bounds.isEmpty {
                bounds = topicBounds
            } else {
                bounds = bounds.union(topicBounds)
            }
        }
        
        // Add padding
        bounds = bounds.insetBy(dx: -100, dy: -100)
        
        // Create a bitmap context
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        
        if format == .png {
            // Create a bitmap image representation
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            
            // Create an NSImage and add the representation
            let image = NSImage(size: NSSize(width: width, height: height))
            image.addRepresentation(rep)
            
            // Lock focus on the image for drawing
            image.lockFocus()
            
            // Draw the background
            NSColor.white.set()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            
            // TODO: Draw the actual mind map here
            
            // Unlock focus
            image.unlockFocus()
            
            // Save the image data
            if let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                do {
                    try pngData.write(to: url)
                } catch {
                    print("Error saving PNG: \(error.localizedDescription)")
                }
            }
        } else if format == .pdf {
            // Create a PDF context
            let pdfData = NSMutableData()
            let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: nil, nil)!
            
            // Begin PDF page
            pdfContext.beginPDFPage(nil)
            
            // Set up the coordinate system
            pdfContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            
            // TODO: Draw the actual mind map here
            
            // End PDF page and document
            pdfContext.endPDFPage()
            pdfContext.closePDF()
            
            // Save the PDF data
            do {
                try pdfData.write(to: url, options: .atomic)
            } catch {
                print("Error saving PDF: \(error.localizedDescription)")
            }
        }
    }
    
    private func calculateTopicBounds(_ topic: Topic) -> CGRect {
        // Calculate bounds for this topic
        let topicSize = CGSize(width: 150, height: 60) // Simplified
        let topicRect = CGRect(
            x: topic.position.x - topicSize.width / 2,
            y: topic.position.y - topicSize.height / 2,
            width: topicSize.width,
            height: topicSize.height
        )
        
        // Start with this topic's bounds
        var bounds = topicRect
        
        // Include all subtopics
        for subtopic in topic.subtopics {
            let subtopicBounds = calculateTopicBounds(subtopic)
            bounds = bounds.union(subtopicBounds)
        }
        
        return bounds
    }
} 