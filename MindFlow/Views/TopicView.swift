import SwiftUI

// MARK: - CGPoint Extensions
extension CGPoint: @retroactive AdditiveArithmetic {}
extension CGPoint: @retroactive VectorArithmetic {
    public static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    public static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    public static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    public mutating func scale(by rhs: Double) {
        x *= CGFloat(rhs)
        y *= CGFloat(rhs)
    }
    
    public var magnitudeSquared: Double {
        return Double(x*x + y*y)
    }
    
    public static var zero: CGPoint {
        return CGPoint(x: 0, y: 0)
    }
}

// Add AnimatableData protocol conformance to CGPoint
extension CGPoint {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(x, y) }
        set { (x, y) = (newValue.first, newValue.second) }
    }
}

// MARK: - View Extensions
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder func selectionGlow(isSelected: Bool, color: Color) -> some View {
        self
            .shadow(color: isSelected ? color.opacity(0.9) : .clear, radius: 4, x: 0, y: 0)
            .overlay(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.6), lineWidth: 2)
                            .scaleEffect(1.05)
                            .blur(radius: 1.5)
                            .opacity(1)
                            .animation(
                                Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                value: isSelected
                            )
                    }
                }
            )
            .shadow(color: isSelected ? color.opacity(0.6) : .clear, radius: 6, x: 0, y: 0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - TopicView
struct TopicView: View {
    var topic: Topic
    let isSelected: Bool
    
    // State for editing
    @State private var editingName: String = ""
    @FocusState private var isFocused: Bool
    @State private var animatedPosition: CGPoint
    @State private var isDragging: Bool = false
    @State private var isControlPressed: Bool = false
    @GestureState private var dragOffset: CGSize = .zero
    
    // Callbacks
    let onSelect: () -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void
    let onNameChange: (String) -> Void
    let onEditingChange: (Bool) -> Void
    let onRelationDragChanged: ((CGPoint) -> Void)?
    let onRelationDragEnded: (() -> Void)?
    let isRelationshipMode: Bool
    
    // Get access to the view model
    @ObservedObject var viewModel: CanvasViewModel
    
    init(topic: Topic, 
         isSelected: Bool, 
         onSelect: @escaping () -> Void, 
         onDragChanged: @escaping (CGPoint) -> Void, 
         onDragEnded: @escaping () -> Void, 
         onNameChange: @escaping (String) -> Void, 
         onEditingChange: @escaping (Bool) -> Void, 
         onRelationDragChanged: ((CGPoint) -> Void)? = nil, 
         onRelationDragEnded: (() -> Void)? = nil,
         isRelationshipMode: Bool = false,
         viewModel: CanvasViewModel) {
        
        self.topic = topic
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onNameChange = onNameChange
        self.onEditingChange = onEditingChange
        self.onRelationDragChanged = onRelationDragChanged
        self.onRelationDragEnded = onRelationDragEnded
        self.isRelationshipMode = isRelationshipMode
        self.viewModel = viewModel
        
        // Initialize position state
        self._animatedPosition = State(initialValue: topic.position)
    }
    
    // Check if a link button should be shown
    private var shouldShowLinkButton: Bool {
        guard let selectedId = viewModel.selectedTopicId, 
              selectedId != topic.id, 
              let selectedTopic = viewModel.findTopic(id: selectedId) else {
            return false
        }
        
        // Show link button if selected topic is an orphan (no parent)
        let isOrphan = viewModel.isOrphanTopic(selectedTopic)
        let isNotAlreadyChild = !topic.subtopics.contains(where: { $0.id == selectedId })
        let wouldNotCreateCycle = !viewModel.hasParentChildCycle(parentId: topic.id, childId: selectedId)
        
        return isOrphan && isNotAlreadyChild && wouldNotCreateCycle
    }
    
    var body: some View {
        ZStack {
            TopicContent(
                topic: topic,
                isSelected: isSelected,
                editingName: $editingName,
                isFocused: _isFocused,
                onNameChange: onNameChange,
                onEditingChange: onEditingChange,
                viewModel: viewModel
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .offset(isControlPressed || isRelationshipMode ? .zero : dragOffset)
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if !topic.isEditing {
                            onSelect()
                            
                            // Clear any active text fields when tapping on a topic
                            if viewModel.isTextInputActive {
                                viewModel.isTextInputActive = false
                                // Return focus to the canvas
                                NotificationCenter.default.post(name: .returnFocusToCanvas, object: nil)
                            }
                        }
                    }
            )
            .gesture(createDragGesture())
            .overlay(alignment: .trailing) {
                // Link button - show on right side edge of the topic
                if shouldShowLinkButton {
                    Button {
                        // Add selected topic as child of this topic
                        guard let selectedId = viewModel.selectedTopicId else { return }
                        viewModel.addSelectedTopicAsChild(parentId: topic.id, childId: selectedId)
                    } label: {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 16))
                            .foregroundColor(topic.foregroundColor.opacity(0.9))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(topic.backgroundColor)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(topic.foregroundColor.opacity(0.6), lineWidth: 1.5)
                                    )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 1.5, x: 1, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(x: 14)  // Half of the button width to make it straddle the edge
                }
            }
        }
        .position(animatedPosition)
        .onChange(of: topic.isEditing) { oldValue, newValue in
            if newValue {
                editingName = topic.name
                isFocused = true
            }
        }
        .onChange(of: topic.position) { oldValue, newPosition in
            if isDragging {
                animatedPosition = newPosition
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    animatedPosition = newPosition
                }
            }
        }
        .onAppear {
            animatedPosition = topic.position
            
            NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
                isControlPressed = event.modifierFlags.contains(.control)
                return event
            }
        }
    }
    
    private func createDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($dragOffset) { value, state, _ in
                if !topic.isEditing {
                    if isControlPressed || isRelationshipMode {
                        if let onRelationDragChanged = onRelationDragChanged {
                            onRelationDragChanged(CGPoint(
                                x: topic.position.x + value.translation.width,
                                y: topic.position.y + value.translation.height
                            ))
                        }
                    } else {
                        state = value.translation
                        
                        let newPosition = CGPoint(
                            x: topic.position.x + value.translation.width,
                            y: topic.position.y + value.translation.height
                        )
                        
                        DispatchQueue.main.async {
                            animatedPosition = newPosition
                        }
                        
                        onDragChanged(newPosition)
                    }
                }
            }
            .onChanged { _ in
                if !isDragging && !topic.isEditing && !isControlPressed && !isRelationshipMode {
                    DispatchQueue.main.async {
                        isDragging = true
                    }
                }
            }
            .onEnded { value in
                if !topic.isEditing {
                    if isControlPressed || isRelationshipMode {
                        onRelationDragEnded?()
                    } else {
                        let finalPosition = CGPoint(
                            x: topic.position.x + value.translation.width,
                            y: topic.position.y + value.translation.height
                        )
                        
                        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
                            animatedPosition = finalPosition
                        }
                        
                        onDragEnded()
                        isDragging = false
                    }
                }
            }
    }
}

