import SwiftUI
import AppKit

class TopicExportViewModel: ObservableObject {
    @Published var selectedFormat: ExportFormat = .png
    @Published var exportError: String?
    @Published var isExporting: Bool = false
    
    private let exportManager: ExportManager
    
    init(exportManager: ExportManager) {
        self.exportManager = exportManager
    }
    
    func exportTopic(_ topic: Topic) {
        isExporting = true
        exportError = nil
        
        // Get the main window
        guard let mainWindow = NSApp.mainWindow else {
            exportError = "Could not access the application window"
            isExporting = false
            return
        }
        
        // Create a temporary array with just this topic
        let topics = [topic]
        
        // Call the export manager with the topic
        exportManager.exportCanvas(
            mainWindow: mainWindow,
            canvasFrame: mainWindow.contentView?.frame ?? .zero,
            topics: topics,
            scale: 1.0,
            offset: .zero,
            backgroundColor: .clear,
            backgroundStyle: .none,
            selectedTopicId: topic.id
        )
        
        isExporting = false
    }
} 