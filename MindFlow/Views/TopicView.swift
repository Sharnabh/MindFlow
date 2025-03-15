import SwiftUI

struct TopicView: View {
    let topic: Topic
    let isSelected: Bool
    let onSelect: () -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void
    let onNameChange: (String) -> Void
    let onEditingChange: (Bool) -> Void
    let onRelationDragChanged: ((CGPoint) -> Void)?
    let onRelationDragEnded: (() -> Void)?
    
    @GestureState private var dragOffset: CGSize = .zero
    @State private var editingName: String = ""
    @FocusState private var isFocused: Bool
    @State private var isControlPressed: Bool = false
    
    var body: some View {
        TopicContent(
            topic: topic,
            isSelected: isSelected,
            editingName: $editingName,
            isFocused: _isFocused,
            onNameChange: onNameChange,
            onEditingChange: onEditingChange
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .offset(dragOffset)
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if !topic.isEditing {
                        onSelect()
                    }
                }
        )
        .gesture(createDragGesture())
        .position(topic.position)
        .onChange(of: topic.isEditing) { isEditing in
            if isEditing {
                editingName = topic.name
                isFocused = true
            }
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
                isControlPressed = event.modifierFlags.contains(.control)
                return event
            }
        }
    }
    
    private func createDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 5)  // Add a small minimum distance to differentiate from taps
            .updating($dragOffset) { value, state, _ in
                if !topic.isEditing {
                    if isControlPressed {
                        if let onRelationDragChanged = onRelationDragChanged {
                            onRelationDragChanged(CGPoint(
                                x: topic.position.x + value.translation.width,
                                y: topic.position.y + value.translation.height
                            ))
                        }
                    } else {
                        state = value.translation
                        onDragChanged(CGPoint(
                            x: topic.position.x + value.translation.width,
                            y: topic.position.y + value.translation.height
                        ))
                    }
                }
            }
            .onEnded { value in
                if !topic.isEditing {
                    if isControlPressed {
                        onRelationDragEnded?()
                    } else {
                        onDragEnded()
                    }
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
    @EnvironmentObject var viewModel: CanvasViewModel
    
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
        TextField("", text: $editingName)
            .textFieldStyle(.plain)
            .foregroundColor(viewModel.topicStyle.foregroundColor)
            .font(viewModel.topicStyle.fontStyle)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: 120, maxWidth: max(120, CGFloat(editingName.count * 10)))
            .background(createBackground())
            .overlay(createBorder())
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
        Text(topic.name)
            .foregroundColor(viewModel.topicStyle.foregroundColor)
            .font(viewModel.topicStyle.fontStyle)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(width: max(120, CGFloat(topic.name.count * 10)))
            .background(createBackground())
            .overlay(createBorder())
    }
    
    private func createBackground() -> some View {
        Group {
            switch viewModel.topicStyle.shape {
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.topicStyle.backgroundColor)
            case .rectangle:
                Rectangle()
                    .fill(viewModel.topicStyle.backgroundColor)
            case .capsule:
                Capsule()
                    .fill(viewModel.topicStyle.backgroundColor)
            case .ellipse:
                Ellipse()
                    .fill(viewModel.topicStyle.backgroundColor)
            }
        }
    }
    
    private func createBorder() -> some View {
        Group {
            switch viewModel.topicStyle.shape {
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: createBorderStyle())
            case .rectangle:
                Rectangle()
                    .stroke(style: createBorderStyle())
            case .capsule:
                Capsule()
                    .stroke(style: createBorderStyle())
            case .ellipse:
                Ellipse()
                    .stroke(style: createBorderStyle())
            }
        }
    }
    
    private func createBorderStyle() -> StrokeStyle {
        let color = isSelected ? viewModel.topicStyle.borderColor : viewModel.topicStyle.borderColor.opacity(0.3)
        
        switch viewModel.topicStyle.borderStyle {
        case .solid:
            return StrokeStyle(lineWidth: viewModel.topicStyle.borderWidth)
        case .dashed:
            return StrokeStyle(
                lineWidth: viewModel.topicStyle.borderWidth,
                dash: [6, 3]
            )
        case .dotted:
            return StrokeStyle(
                lineWidth: viewModel.topicStyle.borderWidth,
                dash: [2, 2]
            )
        }
    }
}

