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
                                    VStack(spacing: 16) {
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
                                        
                                        // Shape selector
                                        if let selectedTopic = viewModel.getSelectedTopic() {
                                            ShapeSelector(
                                                selectedShape: selectedTopic.shape,
                                                onShapeSelected: { shape in
                                                    viewModel.updateTopicShape(selectedTopic.id, shape: shape)
                                                }
                                            )
                                            
                                            // Fill control
                                            HStack(spacing: 8) {
                                                Text("Fill")
                                                    .foregroundColor(.primary)
                                                    .font(.system(size: 13))
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    isShowingColorPicker.toggle()
                                                }) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(selectedTopic.backgroundColor)
                                                        .frame(width: 50, height: 28)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 2)
                                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .popover(isPresented: $isShowingColorPicker, arrowEdge: .bottom) {
                                                    ColorPickerView(
                                                        selectedColor: Binding(
                                                            get: { selectedTopic.backgroundColor },
                                                            set: { newColor in
                                                                viewModel.updateTopicBackgroundColor(selectedTopic.id, color: newColor)
                                                            }
                                                        ),
                                                        opacity: Binding(
                                                            get: { selectedTopic.backgroundOpacity },
                                                            set: { newOpacity in
                                                                viewModel.updateTopicBackgroundOpacity(selectedTopic.id, opacity: newOpacity)
                                                            }
                                                        )
                                                    )
                                                }
                                            }
                                                        .padding(.horizontal)
                                            
                                            // Border control
                                            HStack(spacing: 8) {
                                                Text("Border")
                                                    .foregroundColor(.primary)
                                                    .font(.system(size: 13))
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    isShowingBorderColorPicker.toggle()
                                                }) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(selectedTopic.borderColor)
                                                        .frame(width: 50, height: 28)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 2)
                                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .popover(isPresented: $isShowingBorderColorPicker, arrowEdge: .bottom) {
                                                    ColorPickerView(
                                                        selectedColor: Binding(
                                                            get: { selectedTopic.borderColor },
                                                            set: { newColor in
                                                                viewModel.updateTopicBorderColor(selectedTopic.id, color: newColor)
                                                            }
                                                        ),
                                                        opacity: Binding(
                                                            get: { selectedTopic.borderOpacity },
                                                            set: { newOpacity in
                                                                viewModel.updateTopicBorderOpacity(selectedTopic.id, opacity: newOpacity)
                                                            }
                                                        )
                                                    )
                                                }
                                            }
                                            .padding(.horizontal)
                                            
                                            // Border width control
                                            HStack(spacing: 8) {
                                                Text("Border Width")
                                                    .foregroundColor(.primary)
                                                    .font(.system(size: 13))
                                                
                                                Spacer()
                                                
                                                Menu {
                                                    ForEach(Topic.BorderWidth.allCases, id: \.self) { width in
                                                        Button(action: {
                                                            viewModel.updateTopicBorderWidth(selectedTopic.id, width: width)
                                                        }) {
                                                            HStack {
                                                                if selectedTopic.borderWidth == width {
                                                                    Image(systemName: "checkmark")
                                                                        .frame(width: 16, alignment: .center)
                                                                } else {
                                                                    Color.clear
                                                                        .frame(width: 16)
                                                                }
                                                                Text(width.displayName)
                                                                Spacer()
                                                            }
                                                            .contentShape(Rectangle())
                                                        }
                                                    }
                                                } label: {
                                                    HStack {
                                                        Text(selectedTopic.borderWidth.displayName)
                                                            .foregroundColor(.white)
                                                    }
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 6)
                                                    .frame(width: 100)
                                                    .background(Color.black.opacity(0.6))
                                                    .cornerRadius(6)
                                                }
                                            }
                                            .padding(.horizontal)
                                        } else {
                                            Text("Select a topic to edit its properties")
                                                .foregroundColor(.secondary)
                                                .padding()
                                        }
                                        
                                        Spacer()
                                    }
                                )
                        }
                    }
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