// MARK: - TopicsCanvasView
struct TopicsCanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isRelationshipMode: Bool
    
    @State private var animatedTemporaryLineStart: CGPoint = .zero
    @State private var animatedTemporaryLineEnd: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // Background detection area - must be first in ZStack to be behind everything
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // Clear focus only when tapping empty canvas area
                    if viewModel.isTextInputActive {
                        viewModel.isTextInputActive = false
                        // Return focus to the canvas
                        NotificationCenter.default.post(name: .returnFocusToCanvas, object: nil)
                    }
                    // Deselect any selected topic when clicking empty area
                    viewModel.selectTopic(withId: nil)
                }
            
            // Draw all connection lines first (background layer)
            ConnectionLinesView(
                viewModel: viewModel,
                topics: viewModel.topics,
                onDeleteRelation: viewModel.removeRelation,
                onDeleteParentChild: { _, childId in
                    viewModel.removeParentChildRelation(childId: childId)
                },
                selectedId: viewModel.selectedTopicId
            )
            
            // Draw all topics
            TopicsView(
                topics: viewModel.topics,
                selectedId: viewModel.selectedTopicId,
                onSelect: viewModel.selectTopic(withId:),
                onDragChanged: viewModel.updateDraggedTopicPosition,
                onDragEnded: viewModel.handleDragEnd,
                onNameChange: viewModel.updateTopicName,
                onEditingChange: viewModel.setTopicEditing,
                onRelationDragChanged: viewModel.handleRelationDragChanged,
                onRelationDragEnded: viewModel.handleRelationDragEnded,
                isRelationshipMode: isRelationshipMode,
                viewModel: viewModel
            )
            
            // Draw temporary relation line if dragging
            if let (fromId, toPosition) = viewModel.relationDragState,
               let fromTopic = viewModel.findTopic(id: fromId) {
                let points = calculateIntersection(from: fromTopic, toPosition: toPosition, topics: viewModel.topics)
                let shouldUseCurvedStyle = fromTopic.branchStyle == .curved
                
                Group {
                    if shouldUseCurvedStyle {
                        AnimatedCurvePath(start: animatedTemporaryLineStart, end: animatedTemporaryLineEnd)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                    } else {
                        AnimatedLinePath(start: animatedTemporaryLineStart, end: animatedTemporaryLineEnd)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                    }
                }
                .onChange(of: points.start) { oldValue, newStart in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        animatedTemporaryLineStart = newStart
                    }
                }
                .onChange(of: points.end) { oldValue, newEnd in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        animatedTemporaryLineEnd = newEnd
                    }
                }
                .onAppear {
                    animatedTemporaryLineStart = points.start
                    animatedTemporaryLineEnd = points.end
                }
            }
        }
    }
}