// Helper function to get a topic's bounding box
func getTopicBox(topic: Topic) -> CGRect {
    let width = max(120, CGFloat(topic.name.count * 10))
    let height: CGFloat = 40 // Total height including vertical padding
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
        if box.contains(position) {
            return topic
        }
        
        // Search through subtopics
        for subtopic in topic.subtopics {
            if let found = searchThroughTopics(subtopic, searched: &searched) {
                return found
            }
        }
        
        // Search through relations
        for relatedTopic in topic.relations {
            if let found = searchThroughTopics(relatedTopic, searched: &searched) {
                return found
            }
        }
        
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
    
    // Function to find intersection with a box
    func findBoxIntersection(box: CGRect, from: CGPoint, towards: CGPoint) -> CGPoint {
        let dx = towards.x - from.x
        let dy = towards.y - from.y
        
        // Handle zero direction vector
        if abs(dx) < 0.001 && abs(dy) < 0.001 {
            return from
        }
        
        // Calculate intersections with all edges
        var intersections: [CGPoint] = []
        
        // Check left and right edges
        for x in [box.minX, box.maxX] {
            if abs(dx) > 0.001 {  // Avoid division by zero
                let t = (x - from.x) / dx
                let y = from.y + t * dy
                if y >= box.minY && y <= box.maxY {
                    intersections.append(CGPoint(x: x, y: y))
                }
            }
        }
        
        // Check top and bottom edges
        for y in [box.minY, box.maxY] {
            if abs(dy) > 0.001 {  // Avoid division by zero
                let t = (y - from.y) / dy
                let x = from.x + t * dx
                if x >= box.minX && x <= box.maxX {
                    intersections.append(CGPoint(x: x, y: y))
                }
            }
        }
        
        // Find the intersection point closest to the target point
        return intersections.min(by: { p1, p2 in
            let d1 = pow(p1.x - towards.x, 2) + pow(p1.y - towards.y, 2)
            let d2 = pow(p2.x - towards.x, 2) + pow(p2.y - towards.y, 2)
            return d1 < d2
        }) ?? from
    }
    
    let fromIntersect = findBoxIntersection(box: fromBox, from: fromCenter, towards: toCenter)
    let toIntersect = findBoxIntersection(box: toBox, from: toCenter, towards: fromCenter)
    
    return (fromIntersect, toIntersect)
}

// Helper function to calculate intersection with a point
func calculateIntersection(from topic: Topic, toPosition: CGPoint, topics: [Topic]) -> (start: CGPoint, end: CGPoint) {
    let fromBox = getTopicBox(topic: topic)
    
    // Calculate center points
    let fromCenter = topic.position
    let toCenter = toPosition
    
    // Function to find intersection with a box
    func findBoxIntersection(box: CGRect, from: CGPoint, towards: CGPoint) -> CGPoint {
        let dx = towards.x - from.x
        let dy = towards.y - from.y
        
        // Handle zero direction vector
        if abs(dx) < 0.001 && abs(dy) < 0.001 {
            return from
        }
        
        // Calculate intersections with all edges
        var intersections: [CGPoint] = []
        
        // Check left and right edges
        for x in [box.minX, box.maxX] {
            if abs(dx) > 0.001 {  // Avoid division by zero
                let t = (x - from.x) / dx
                let y = from.y + t * dy
                if y >= box.minY && y <= box.maxY {
                    intersections.append(CGPoint(x: x, y: y))
                }
            }
        }
        
        // Check top and bottom edges
        for y in [box.minY, box.maxY] {
            if abs(dy) > 0.001 {  // Avoid division by zero
                let t = (y - from.y) / dy
                let x = from.x + t * dx
                if x >= box.minX && x <= box.maxX {
                    intersections.append(CGPoint(x: x, y: y))
                }
            }
        }
        
        // Find the intersection point closest to the target point
        return intersections.min(by: { p1, p2 in
            let d1 = pow(p1.x - towards.x, 2) + pow(p1.y - towards.y, 2)
            let d2 = pow(p2.x - towards.x, 2) + pow(p2.y - towards.y, 2)
            return d1 < d2
        }) ?? from
    }
    
    // Find target topic at position
    if let targetTopic = findTopicAt(position: toPosition, in: topics) {
        let toBox = getTopicBox(topic: targetTopic)
        let fromIntersect = findBoxIntersection(box: fromBox, from: fromCenter, towards: targetTopic.position)
        let toIntersect = findBoxIntersection(box: toBox, from: targetTopic.position, towards: fromCenter)
        return (fromIntersect, toIntersect)
    }
    
    // If no target topic found, just connect to the cursor position
    let fromIntersect = findBoxIntersection(box: fromBox, from: fromCenter, towards: toCenter)
    return (fromIntersect, toCenter)
}

