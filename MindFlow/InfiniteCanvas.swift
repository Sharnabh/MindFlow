import SwiftUI
import AppKit
import Combine
import CoreGraphics


struct InfiniteCanvas: View {
    // Use injected view model instead of creating one
    @ObservedObject var viewModel: CanvasViewModel
    
    @State private var offset: CGPoint = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastDragPosition: CGPoint?
    @State private var visibleRect: CGRect = .zero
    @State private var cursorPosition: CGPoint = .zero
    @State private var topicsBounds: CGRect = .zero // Track bounds of all topics
    @State private var isSidebarOpen: Bool = false // Track sidebar state
    @State private var isShowingColorPicker: Bool = false // Track color picker state
    @State private var isShowingBorderColorPicker: Bool = false // Track border color picker state
    @State private var isShowingForegroundColorPicker: Bool = false // Track foreground color picker state
    @State private var isShowingBackgroundColorPicker: Bool = false // Track background color picker state
    @State private var backgroundStyle: BackgroundStyle = .grid // Track background style
    @State private var backgroundColor: Color = Color(.windowBackgroundColor) // Track background color
    @State private var backgroundOpacity: Double = 1.0 // Track background opacity
    @State private var sidebarMode: SidebarMode = .style
    @State private var isRelationshipMode: Bool = false // Track relationship mode
    @State private var touchBarDelegate: InfiniteCanvasTouchBarDelegate?
    
    // Reference to the NSViewRepresentable for exporting
    @State private var canvasViewRef: FocusableCanvasView?
    
    // Access theme service for background settings
    @ObservedObject private var themeService = DependencyContainer.shared.themeService as! ThemeService
    
    // Constants for canvas
    private let minScale: CGFloat = 0.1
    private let maxScale: CGFloat = 5.0
    private let gridSize: CGFloat = 50
    private let minimapSize: CGFloat = 200 // Size of the minimap
    private let minimapPadding: CGFloat = 16 // Padding from the edges
    private let topBarHeight: CGFloat = 40 // Height of the top bar
    private let sidebarWidth: CGFloat = 300 // Width of the sidebar
    
    // Init with DI
    init(viewModel: CanvasViewModel) {
        self.viewModel = viewModel
    }
    
    // Add this method to save topics to the active document
    private func saveTopicsToActiveDocument() {
        // Get all topics from the topic service
        let allTopics = viewModel.topicService.getAllTopics()
        
        // Post notification to save topics to document
        NotificationCenter.default.post(
            name: NSNotification.Name("SaveTopicsToDocument"),
            object: nil,
            userInfo: ["topics": allTopics]
        )
    }
    
    // Convert screen coordinates to canvas coordinates
    private func screenToCanvasPosition(_ screenPosition: CGPoint) -> CGPoint {
        let x = (screenPosition.x - offset.x) / scale
        let y = (screenPosition.y - offset.y) / scale
        return CGPoint(x: x, y: y)
    }
    
    // Center the canvas on a specific point
    private func centerCanvasOn(_ point: CGPoint, in geometry: GeometryProxy) {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        // Calculate the new offset to center the point
        offset = CGPoint(
            x: centerX - (point.x * scale),
            y: centerY - (point.y * scale)
        )
    }
    
    // Convert minimap coordinates to canvas coordinates
    private func minimapToCanvasPosition(_ minimapPoint: CGPoint, size: CGSize) -> CGPoint {
        guard !topicsBounds.isEmpty else { return .zero }
        
        // Calculate the scale factors for the minimap
        let scaleX = topicsBounds.width / size.width
        let scaleY = topicsBounds.height / size.height
        
        // Convert minimap coordinates to canvas coordinates
        let canvasX = minimapPoint.x * scaleX + topicsBounds.minX
        let canvasY = minimapPoint.y * scaleY + topicsBounds.minY
        
        return CGPoint(x: canvasX, y: canvasY)
    }
    