// MARK: - TopicsView
private struct TopicsView: View {
    let topics: [Topic]
    let selectedId: UUID?
    let onSelect: (UUID?) -> Void
    let onDragChanged: (UUID, CGPoint) -> Void
    let onDragEnded: (UUID) -> Void
    let onNameChange: (UUID, String) -> Void
    let onEditingChange: (UUID, Bool) -> Void
    let onRelationDragChanged: ((UUID, CGPoint) -> Void)?
    let onRelationDragEnded: ((UUID) -> Void)?
    let isRelationshipMode: Bool
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        ZStack {
            ForEach(topics) { topic in
                TopicView(
                    topic: topic,
                    isSelected: topic.id == selectedId,
                    onSelect: { onSelect(topic.id) },
                    onDragChanged: { newPosition in
                        onDragChanged(topic.id, newPosition)
                    },
                    onDragEnded: {
                        onDragEnded(topic.id)
                    },
                    onNameChange: { name in
                        onNameChange(topic.id, name)
                    },
                    onEditingChange: { isEditing in
                        onEditingChange(topic.id, isEditing)
                    },
                    onRelationDragChanged: onRelationDragChanged.map { handler in
                        { position in
                            handler(topic.id, position)
                        }
                    },
                    onRelationDragEnded: onRelationDragEnded.map { handler in
                        { handler(topic.id) }
                    },
                    isRelationshipMode: isRelationshipMode,
                    viewModel: viewModel
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(topic.id == selectedId ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: topic.id == selectedId)
                
                if !topic.subtopics.isEmpty && !topic.isCollapsed {
                    TopicsView(
                        topics: topic.subtopics,
                        selectedId: selectedId,
                        onSelect: onSelect,
                        onDragChanged: onDragChanged,
                        onDragEnded: onDragEnded,
                        onNameChange: onNameChange,
                        onEditingChange: onEditingChange,
                        onRelationDragChanged: onRelationDragChanged,
                        onRelationDragEnded: onRelationDragEnded,
                        isRelationshipMode: isRelationshipMode,
                        viewModel: viewModel
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: !topic.isCollapsed)
                }
            }
        }
    }
}

// Helper function to get a topic's bounding box
func getTopicBox(topic: Topic) -> CGRect {
    // Calculate width based on the longest line
    let lines = topic.name.components(separatedBy: "\n")
    let maxLineLength = lines.map { $0.count }.max() ?? 0
    
    // Scale width based on font size - larger fonts need more width per character
    let fontSizeScaleFactor = max(1.0, topic.fontSize / 14.0)
    let width = max(120, CGFloat(maxLineLength * 10) * fontSizeScaleFactor) + 32 // Add padding for shape
    
    // Calculate height based on number of lines
    let lineCount = lines.count
    // Scale line height based on font size
    let lineHeight = max(24, topic.fontSize * 1.5)
    let height = max(40, CGFloat(lineCount) * lineHeight) + 16 // Add vertical padding
    
    return CGRect(
        x: topic.position.x - width/2,
        y: topic.position.y - height/2,
        width: width,
        height: height
    )
}

// Helper function to find a topic at a given position
func findTopicAt(position: CGPoint, in topics: [Topic], tolerance: CGFloat = 40) -> Topic? {
    // Helper function to search through a topic and all its connected topics
    func searchThroughTopics(_ topic: Topic, searched: inout Set<UUID>) -> Topic? {
        // If we've already searched this topic, skip it
        if searched.contains(topic.id) {
            return nil
        }
        searched.insert(topic.id)

        // Check if the position is within this topic's box
        let box = getTopicBox(topic: topic)
        // Check within bounds (with tolerance)
        if box.insetBy(dx: -tolerance, dy: -tolerance).contains(position) {
            return topic
        }

        // Search through subtopics
        for subtopic in topic.subtopics {
            if let found = searchThroughTopics(subtopic, searched: &searched) {
                return found
            }
        }

        // Don't search through relations for hit-testing
        // This prevents infinite loops and is not the intended behavior for finding a topic *at* a point.

        return nil
    }
    
    // Keep track of searched topics to avoid cycles
    var searched = Set<UUID>()
    
    // Search through all root topics
    for topic in topics {
        if let found = searchThroughTopics(topic, searched: &searched) {
            return found
        }
    }
    
    return nil
}