// Custom shape views
private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct RegularPolygon: Shape {
    let sides: Int
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        
        for i in 0..<sides {
            let angle = (2.0 * .pi * Double(i)) / Double(sides) - (.pi / 2)
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct Parallelogram: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let offset: CGFloat = rect.width * 0.2
        path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Cloud: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let centerY = height * 0.5
        
        path.move(to: CGPoint(x: width * 0.2, y: centerY))
        path.addCurve(
            to: CGPoint(x: width * 0.8, y: centerY),
            control1: CGPoint(x: width * 0.2, y: height * 0.2),
            control2: CGPoint(x: width * 0.8, y: height * 0.2)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.2, y: centerY),
            control1: CGPoint(x: width * 0.8, y: height * 0.8),
            control2: CGPoint(x: width * 0.2, y: height * 0.8)
        )
        path.closeSubpath()
        return path
    }
}

private struct Heart: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width * 0.5, y: height * 0.75))
        path.addCurve(
            to: CGPoint(x: width * 0.1, y: height * 0.35),
            control1: CGPoint(x: width * 0.5, y: height * 0.7),
            control2: CGPoint(x: width * 0.1, y: height * 0.5)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.25),
            control1: CGPoint(x: width * 0.1, y: height * 0.2),
            control2: CGPoint(x: width * 0.5, y: height * 0.25)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.9, y: height * 0.35),
            control1: CGPoint(x: width * 0.5, y: height * 0.25),
            control2: CGPoint(x: width * 0.9, y: height * 0.2)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.75),
            control1: CGPoint(x: width * 0.9, y: height * 0.5),
            control2: CGPoint(x: width * 0.5, y: height * 0.7)
        )
        path.closeSubpath()
        return path
    }
}

private struct Shield: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width * 0.5, y: height))
        path.addCurve(
            to: CGPoint(x: 0, y: height * 0.4),
            control1: CGPoint(x: width * 0.2, y: height * 0.9),
            control2: CGPoint(x: 0, y: height * 0.7)
        )
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: height * 0.4))
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: width, y: height * 0.7),
            control2: CGPoint(x: width * 0.8, y: height * 0.9)
        )
        path.closeSubpath()
        return path
    }
}

private struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.4
        let points = 5
        var path = Path()
        
        for i in 0..<points * 2 {
            let angle = (2.0 * .pi * Double(i)) / Double(points * 2) - (.pi / 2)
            let r = i % 2 == 0 ? radius : innerRadius
            let point = CGPoint(
                x: center.x + r * cos(angle),
                y: center.y + r * sin(angle)
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct Document: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let cornerRadius: CGFloat = 8
        let foldSize: CGFloat = min(width, height) * 0.2
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(
            center: CGPoint(x: cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: width - foldSize, y: 0))
        path.addLine(to: CGPoint(x: width, y: foldSize))
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        
        // Add fold line
        path.move(to: CGPoint(x: width - foldSize, y: 0))
        path.addLine(to: CGPoint(x: width - foldSize, y: foldSize))
        path.addLine(to: CGPoint(x: width, y: foldSize))
        
        return path
    }
}

private struct DoubleRectangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let offset: CGFloat = 4
        
        // Back rectangle
        path.addRect(CGRect(
            x: offset,
            y: offset,
            width: rect.width - offset,
            height: rect.height - offset
        ))
        
        // Front rectangle
        path.addRect(CGRect(
            x: 0,
            y: 0,
            width: rect.width - offset,
            height: rect.height - offset
        ))
        
        return path
    }
}

