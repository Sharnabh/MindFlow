import Foundation

// MARK: - App-wide Notification Names
extension Notification.Name {
    // Topic & Canvas Lifecycle
    static let topicsChanged = Notification.Name("TopicsChanged")
    static let clearCanvas = Notification.Name("ClearCanvas")
    static let returnKeyPressed = Notification.Name("ReturnKeyPressed")
    static let returnFocusToCanvas = Notification.Name("ReturnFocusToCanvas")
    static let keyDown = Notification.Name("KeyDown")
    
    // File & Document Operations
    static let newMindMap = Notification.Name("NewMindMap")
    static let openMindMap = Notification.Name("OpenMindMap")
    static let saveMindMap = Notification.Name("SaveMindMap")
    static let saveMindMapAs = Notification.Name("SaveMindMapAs")
    static let saveToiCloud = Notification.Name("SaveToiCloud")
    static let loadMindMap = Notification.Name("LoadMindMap")
    static let loadTopics = Notification.Name("LoadTopics")
    static let loadDocumentFromURL = Notification.Name("LoadDocumentFromURL")
    static let requestTopicsForSave = Notification.Name("RequestTopicsForSave")
    static let requestTopicsForSaveAs = Notification.Name("RequestTopicsForSaveAs")
    static let saveTopicsToDocument = Notification.Name("SaveTopicsToDocument")
    static let saveActiveDocument = Notification.Name("SaveActiveDocument")
    static let saveAsActiveDocument = Notification.Name("SaveAsActiveDocument")
    
    // UI Navigation & Sheets
    static let showStartupScreen = Notification.Name("ShowStartupScreen")
    static let showTemplateSelection = Notification.Name("ShowTemplateSelection")
    
    // Undo / Redo
    static let undoRequested = Notification.Name("UndoRequested")
    static let redoRequested = Notification.Name("RedoRequested")
    
    // Export Operations
    static let exportMindMap = Notification.Name("ExportMindMap")
    static let prepareCanvasForExport = Notification.Name("PrepareCanvasForExport")
    static let requestTopicsForExport = Notification.Name("RequestTopicsForExport")
    
    // Presentations
    static let presentationSlidesUpdated = Notification.Name("PresentationSlidesUpdated")
    static let presentationEnded = Notification.Name("PresentationEnded")
    
    // Collaboration
    static let openSharedDocument = Notification.Name("OpenSharedDocument")
    static let showShareAcceptance = Notification.Name("ShowShareAcceptance")
    static let closeShareAcceptance = Notification.Name("CloseShareAcceptance")
    
    // Themes & Styling
    static let applyThemeToCanvas = Notification.Name("ApplyThemeToCanvas")
    static let themeApplied = Notification.Name("ThemeApplied")
}