// Helper function to calculate intersection between two topics
func calculateTopicIntersection(from: Topic, to: Topic) -> (start: CGPoint, end: CGPoint) {
    let fromBox = getTopicBox(topic: from)
    let toBox = getTopicBox(topic: to)
    
    // Calculate center points
    let fromCenter = from.position
    let toCenter = to.position
    
    // Constants for automatic arrangement - we'll leave these in as comments for reference
    // Horizontal space between parent and child
    // Minimum vertical space between siblings
    
    // Function to find the best side intersection point
    func findBestSideIntersection(box: CGRect, from: CGPoint, towards: CGPoint, isParentChild: Bool = false) -> CGPoint {
        // For parent-child relationships, always use right side of parent and left side of child
        if isParentChild {
            if box == fromBox {
                return CGPoint(x: box.maxX, y: box.midY) // Right side for parent
            } else {
                return CGPoint(x: box.minX, y: box.midY) // Left side for child
            }
        }
        
        // For other relationships (like manually created ones), use the original angle-based logic
        let leftCenter = CGPoint(x: box.minX, y: box.midY)
        let rightCenter = CGPoint(x: box.maxX, y: box.midY)
        let topCenter = CGPoint(x: box.midX, y: box.minY)
        let bottomCenter = CGPoint(x: box.midX, y: box.maxY)
        
        let angle = atan2(towards.y - from.y, towards.x - from.x)
        let normalizedAngle = (angle + .pi * 2).truncatingRemainder(dividingBy: .pi * 2)
        
        if normalizedAngle >= .pi * 7/4 || normalizedAngle < .pi * 1/4 {
            return rightCenter
        } else if normalizedAngle >= .pi * 1/4 && normalizedAngle < .pi * 3/4 {
            return bottomCenter
        } else if normalizedAngle >= .pi * 3/4 && normalizedAngle < .pi * 5/4 {
            return leftCenter
        } else {
            return topCenter
        }
    }
    
    // Check if this is a parent-child relationship by looking at the subtopics
    let isParentChild = from.subtopics.contains(where: { $0.id == to.id })
    
    let fromIntersect = findBestSideIntersection(box: fromBox, from: fromCenter, towards: toCenter, isParentChild: isParentChild)
    let toIntersect = findBestSideIntersection(box: toBox, from: toCenter, towards: fromCenter, isParentChild: isParentChild)
    
    return (fromIntersect, toIntersect)
}

// Helper function to calculate intersection with a point
func calculateIntersection(from topic: Topic, toPosition: CGPoint, topics: [Topic]) -> (start: CGPoint, end: CGPoint) {
    let fromBox = getTopicBox(topic: topic)
    
    // Calculate center points
    let fromCenter = topic.position
    let toCenter = toPosition
    
    // Function to find the best side intersection point
    func findBestSideIntersection(box: CGRect, from: CGPoint, towards: CGPoint) -> CGPoint {
        // For dragging new connections, use the same angle-based logic
        let leftCenter = CGPoint(x: box.minX, y: box.midY)
        let rightCenter = CGPoint(x: box.maxX, y: box.midY)
        let topCenter = CGPoint(x: box.midX, y: box.minY)
        let bottomCenter = CGPoint(x: box.midX, y: box.maxY)
        
        let angle = atan2(towards.y - from.y, towards.x - from.x)
        let normalizedAngle = (angle + .pi * 2).truncatingRemainder(dividingBy: .pi * 2)
        
        if normalizedAngle >= .pi * 7/4 || normalizedAngle < .pi * 1/4 {
            return rightCenter
        } else if normalizedAngle >= .pi * 1/4 && normalizedAngle < .pi * 3/4 {
            return bottomCenter
        } else if normalizedAngle >= .pi * 3/4 && normalizedAngle < .pi * 5/4 {
            return leftCenter
        } else {
            return topCenter
        }
    }
    
    // Find target topic at position
    if let targetTopic = findTopicAt(position: toPosition, in: topics) {
        let toBox = getTopicBox(topic: targetTopic)
        let fromIntersect = findBestSideIntersection(box: fromBox, from: fromCenter, towards: targetTopic.position)
        let toIntersect = findBestSideIntersection(box: toBox, from: targetTopic.position, towards: fromCenter)
        return (fromIntersect, toIntersect)
    }
    
    // If no target topic found, just connect to the cursor position
    let fromIntersect = findBestSideIntersection(box: fromBox, from: fromCenter, towards: toCenter)
    return (fromIntersect, toCenter)
}
