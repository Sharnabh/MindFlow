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
                            with: .color(Color(nsColor: .windowBackgroundColor))
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
                        
                        // Calculate grid line ranges
                        let startX = floor(gridBounds.minX / gridSize) * gridSize
                        let endX = ceil(gridBounds.maxX / gridSize) * gridSize
                        let startY = floor(gridBounds.minY / gridSize) * gridSize
                        let endY = ceil(gridBounds.maxY / gridSize) * gridSize
                        
                        // Apply canvas transformations
                        context.translateBy(x: offset.x, y: offset.y)
                        context.scaleBy(x: scale, y: scale)
                        
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
                    }
                    
                    // Topics layer
                    TopicsCanvasView(viewModel: viewModel)
                        .scaleEffect(scale)
                        .offset(x: offset.x, y: offset.y)
                }
                .padding(.top, topBarHeight) // Add padding for the top bar
                
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
                            
                            // Sidebar toggle button container
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
                .background(Color(.windowBackgroundColor).opacity(0.9))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(minimapPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, topBarHeight + minimapPadding) // Add padding to position below top bar
                .padding(.trailing, isSidebarOpen ? sidebarWidth + minimapPadding : minimapPadding)
                
                // Sidebar
                if isSidebarOpen {
                    HStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 0) {
                            // Sidebar content
                            Rectangle()
                                .fill(Color(.windowBackgroundColor))
                                .frame(width: sidebarWidth)
                                .overlay(
                                    VStack(spacing: 0) {
                                        // Sidebar header
                                        Rectangle()
                                            .fill(Color(.windowBackgroundColor))
                                            .frame(height: topBarHeight)
                                            .overlay(
                                                Text("Style")
                                                    .foregroundColor(.primary)
                                                    .font(.headline)
                                                    .padding(.leading)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            )
                                        
                                        Divider()
                                        
                                        // Style sidebar content
                                        StyleSidebarView(style: $viewModel.topicStyle)
                                    }
                                )
                        }
                    }
                    .transition(.move(edge: .trailing))
                    .zIndex(0) // Place sidebar below top bar
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
            .onChange(of: viewModel.topics) { _ in
                topicsBounds = calculateTopicsBounds()
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
            }
            .onDisappear {
                KeyboardMonitor.shared.stopMonitoring()
            }
        }
        .ignoresSafeArea()
    }
}

// Minimap view that shows a scaled-down version of all topics
struct MinimapView: View {
    let topics: [Topic]
    let visibleRect: CGRect
    let topicsBounds: CGRect
    let size: CGSize
    let onTapLocation: (CGPoint) -> Void
    
    var body: some View {
        Canvas { context, size in
            // Draw topics as dots
            for topic in topics {
                func drawTopic(_ topic: Topic, color: Color) {
                    let position = scaleToMinimap(topic.position)
                    let dotSize: CGFloat = 6
                    
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: position.x - dotSize/2,
                            y: position.y - dotSize/2,
                            width: dotSize,
                            height: dotSize
                        )),
                        with: .color(color)
                    )
                    
                    // Draw lines to subtopics
                    for subtopic in topic.subtopics {
                        let startPoint = position
                        let endPoint = scaleToMinimap(subtopic.position)
                        
                        context.stroke(
                            Path { path in
                                path.move(to: startPoint)
                                path.addLine(to: endPoint)
                            },
                            with: .color(.blue.opacity(0.3)),
                            lineWidth: 1
                        )
                        
                        // Recursively draw subtopics
                        drawTopic(subtopic, color: .blue.opacity(0.6))
                    }
                }
                
                // Draw main topic
                drawTopic(topic, color: .blue)
            }
            
            // Draw visible area rectangle
            if !topicsBounds.isEmpty {
                let visibleRectInMinimap = CGRect(
                    x: (visibleRect.minX - topicsBounds.minX) * (size.width / topicsBounds.width),
                    y: (visibleRect.minY - topicsBounds.minY) * (size.height / topicsBounds.height),
                    width: visibleRect.width * (size.width / topicsBounds.width),
                    height: visibleRect.height * (size.height / topicsBounds.height)
                )
                
                context.stroke(
                    Path(visibleRectInMinimap),
                    with: .color(.blue.opacity(0.5)),
                    lineWidth: 1
                )
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // Handle tap at the current cursor position
                    if let window = NSApp.keyWindow,
                       let contentView = window.contentView {
                        let mouseLocation = NSEvent.mouseLocation
                        let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                        let viewPoint = contentView.convert(windowPoint, from: nil)
                        
                        // Convert the point to be relative to the minimap
                        if let minimapFrame = (contentView as? NSHostingView<MinimapView>)?.frame {
                            let relativePoint = CGPoint(
                                x: viewPoint.x - minimapFrame.minX,
                                y: viewPoint.y - minimapFrame.minY
                            )
                            onTapLocation(relativePoint)
                        }
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onTapLocation(value.location)
                }
        )
        .contentShape(Rectangle()) // Make entire minimap tappable
    }
    
    private func scaleToMinimap(_ point: CGPoint) -> CGPoint {
        guard !topicsBounds.isEmpty else { return .zero }
        
        let scaleX = size.width / topicsBounds.width
        let scaleY = size.height / topicsBounds.height
        let scale = min(scaleX, scaleY)
        
        return CGPoint(
            x: (point.x - topicsBounds.minX) * scale,
            y: (point.y - topicsBounds.minY) * scale
        )
    }
}

#Preview {
    InfiniteCanvas()
} 
