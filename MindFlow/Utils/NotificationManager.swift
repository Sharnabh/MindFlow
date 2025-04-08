import SwiftUI
import AppKit

// Define notification names as an enum to avoid string literals
enum MindFlowNotification: String {
    case undoRequested = "UndoRequested"
    case redoRequested = "RedoRequested"
    case applyThemeToCanvas = "ApplyThemeToCanvas"
    case exportMindMap = "ExportMindMap"
    case prepareCanvasForExport = "PrepareCanvasForExport"
    case requestTopicsForExport = "RequestTopicsForExport"
    
    var name: NSNotification.Name {
        return NSNotification.Name(self.rawValue)
    }
}

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Register Observers
    
    func registerForUndoRedo(viewModel: CanvasViewModel) {
        NotificationCenter.default.addObserver(
            forName: MindFlowNotification.undoRequested.name,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.undo()
        }
        
        NotificationCenter.default.addObserver(
            forName: MindFlowNotification.redoRequested.name,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.redo()
        }
    }
    
    func registerForThemeApplication(handler: @escaping (Color, BackgroundStyle) -> Void) {
        NotificationCenter.default.addObserver(
            forName: MindFlowNotification.applyThemeToCanvas.name,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let backgroundColor = userInfo["backgroundColor"] as? Color,
               let backgroundStyle = userInfo["backgroundStyle"] as? BackgroundStyle {
                handler(backgroundColor, backgroundStyle)
            }
        }
    }
    
    func registerForExport(handler: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: MindFlowNotification.exportMindMap.name,
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }
    
    func registerForCanvasPreparation(handler: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: MindFlowNotification.prepareCanvasForExport.name,
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }
    
    // MARK: - Post Notifications
    
    func requestTopicsForExport() {
        NotificationCenter.default.post(name: MindFlowNotification.requestTopicsForExport.name, object: nil)
    }
    
    // MARK: - Remove Observers
    
    func removeUndoRedoObservers() {
        NotificationCenter.default.removeObserver(self, name: MindFlowNotification.undoRequested.name, object: nil)
        NotificationCenter.default.removeObserver(self, name: MindFlowNotification.redoRequested.name, object: nil)
    }
} 