private struct Flag: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let poleWidth: CGFloat = width * 0.1
        
        // Pole
        path.addRect(CGRect(
            x: 0,
            y: 0,
            width: poleWidth,
            height: height
        ))
        
        // Flag part
        path.move(to: CGPoint(x: poleWidth, y: height * 0.2))
        path.addLine(to: CGPoint(x: width, y: height * 0.2))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.5))
        path.addLine(to: CGPoint(x: width, y: height * 0.8))
        path.addLine(to: CGPoint(x: poleWidth, y: height * 0.8))
        path.closeSubpath()
        
        return path
    }
}

private struct Arrow: Shape {
    enum Direction {
        case left
        case right
    }
    
    let pointing: Direction
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let arrowWidth = width * 0.3
        
        switch pointing {
        case .left:
            path.move(to: CGPoint(x: 0, y: height * 0.5))
            path.addLine(to: CGPoint(x: arrowWidth, y: 0))
            path.addLine(to: CGPoint(x: arrowWidth, y: height * 0.3))
            path.addLine(to: CGPoint(x: width, y: height * 0.3))
            path.addLine(to: CGPoint(x: width, y: height * 0.7))
            path.addLine(to: CGPoint(x: arrowWidth, y: height * 0.7))
            path.addLine(to: CGPoint(x: arrowWidth, y: height))
            path.closeSubpath()
        case .right:
            path.move(to: CGPoint(x: width, y: height * 0.5))
            path.addLine(to: CGPoint(x: width - arrowWidth, y: 0))
            path.addLine(to: CGPoint(x: width - arrowWidth, y: height * 0.3))
            path.addLine(to: CGPoint(x: 0, y: height * 0.3))
            path.addLine(to: CGPoint(x: 0, y: height * 0.7))
            path.addLine(to: CGPoint(x: width - arrowWidth, y: height * 0.7))
            path.addLine(to: CGPoint(x: width - arrowWidth, y: height))
            path.closeSubpath()
        }
        
        return path
    }
}

// Shape selector view
struct ShapeSelector: View {
    let selectedShape: Topic.Shape
    let onShapeSelected: (Topic.Shape) -> Void
    @State private var isShowingPopover = false
    
    private let shapes: [(Topic.Shape, String)] = [
        (.rectangle, "Rectangle"),
        (.roundedRectangle, "Rounded Rectangle"),
        (.circle, "Circle"),
        (.roundedSquare, "Rounded Square"),
        (.line, "Line"),
        (.diamond, "Diamond"),
        (.hexagon, "Hexagon"),
        (.octagon, "Octagon"),
        (.parallelogram, "Parallelogram"),
        (.cloud, "Cloud"),
        (.heart, "Heart"),
        (.shield, "Shield"),
        (.star, "Star"),
        (.document, "Document"),
        (.doubleRectangle, "Double Rectangle"),
        (.flag, "Flag"),
        (.leftArrow, "Left Arrow"),
        (.rightArrow, "Right Arrow")
    ]
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    var body: some View {
        HStack(spacing: 8) {
            Text("Shape")
                .foregroundColor(.primary)
                .font(.system(size: 13))
            
            Spacer()
            
            Button(action: {
                isShowingPopover.toggle()
            }) {
                HStack(spacing: 4) {
                    ShapePreview(shape: selectedShape)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: 50)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                VStack {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(shapes, id: \.0) { shape, name in
                            Button(action: {
                                onShapeSelected(shape)
                                isShowingPopover = false
                            }) {
                                ShapePreview(shape: shape)
                                    .frame(width: 32, height: 32)
                                    .background(shape == selectedShape ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(name)
                        }
                    }
                    .padding(8)
                }
                .frame(width: 180)
                .background(Color(.windowBackgroundColor))
            }
        }
        .padding(.horizontal)
    }
}

// Shape preview for the menu
struct ShapePreview: View {
    let shape: Topic.Shape
    