    // Calculate bounds containing all topics
    private func calculateTopicsBounds() -> CGRect {
        guard !viewModel.topics.isEmpty else { return .zero }
        
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        func updateBounds(for topic: Topic) {
            minX = min(minX, topic.position.x)
            minY = min(minY, topic.position.y)
            maxX = max(maxX, topic.position.x)
            maxY = max(maxY, topic.position.y)
            
            // Include subtopics
            for subtopic in topic.subtopics {
                updateBounds(for: subtopic)
            }
        }
        
        // Process all topics and their subtopics
        for topic in viewModel.topics {
            updateBounds(for: topic)
        }
        
        // Add padding
        let padding: CGFloat = 100
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + (padding * 2),
            height: (maxY - minY) + (padding * 2)
        )
    }
    
    // Add these variables to the state variables at the top of InfiniteCanvas struct

    @State private var currentTheme: ThemeSettings? = nil

    // Define a ThemeSettings struct to hold theme information
    struct ThemeSettings {
        let name: String
        let backgroundColor: Color
        let backgroundStyle: BackgroundStyle
        let topicFillColor: Color
        let topicBorderColor: Color
        let topicTextColor: Color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background layer with focusable container
                ZStack {
                    // Draw background
                    Canvas { context, size in
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(backgroundColor.opacity(backgroundOpacity))
                        )
                        
                        // Calculate visible area in canvas coordinates
                        let visibleArea = CGRect(
                            x: -offset.x / scale,
                            y: -offset.y / scale,
                            width: size.width / scale,
                            height: size.height / scale
                        )
                        
                        // Calculate grid bounds with padding
                        let padding = max(size.width, size.height) / scale
                        let gridBounds = visibleArea.insetBy(dx: -padding, dy: -padding)
                        
                        // Apply canvas transformations
                        context.translateBy(x: offset.x, y: offset.y)
                        context.scaleBy(x: scale, y: scale)
                        
                        // Draw the selected background style
                        switch backgroundStyle {
                        case .none:
                            // No grid or pattern
                            break
                            
                        case .grid:
                            // Calculate grid line ranges
                            let startX = floor(gridBounds.minX / gridSize) * gridSize
                            let endX = ceil(gridBounds.maxX / gridSize) * gridSize
                            let startY = floor(gridBounds.minY / gridSize) * gridSize
                            let endY = ceil(gridBounds.maxY / gridSize) * gridSize
                            
                            // Draw vertical grid lines
                            for x in stride(from: startX, through: endX, by: gridSize) {
                                context.stroke(
                                    Path { path in
                                        path.move(to: CGPoint(x: x, y: startY))
                                        path.addLine(to: CGPoint(x: x, y: endY))
                                    },
                                    with: .color(.gray.opacity(0.2)),
                                    lineWidth: 0.5 / scale
                                )
                            }
                            
                            // Draw horizontal grid lines
                            for y in stride(from: startY, through: endY, by: gridSize) {
                                context.stroke(
                                    Path { path in
                                        path.move(to: CGPoint(x: startX, y: y))
                                        path.addLine(to: CGPoint(x: endX, y: y))
                                    },
                                    with: .color(.gray.opacity(0.2)),
                                    lineWidth: 0.5 / scale
                                )
                            }
                            
                        case .dots:
                            // Calculate dot positions
                            let dotSize: CGFloat = 2.0 / scale
                            let startX = floor(gridBounds.minX / gridSize) * gridSize
                            let endX = ceil(gridBounds.maxX / gridSize) * gridSize
                            let startY = floor(gridBounds.minY / gridSize) * gridSize
                            let endY = ceil(gridBounds.maxY / gridSize) * gridSize
                            
                            // Draw dots at grid intersections
                            for x in stride(from: startX, through: endX, by: gridSize) {
                                for y in stride(from: startY, through: endY, by: gridSize) {
                                    let dotRect = CGRect(
                                        x: x - (dotSize / 2),
                                        y: y - (dotSize / 2),
                                        width: dotSize,
                                        height: dotSize
                                    )
                                    context.fill(
                                        Path(ellipseIn: dotRect),
                                        with: .color(.gray.opacity(0.3))
                                    )
                                }
                            }
                        }
                    }
                    .background(
                        // Add a custom NSView representable that can become first responder
                        FocusableCanvasView(onViewCreated: { view in
                            // Store reference to the canvas view for focus
                            self.canvasViewRef = view
                            
                            // Set this view as first responder when created
                            DispatchQueue.main.async {
                                if let window = NSApp.keyWindow {
                                    window.makeFirstResponder(view.nsView)
                                }
                            }
                        })
                    )
                    
                    // Topics layer
                    TopicsCanvasView(viewModel: viewModel, isRelationshipMode: $isRelationshipMode)
                        .scaleEffect(scale)
                        .offset(x: offset.x, y: offset.y)
                }
                .padding(.top, topBarHeight) // Add padding for the top bar
                .onContinuousHover { phase in
                    if let window = NSApp.keyWindow {
                        let mouseLocation = NSEvent.mouseLocation
                        let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                        if let view = window.contentView {
                            let viewPoint = view.convert(windowPoint, from: nil)
                            cursorPosition = viewPoint
                        }
                    }
                }
                
                // Top bar - using the TopBarView component
                TopBarView(
                    viewModel: viewModel,
                    isSidebarOpen: $isSidebarOpen,
                    isRelationshipMode: $isRelationshipMode,
                    topBarHeight: topBarHeight
                )
                
                // Minimap overlay with conditional position
                let visibleRectX = -offset.x / scale
                let visibleRectY = -offset.y / scale
                let visibleRectWidth = geometry.size.width / scale
                let visibleRectHeight = geometry.size.height / scale
                let visibleRect = CGRect(
                    x: visibleRectX,
                    y: visibleRectY,
                    width: visibleRectWidth,
                    height: visibleRectHeight
                )
                
                MinimapView(
                    topics: viewModel.topics,
                    visibleRect: visibleRect,
                    topicsBounds: topicsBounds,
                    size: CGSize(width: minimapSize, height: minimapSize),
                    onTapLocation: { minimapPoint in
                        let canvasPoint = minimapToCanvasPosition(minimapPoint, size: CGSize(width: minimapSize, height: minimapSize))
                        centerCanvasOn(canvasPoint, in: geometry)
                    }
                )
                .frame(width: minimapSize, height: minimapSize)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor.opacity(backgroundOpacity))
                            .blur(radius: 1)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor.opacity(backgroundOpacity * 0.8))
                        
                        // Subtle inner glow
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .padding(1)
                    }
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.6), lineWidth: 2.5)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                .padding(minimapPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, topBarHeight + minimapPadding) // Add padding to position below top bar
                .padding(.trailing, isSidebarOpen ? sidebarWidth + minimapPadding : minimapPadding)
                
                // Sidebar
                if isSidebarOpen {
                    SidebarView(
                        viewModel: viewModel,
                        isSidebarOpen: $isSidebarOpen,
                        sidebarMode: $sidebarMode,
                        backgroundStyle: $backgroundStyle,
                        backgroundColor: $backgroundColor,
                        backgroundOpacity: $backgroundOpacity,
                        isShowingColorPicker: $isShowingColorPicker,
                        isShowingBorderColorPicker: $isShowingBorderColorPicker,
                        isShowingForegroundColorPicker: $isShowingForegroundColorPicker,
                        isShowingBackgroundColorPicker: $isShowingBackgroundColorPicker
                    )
                }
            }
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture().onChanged(handleZoom),
                    DragGesture(minimumDistance: 0)
                        .onChanged(handleDrag)
                        .onEnded(handleDragEnd)
                )
            )
            .onChange(of: viewModel.topics) { oldValue, newValue in
                topicsBounds = calculateTopicsBounds()
            }
            .onChange(of: viewModel.selectedTopicId) { oldValue, newValue in
                // Update the touch bar when selection changes
                touchBarDelegate?.updateTouchBar()
            }
            .onChange(of: isRelationshipMode) { oldValue, newValue in
                // Update the touch bar when relationship mode changes
                touchBarDelegate?.updateTouchBar()
            }
            .onAppear {
                setupKeyboardMonitoring()
                setupFocus()
                setupTouchBar()
                registerNotificationObservers()
            }
            .onDisappear {
                cleanupResources()
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Setup Methods
    
    private func setupKeyboardMonitoring() {
        KeyboardMonitor.shared.keyHandler = { event in
            if let window = NSApp.keyWindow {
                let mouseLocation = NSEvent.mouseLocation
                let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                if let view = window.contentView {
                    let viewPoint = view.convert(windowPoint, from: nil)
                    cursorPosition = viewPoint
                    let canvasPosition = screenToCanvasPosition(cursorPosition)
                    viewModel.handleKeyPress(event, at: canvasPosition)
                }
            }
        }
        KeyboardMonitor.shared.startMonitoring()
    }
    
    private func setupFocus() {
        // Give focus to the canvas view immediately to prevent buttons from getting initial focus
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow {
                // Set the first responder to the window's content view, not any specific button
                window.makeFirstResponder(window.contentView)
            }
        }
    }
    
    private func setupTouchBar() {
        // Initialize Touch Bar Delegate
        touchBarDelegate = InfiniteCanvasTouchBarDelegate(
            viewModel: viewModel,
            isRelationshipMode: $isRelationshipMode
        )
    }
    
    private func registerNotificationObservers() {
        // Add observer for undo/redo commands
        NotificationCenter.default.addObserver(
            forName: .undoRequested,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.undo()
        }
        
        NotificationCenter.default.addObserver(
            forName: .redoRequested,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.redo()
        }
        
        // Theme application observer
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ApplyThemeToCanvas"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let backgroundColor = userInfo["backgroundColor"] as? Color,
               let backgroundStyle = userInfo["backgroundStyle"] as? BackgroundStyle {
                self.backgroundColor = backgroundColor
                self.backgroundStyle = backgroundStyle
            }
        }
        
        // Export notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExportMindMap"),
            object: nil,
            queue: .main
        ) { _ in
            self.handleExportRequest()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PrepareCanvasForExport"),
            object: nil,
            queue: .main
        ) { _ in
            self.prepareCanvasForExport()
        }
        
        // Document operation observers
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RequestTopicsForSave"),
            object: nil,
            queue: .main
        ) { _ in
            self.saveTopicsToActiveDocument()
            NotificationCenter.default.post(name: NSNotification.Name("SaveActiveDocument"), object: nil)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RequestTopicsForSaveAs"),
            object: nil,
            queue: .main
        ) { _ in
            self.saveTopicsToActiveDocument()
            NotificationCenter.default.post(name: NSNotification.Name("SaveAsActiveDocument"), object: nil)
        }
        
        // Set up callback for topic changes to save to active document
        viewModel.topicService.onTopicsChanged = {
            self.saveTopicsToActiveDocument()
        }
        
        // Focus return observer for AI operations
        NotificationCenter.default.addObserver(
            forName: .returnFocusToCanvas,
            object: nil,
            queue: .main
        ) { _ in
            if let window = NSApp.keyWindow {
                DispatchQueue.main.async {
                    window.makeFirstResponder(window.contentView)
                }
            }
        }
    }
    
    private func cleanupResources() {
        KeyboardMonitor.shared.stopMonitoring()
        
        // Remove observers
        NotificationCenter.default.removeObserver(self, name: .undoRequested, object: nil)
        NotificationCenter.default.removeObserver(self, name: .redoRequested, object: nil)
        NotificationCenter.default.removeObserver(self, name: .returnFocusToCanvas, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ApplyThemeToCanvas"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ExportMindMap"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PrepareCanvasForExport"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RequestTopicsForSave"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RequestTopicsForSaveAs"), object: nil)
    }
    
    // MARK: - Gesture Handlers
    
    // Handle zoom gesture
    private func handleZoom(_ value: MagnificationGesture.Value) {
        // Add dampening factor to reduce zoom sensitivity
        let dampening: CGFloat = 0.5
        let zoomDelta = (value - 1) * dampening
        let newScale = scale * (1 + zoomDelta)
        scale = min(maxScale, max(minScale, newScale))
    }
    
    // Handle drag gesture
    private func handleDrag(_ value: DragGesture.Value) {
        let currentPosition = value.location
        
        if let lastPosition = lastDragPosition {
            let deltaX = currentPosition.x - lastPosition.x
            let deltaY = currentPosition.y - lastPosition.y
            
            offset = CGPoint(
                x: offset.x + deltaX,
                y: offset.y + deltaY
            )
        }
        
        lastDragPosition = currentPosition
    }
    
    // Handle drag gesture end
    private func handleDragEnd(_ value: DragGesture.Value) {
        lastDragPosition = nil
    }
    
    // MARK: - Export Functionality
    
    private func handleExportRequest() {
        // Notify that we want to export the mind map
        NotificationCenter.default.post(name: NSNotification.Name("RequestTopicsForExport"), object: nil)
    }
    
    private func prepareCanvasForExport() {
        // Instead of directly using the NSView reference which doesn't capture the canvas content,
        // we'll pass all the necessary data to render a complete representation of the mind map
        guard let mainWindow = NSApp.mainWindow else {
            showExportError(message: "Could not access the application window")
            return
        }
        
        // Pass all the necessary data to render a complete representation
        ExportManager.shared.exportCanvas(
            mainWindow: mainWindow,
            canvasFrame: mainWindow.contentView?.frame ?? .zero,
            topics: viewModel.topics,
            scale: scale,
            offset: offset,
            backgroundColor: backgroundColor,
            backgroundStyle: backgroundStyle,
            selectedTopicId: viewModel.selectedTopicId
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
}

// NSViewRepresentable to get access to the underlying NSView for export
struct CanvasViewRepresentable: NSViewRepresentable {
    var onViewCreated: (CanvasViewRepresentable) -> Void
    var nsView: NSView?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        // Create a mutable copy with the view set
        var mutableSelf = self
        mutableSelf.nsView = view
        
        // Call back with the reference to this representable
        DispatchQueue.main.async {
            onViewCreated(mutableSelf)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to update
    }
}

// Focusable canvas view that can become first responder
struct FocusableCanvasView: NSViewRepresentable {
    var onViewCreated: (FocusableCanvasView) -> Void
    var nsView: FocusableNSView?
    
    func makeNSView(context: Context) -> NSView {
        let view = FocusableNSView()
        view.wantsLayer = true
        
        // Create a mutable copy with the view set
        var mutableSelf = self
        mutableSelf.nsView = view
        
        // Call back with the reference to this representable
        DispatchQueue.main.async {
            onViewCreated(mutableSelf)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to update
    }
    
    // Custom NSView subclass that can become first responder
    class FocusableNSView: NSView {
        override var acceptsFirstResponder: Bool {
            return true
        }
        
        override func keyDown(with event: NSEvent) {
            // Just pass the event to the next responder
            super.keyDown(with: event)
        }
    }
}

// Add this after ColorPickerView struct near line 2220
// Theme button for the theme selector
struct ThemeButton: View {
    let name: String
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    var isDark: Bool = false
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(secondaryColor)
                        .frame(height: 60)
                    
                    // Sample topic
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isDark ? Color(red: 0.18, green: 0.18, blue: 0.2) : .white)
                        .frame(width: 50, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(primaryColor, lineWidth: 2)
                        )
                        .shadow(color: accentColor.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(isDark ? .white : .primary)
                    .padding(.top, 4)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Add this extension in the InfiniteCanvas struct - just before the body property
// MARK: - Theme Management
extension InfiniteCanvas {
    func applyTheme(
        backgroundColor: Color, 
        backgroundStyle: BackgroundStyle, 
        topicFillColor: Color, 
        topicBorderColor: Color,
        topicTextColor: Color,
        themeName: String = ""
    ) {
        // Update canvas background
        self.backgroundColor = backgroundColor
        self.backgroundStyle = backgroundStyle
        
        // Store theme settings for new topics
        self.currentTheme = ThemeSettings(
            name: themeName,
            backgroundColor: backgroundColor,
            backgroundStyle: backgroundStyle,
            topicFillColor: topicFillColor,
            topicBorderColor: topicBorderColor,
            topicTextColor: topicTextColor
        )
        
        // Update all topics with the theme colors
        for topicId in viewModel.getAllTopicIds() {
            // Update fill color
            viewModel.updateTopicBackgroundColor(topicId, color: topicFillColor)
            
            // Update border color
            viewModel.updateTopicBorderColor(topicId, color: topicBorderColor)
            
            // Update text color
            viewModel.updateTopicForegroundColor(topicId, color: topicTextColor)
        }
        
        // Update the theme in the ViewModel
        viewModel.setCurrentTheme(
            topicFillColor: topicFillColor,
            topicBorderColor: topicBorderColor,
            topicTextColor: topicTextColor
        )
    }
}

#Preview {
    InfiniteCanvas(viewModel: DependencyContainer.shared.makeCanvasViewModel())
} 
