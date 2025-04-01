import SwiftUI
import AppKit

// Define ThemeSettings struct
struct ThemeSettings {
    let name: String
    let backgroundColor: Color
    let backgroundStyle: BackgroundStyle
    let topicFillColor: Color
    let topicBorderColor: Color
    let topicTextColor: Color
}

// Define BackgroundStyle enum
enum BackgroundStyle: String, CaseIterable, Identifiable {
    case none = "None"
    case grid = "Grid"
    case dots = "Dots"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .none: return "square"
        case .grid: return "grid"
        case .dots: return "circle.grid.3x3"
        }
    }
}

// Remove duplicate SidebarMode enum and use the one from InfiniteCanvas.swift
// enum SidebarMode {
//     case style
//     case map
// }

class InfiniteCanvasViewModel: ObservableObject {
    @Published var offset: CGPoint = .zero
    @Published var scale: CGFloat = 1.0
    @Published var lastDragPosition: CGPoint?
    @Published var visibleRect: CGRect = .zero
    @Published var cursorPosition: CGPoint = .zero
    @Published var topicsBounds: CGRect = .zero
    @Published var isSidebarOpen: Bool = false
    @Published var isShowingColorPicker: Bool = false
    @Published var isShowingBorderColorPicker: Bool = false
    @Published var isShowingForegroundColorPicker: Bool = false
    @Published var isShowingBackgroundColorPicker: Bool = false
    @Published var backgroundStyle: BackgroundStyle = .grid
    @Published var backgroundColor: Color = Color(.windowBackgroundColor)
    @Published var backgroundOpacity: Double = 1.0
    @Published var isRelationshipMode: Bool = false
    @Published var currentTheme: ThemeSettings?
    @Published var topicFillColor: Color = .blue
    @Published var topicBorderColor: Color = .black
    @Published var topicTextColor: Color = .white
    @Published var isEditing: Bool = false
    
    // Constants for canvas
    let minScale: CGFloat = 0.1
    let maxScale: CGFloat = 5.0
    let gridSize: CGFloat = 50
    let minimapSize: CGFloat = 200
    let minimapPadding: CGFloat = 16
    let topBarHeight: CGFloat = 40
    let sidebarWidth: CGFloat = 300
    
    private var canvasViewModel: CanvasViewModel
    private var touchBarDelegate: InfiniteCanvasTouchBarDelegate?
    
    init(canvasViewModel: CanvasViewModel) {
        self.canvasViewModel = canvasViewModel
        setupObservers()
    }
    
    private func setupObservers() {
        // Add observers for undo/redo
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UndoRequested"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.canvasViewModel.undo()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RedoRequested"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.canvasViewModel.redo()
        }
        