    var body: some View {
        Group {
            switch shape {
            case .rectangle:
                RoundedRectangle(cornerRadius: 2)
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 4)
            case .circle:
                Circle()
            case .roundedSquare:
                RoundedRectangle(cornerRadius: 6)
            case .line:
                Rectangle().frame(height: 2)
            case .diamond:
                Diamond()
            case .hexagon:
                RegularPolygon(sides: 6)
            case .octagon:
                RegularPolygon(sides: 8)
            case .parallelogram:
                Parallelogram()
            case .cloud:
                Cloud()
            case .heart:
                Heart()
            case .shield:
                Shield()
            case .star:
                Star()
            case .document:
                Document()
            case .doubleRectangle:
                DoubleRectangle()
            case .flag:
                Flag()
            case .leftArrow:
                Arrow(pointing: .left)
            case .rightArrow:
                Arrow(pointing: .right)
            }
        }
    }
}

private struct TopicContent: View {
    var topic: Topic
    let isSelected: Bool
    @Binding var editingName: String
    @FocusState var isFocused: Bool
    let onNameChange: (String) -> Void
    let onEditingChange: (Bool) -> Void
    
    private func calculateWidth() -> CGFloat {
        let text = topic.isEditing ? editingName : topic.name
        return max(120, CGFloat(text.count * 10))
    }
    
    var body: some View {
        Group {
            if topic.isEditing {
                createTextField()
            } else {
                createTextDisplay()
            }
        }
    }
    
    private func createTextField() -> some View {
        let width = calculateWidth()
        return TextField("", text: $editingName)
            .textFieldStyle(.plain)
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: width, maxWidth: width)
            .background(
                createBackground()
                    .frame(width: width + 32, height: 40) // Add padding to shape
            )
            .overlay(
                createBorder()
                    .frame(width: width + 32, height: 40) // Match shape size
            )
            .focused($isFocused)
            .onChange(of: editingName) { newValue in
                onNameChange(newValue)
            }
            .onSubmit {
                onNameChange(editingName)
                isFocused = false
                onEditingChange(false)
            }
            .onExitCommand {
                isFocused = false
                onEditingChange(false)
            }
            .multilineTextAlignment(.center)
            .onKeyPress(.tab) {
                isFocused = true
                return .handled
            }
            .submitLabel(.return)
    }
    
    private func createTextDisplay() -> some View {
        let width = calculateWidth()
        return Text(topic.name)
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(width: width)
            .background(
                createBackground()
                    .frame(width: width + 32, height: 40) // Add padding to shape
            )
            .overlay(
                createBorder()
                    .frame(width: width + 32, height: 40) // Match shape size
            )
    }
    
    private func createBackground() -> some View {
        Group {
            switch topic.shape {
            case .rectangle:
                Rectangle()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 8)
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .circle:
                Capsule()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .roundedSquare:
                RoundedRectangle(cornerRadius: 12)
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .line:
                Rectangle()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
                    .frame(height: 2)
            case .diamond:
                Diamond()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .hexagon:
                RegularPolygon(sides: 6)
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .octagon:
                RegularPolygon(sides: 8)
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .parallelogram:
                Parallelogram()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .cloud:
                Cloud()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .heart:
                Heart()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .shield:
                Shield()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .star:
                Star()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .document:
                Document()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .doubleRectangle:
                DoubleRectangle()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .flag:
                Flag()
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .leftArrow:
                Arrow(pointing: .left)
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            case .rightArrow:
                Arrow(pointing: .right)
                    .fill(topic.backgroundColor.opacity(topic.backgroundOpacity))
            }
        }
    }
    
    private func createBorder() -> some View {
        Group {
            switch topic.shape {
            case .rectangle:
                Rectangle()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .circle:
                Capsule()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .roundedSquare:
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .line:
                Rectangle()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .frame(height: 2)
            case .diamond:
                Diamond()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .hexagon:
                RegularPolygon(sides: 6)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .octagon:
                RegularPolygon(sides: 8)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .parallelogram:
                Parallelogram()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .cloud:
                Cloud()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .heart:
                Heart()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .shield:
                Shield()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .star:
                Star()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .document:
                Document()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .doubleRectangle:
                DoubleRectangle()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .flag:
                Flag()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .leftArrow:
                Arrow(pointing: .left)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            case .rightArrow:
                Arrow(pointing: .right)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
            }
        }
    }
}

