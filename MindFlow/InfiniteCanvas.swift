import SwiftUI
import AppKit


struct InfiniteCanvas: View {
    @StateObject private var viewModel = CanvasViewModel()
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
    @State private var canvasViewRef: CanvasViewRepresentable?
    
    // Constants for canvas
    private let minScale: CGFloat = 0.1
    private let maxScale: CGFloat = 5.0
    private let gridSize: CGFloat = 50
    private let minimapSize: CGFloat = 200 // Size of the minimap
    private let minimapPadding: CGFloat = 16 // Padding from the edges
    private let topBarHeight: CGFloat = 40 // Height of the top bar
    private let sidebarWidth: CGFloat = 300 // Width of the sidebar
    
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
                // Background layer with grid and topics
                ZStack {
                    // Background layer
                    Canvas { context, size in
                        // Draw background
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
                    
                    // Topics layer
                    TopicsCanvasView(viewModel: viewModel, isRelationshipMode: $isRelationshipMode)
                        .scaleEffect(scale)
                        .offset(x: offset.x, y: offset.y)
                }
                .padding(.top, topBarHeight) // Add padding for the top bar
                .background(
                    // Add a representable that gives us access to the underlying NSView
                    CanvasViewRepresentable(onViewCreated: { view in
                        self.canvasViewRef = view
                    })
                )
                
                // Top bar
                Rectangle()
                    .fill(Color(.windowBackgroundColor))
                    .frame(height: topBarHeight)
                    .overlay(
                        HStack(spacing: 0) {
                            Text("MindFlow")
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            Spacer()
                            
                            // Group all central buttons together in the middle
                            HStack(spacing: 12) {
                                // Auto layout button
                                Button(action: {
                                    viewModel.performAutoLayout()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "rectangle.grid.1x2")
                                            .font(.system(size: 14))
                                        Text("Auto Layout")
                                            .font(.system(size: 13))
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Automatically arrange topics with perfect spacing")
                                
                                // Collapse button - enabled when a topic with children is selected
                                Button(action: {
                                    if let selectedId = viewModel.selectedTopicId {
                                        viewModel.toggleCollapseState(topicId: selectedId)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        let isCollapsed = viewModel.selectedTopicId.flatMap(viewModel.isTopicCollapsed) ?? false
                                        let totalDescendants = viewModel.selectedTopicId.flatMap { id in 
                                            if let topic = viewModel.getTopicById(id) {
                                                return viewModel.countAllDescendants(for: topic)
                                            }
                                            return 0
                                        } ?? 0
                                        
                                        Image(systemName: isCollapsed ? "chevron.down.circle" : "chevron.right.circle")
                                            .foregroundColor(totalDescendants > 0 ? .primary : .gray)
                                            .font(.system(size: 14))
                                        
                                        Text(isCollapsed ? "Expand" : "Collapse")
                                            .font(.system(size: 13))
                                            .foregroundColor(totalDescendants > 0 ? .primary : .gray)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(viewModel.selectedTopicId == nil || 
                                         (viewModel.selectedTopicId.flatMap { id in 
                                             viewModel.getTopicById(id)
                                         }.flatMap { topic in 
                                             viewModel.countAllDescendants(for: topic)
                                         } ?? 0) == 0)
                                .help("Collapse or expand the selected topic")
                                
                                // Relationship button
                                Button(action: {
                                    isRelationshipMode.toggle()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.triangle.branch")
                                            .foregroundColor(isRelationshipMode ? .blue : .primary)
                                            .font(.system(size: 14))
                                        
                                        Text("Relationship")
                                            .font(.system(size: 13))
                                            .foregroundColor(isRelationshipMode ? .blue : .primary)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isRelationshipMode ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Create relationships between topics")
                            }
                            
                            Spacer()
                            
                            // Sidebar toggle button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isSidebarOpen.toggle()
                                }
                            }) {
                                Image(systemName: isSidebarOpen ? "sidebar.right" : "sidebar.right")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 14, weight: .regular))
                                    .frame(width: 28, height: topBarHeight)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color(.windowBackgroundColor))
                            .focusable(false) // Prevent the button from receiving focus
                        }
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    .zIndex(1) // Ensure top bar stays above other content
                
                // Minimap overlay with conditional position
                MinimapView(
                    topics: viewModel.topics,
                    visibleRect: CGRect(
                        x: -offset.x / scale,
                        y: -offset.y / scale,
                        width: geometry.size.width / scale,
                        height: geometry.size.height / scale
                    ),
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
                    MagnificationGesture()
                        .onChanged { value in
                            // Add dampening factor to reduce zoom sensitivity
                            let dampening: CGFloat = 0.5
                            let zoomDelta = (value - 1) * dampening
                            let newScale = scale * (1 + zoomDelta)
                            scale = min(maxScale, max(minScale, newScale))
                        },
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let currentPosition = value.location
                            
                            if let lastPosition = lastDragPosition {
                                let delta = CGPoint(
                                    x: currentPosition.x - lastPosition.x,
                                    y: currentPosition.y - lastPosition.y
                                )
                                offset = CGPoint(
                                    x: offset.x + delta.x,
                                    y: offset.y + delta.y
                                )
                            }
                            
                            lastDragPosition = currentPosition
                        }
                        .onEnded { _ in
                            lastDragPosition = nil
                        }
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
                
                // Initialize Touch Bar Delegate
                touchBarDelegate = InfiniteCanvasTouchBarDelegate(viewModel: viewModel, isRelationshipMode: $isRelationshipMode)
                
                // Add observer for undo command (Cmd+Z)
                NotificationCenter.default.addObserver(forName: NSNotification.Name("UndoRequested"), object: nil, queue: .main) { _ in
                    viewModel.undo()
                }
                
                // Add observer for redo command (Cmd+Shift+Z)
                NotificationCenter.default.addObserver(forName: NSNotification.Name("RedoRequested"), object: nil, queue: .main) { _ in
                    viewModel.redo()
                }
                
                // Add observer for theme application
                NotificationCenter.default.addObserver(forName: NSNotification.Name("ApplyThemeToCanvas"), object: nil, queue: .main) { notification in
                    if let userInfo = notification.userInfo,
                       let backgroundColor = userInfo["backgroundColor"] as? Color,
                       let backgroundStyle = userInfo["backgroundStyle"] as? BackgroundStyle {
                        self.backgroundColor = backgroundColor
                        self.backgroundStyle = backgroundStyle
                    }
                }
                
                // Set up touch bar delegate
                touchBarDelegate = InfiniteCanvasTouchBarDelegate(
                    viewModel: viewModel,
                    isRelationshipMode: $isRelationshipMode
                )
                
                // Register for export notification
                NotificationCenter.default.addObserver(forName: NSNotification.Name("ExportMindMap"), object: nil, queue: .main) { _ in
                    self.handleExportRequest()
                }
                
                NotificationCenter.default.addObserver(forName: NSNotification.Name("PrepareCanvasForExport"), object: nil, queue: .main) { _ in
                    self.prepareCanvasForExport()
                }
                
                // Add observer for returning focus to canvas after AI operations
                NotificationCenter.default.addObserver(forName: NSNotification.Name("ReturnFocusToCanvas"), object: nil, queue: .main) { _ in
                    // Make the canvas the first responder to capture keyboard events
                    if let window = NSApp.keyWindow {
                        DispatchQueue.main.async {
                            window.makeFirstResponder(window.contentView)
                        }
                    }
                }
            }
            .onDisappear {
                KeyboardMonitor.shared.stopMonitoring()
                
                // Remove observers
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UndoRequested"), object: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RedoRequested"), object: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ReturnFocusToCanvas"), object: nil)
            }
        }
        .ignoresSafeArea()
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
    InfiniteCanvas()
} 