        // Add observer for export notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExportMindMap"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleExportRequest()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PrepareCanvasForExport"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.prepareCanvasForExport()
        }
    }
    
    // MARK: - Canvas Operations
    
    func screenToCanvasPosition(_ screenPosition: CGPoint) -> CGPoint {
        let x = (screenPosition.x - offset.x) / scale
        let y = (screenPosition.y - offset.y) / scale
        return CGPoint(x: x, y: y)
    }
    
    func centerCanvasOn(_ point: CGPoint, in geometry: GeometryProxy) {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        offset = CGPoint(
            x: centerX - (point.x * scale),
            y: centerY - (point.y * scale)
        )
    }
    
    func minimapToCanvasPosition(_ minimapPoint: CGPoint, size: CGSize) -> CGPoint {
        guard !topicsBounds.isEmpty else { return .zero }
        
        let scaleX = topicsBounds.width / size.width
        let scaleY = topicsBounds.height / size.height
        
        let canvasX = minimapPoint.x * scaleX + topicsBounds.minX
        let canvasY = minimapPoint.y * scaleY + topicsBounds.minY
        
        return CGPoint(x: canvasX, y: canvasY)
    }
    
    func calculateTopicsBounds() -> CGRect {
        guard !canvasViewModel.topics.isEmpty else { return .zero }
        
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        func updateBounds(for topic: Topic) {
            minX = min(minX, topic.position.x)
            minY = min(minY, topic.position.y)
            maxX = max(maxX, topic.position.x)
            maxY = max(maxY, topic.position.y)
            
            for subtopic in topic.subtopics {
                updateBounds(for: subtopic)
            }
        }
        
        for topic in canvasViewModel.topics {
            updateBounds(for: topic)
        }
        
        let padding: CGFloat = 100
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + (padding * 2),
            height: (maxY - minY) + (padding * 2)
        )
    }
    
    // MARK: - Theme Management
    
    func applyTheme(
        backgroundColor: Color,
        backgroundStyle: BackgroundStyle,
        topicFillColor: Color,
        topicBorderColor: Color,
        topicTextColor: Color,
        themeName: String = ""
    ) {
        self.backgroundColor = backgroundColor
        self.backgroundStyle = backgroundStyle
        
        self.currentTheme = ThemeSettings(
            name: themeName,
            backgroundColor: backgroundColor,
            backgroundStyle: backgroundStyle,
            topicFillColor: topicFillColor,
            topicBorderColor: topicBorderColor,
            topicTextColor: topicTextColor
        )
        
        for topicId in canvasViewModel.getAllTopicIds() {
            canvasViewModel.updateTopicBackgroundColor(topicId, color: topicFillColor)
            canvasViewModel.updateTopicBorderColor(topicId, color: topicBorderColor)
            canvasViewModel.updateTopicForegroundColor(topicId, color: topicTextColor)
        }
        
        canvasViewModel.setCurrentTheme(
            topicFillColor: topicFillColor,
            topicBorderColor: topicBorderColor,
            topicTextColor: topicTextColor
        )
    }
    
    func updateTheme(_ settings: ThemeSettings) {
        backgroundColor = settings.backgroundColor
        backgroundStyle = settings.backgroundStyle
        topicFillColor = settings.topicFillColor
        topicBorderColor = settings.topicBorderColor
        topicTextColor = settings.topicTextColor
    }
    
    // MARK: - Export Functionality
    
    private func handleExportRequest() {
        NotificationCenter.default.post(name: NSNotification.Name("RequestTopicsForExport"), object: nil)
    }
    
    private func prepareCanvasForExport() {
        guard let mainWindow = NSApp.mainWindow else {
            showExportError(message: "Could not access the application window")
            return
        }
        
        // Use the conversion function to convert BackgroundStyle
        let canvasBackgroundStyle = getInfiniteCanvasBackgroundStyle(backgroundStyle)
        
        ExportManager.shared.exportCanvas(
            mainWindow: mainWindow,
            canvasFrame: mainWindow.contentView?.frame ?? .zero,
            topics: canvasViewModel.topics,
            scale: scale,
            offset: offset,
            backgroundColor: backgroundColor,
            backgroundStyle: canvasBackgroundStyle,
            selectedTopicId: canvasViewModel.selectedTopicId
        )
    }
    
    private func showExportError(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // MARK: - Touch Bar Management
    
    func setupTouchBar() {
        let relationshipBinding = Binding<Bool>(
            get: { self.isRelationshipMode },
            set: { self.isRelationshipMode = $0 }
        )
        
        touchBarDelegate = InfiniteCanvasTouchBarDelegate(
            viewModel: canvasViewModel,
            isRelationshipMode: relationshipBinding
        )
    }
    
    func updateTouchBar() {
        touchBarDelegate?.updateTouchBar()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    var isEditingBinding: Binding<Bool> {
        Binding(
            get: { self.isEditing },
            set: { self.isEditing = $0 }
        )
    }
    
    func getInfiniteCanvasBackgroundStyle(_ style: BackgroundStyle) -> InfiniteCanvas.BackgroundStyle {
        switch style {
        case .none: return .none
        case .grid: return .grid
        case .dots: return .dots
        }
    }
} 