// Add this struct before the ShapeSelector
struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Binding var opacity: Double
    @State private var hexValue: String = ""
    @State private var showColorPicker = false
    
    let colors: [[Color]] = [
        [.white, .gray.opacity(0.2), .gray.opacity(0.4), .gray.opacity(0.6), .gray.opacity(0.8), .gray, .black],
        [Color(red: 1.0, green: 0.85, blue: 0), Color(red: 1.0, green: 0.63, blue: 0.48), Color(red: 0.6, green: 0.98, blue: 0.6), Color(red: 0.25, green: 0.88, blue: 0.82), Color(red: 0.53, green: 0.81, blue: 0.92), Color(red: 0.39, green: 0.58, blue: 0.93), Color(red: 0.87, green: 0.63, blue: 0.87), Color(red: 1.0, green: 0.41, blue: 0.71), Color(red: 1.0, green: 0.75, blue: 0.8)],
        [Color(red: 1.0, green: 0.72, blue: 0), Color(red: 1.0, green: 0.55, blue: 0.35), Color(red: 0.47, green: 0.98, blue: 0.47), Color(red: 0.13, green: 0.88, blue: 0.82), Color(red: 0.4, green: 0.81, blue: 0.92), Color(red: 0.27, green: 0.46, blue: 0.93), Color(red: 0.74, green: 0.5, blue: 0.87), Color(red: 1.0, green: 0.29, blue: 0.71), Color(red: 1.0, green: 0.63, blue: 0.67)],
        [Color(red: 1.0, green: 0.59, blue: 0), Color(red: 1.0, green: 0.42, blue: 0.23), Color(red: 0.35, green: 0.98, blue: 0.35), Color(red: 0, green: 0.88, blue: 0.82), Color(red: 0.28, green: 0.81, blue: 0.92), Color(red: 0.14, green: 0.34, blue: 0.93), Color(red: 0.62, green: 0.38, blue: 0.87), Color(red: 1.0, green: 0.16, blue: 0.71), Color(red: 1.0, green: 0.5, blue: 0.55)],
        [Color(red: 1.0, green: 0.47, blue: 0), Color(red: 1.0, green: 0.3, blue: 0.1), Color(red: 0.22, green: 0.98, blue: 0.22), Color(red: 0, green: 0.75, blue: 0.69), Color(red: 0.15, green: 0.81, blue: 0.92), Color(red: 0.02, green: 0.21, blue: 0.93), Color(red: 0.49, green: 0.25, blue: 0.87), Color(red: 1.0, green: 0.04, blue: 0.71), Color(red: 1.0, green: 0.38, blue: 0.42)]
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Color grid
            VStack(spacing: 4) {
                ForEach(colors, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                                hexValue = color.toHex() ?? ""
                            }) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(8)
            
            Divider()
            
            // Color wheel and hex input
            HStack {
                Text("#")
                    .foregroundColor(.secondary)
                TextField("", text: $hexValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 60)
                    .onChange(of: hexValue) { newValue in
                        if let color = Color(hex: newValue) {
                            selectedColor = color
                        }
                    }
                
                Spacer()
                
                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 8)
            
            Divider()
            
            // Opacity slider
            HStack {
                Text("\(Int(opacity * 100))%")
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                
                Slider(value: $opacity, in: 0...1)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 180)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            hexValue = selectedColor.toHex() ?? ""
        }
    }
}

// Add these extensions for color handling
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
    
    func toHex() -> String? {
        let uic = NSColor(self)
        guard let components = uic.cgColor.components else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }
}

#Preview {
    InfiniteCanvas()
} 