struct TopicsCanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        ZStack {
            // Draw all connection lines first (background layer)
            ConnectionLinesView(topics: viewModel.topics)
            
            // Draw all topics
            TopicsView(
                topics: viewModel.topics,
                selectedId: viewModel.selectedTopicId,
                onSelect: viewModel.selectTopic,
                onDragChanged: viewModel.updateDraggedTopicPosition,
                onDragEnded: viewModel.handleDragEnd,
                onNameChange: viewModel.updateTopicName,
                onEditingChange: viewModel.setTopicEditing,
                onRelationDragChanged: viewModel.handleRelationDragChanged,
                onRelationDragEnded: viewModel.handleRelationDragEnded
            )
            
            // Draw temporary relation line if dragging
            if let (fromId, toPosition) = viewModel.relationDragState,
               let fromTopic = viewModel.findTopic(id: fromId) {
                // Always show the line while dragging, but calculate endpoints based on target
                let points = calculateIntersection(from: fromTopic, toPosition: toPosition, topics: viewModel.topics)
                Path { path in
                    path.move(to: points.start)
                    path.addLine(to: points.end)
                }
                .stroke(Color.purple.opacity(0.5), lineWidth: 2)
            }
        }
    }
}

// Helper view to recursively render connection lines
private struct ConnectionLinesView: View {
    let topics: [Topic]
    
    var body: some View {
        // Draw all lines in a single layer
        ForEach(topics) { topic in
            Group {
                // Draw lines to immediate subtopics
                ForEach(topic.subtopics) { subtopic in
                    ConnectionLine(from: topic, to: subtopic, color: .blue)
                }
                
                // Draw relationship lines (only draw if we're the source topic)
                ForEach(topic.relations) { relatedTopic in
                    if topic.id < relatedTopic.id {  // Only draw once for each relationship
                        ConnectionLine(from: topic, to: relatedTopic, color: .purple)
                    }
                }
            }
            
            // Recursively draw lines for nested subtopics
            if !topic.subtopics.isEmpty {
                ConnectionLinesView(topics: topic.subtopics)
            }
        }
    }
}

// Helper view for drawing a single connection line
private struct ConnectionLine: View {
    let from: Topic
    let to: Topic
    let color: Color
    
    var body: some View {
        let points = calculateTopicIntersection(from: from, to: to)
        Path { path in
            path.move(to: points.start)
            path.addLine(to: points.end)
        }
        .stroke(color.opacity(0.3), lineWidth: 1)
    }
}

// Helper view to recursively render topics
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
    
    var body: some View {
        ZStack {
            // Draw all topics in order, ensuring proper z-index
            ForEach(topics) { topic in
                // Draw the topic
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
                    onNameChange: { newName in
                        onNameChange(topic.id, newName)
                    },
                    onEditingChange: { isEditing in
                        onEditingChange(topic.id, isEditing)
                    },
                    onRelationDragChanged: onRelationDragChanged.map { handler in
                        { newPosition in handler(topic.id, newPosition) }
                    },
                    onRelationDragEnded: onRelationDragEnded.map { handler in
                        { handler(topic.id) }
                    }
                )
                .zIndex(topic.id == selectedId ? 1 : 0)
                
                // Draw subtopics for this topic
                if !topic.subtopics.isEmpty {
                    TopicsView(
                        topics: topic.subtopics,
                        selectedId: selectedId,
                        onSelect: onSelect,
                        onDragChanged: onDragChanged,
                        onDragEnded: onDragEnded,
                        onNameChange: onNameChange,
                        onEditingChange: onEditingChange,
                        onRelationDragChanged: onRelationDragChanged,
                        onRelationDragEnded: onRelationDragEnded
                    )
                }
            }
        }
    }
} 