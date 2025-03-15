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
    
    private func calculateSize() -> (width: CGFloat, height: CGFloat) {
        let text = topic.isEditing ? editingName : topic.name
        let width = max(120, CGFloat(text.count * 10))
        let height: CGFloat = 40
        return (width, height)
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
        let size = calculateSize()
        return TextField("", text: $editingName)
            .textFieldStyle(.plain)
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: size.width, maxWidth: size.width)
            .background(
                createBackground()
                    .frame(width: size.width + 32, height: size.height)
            )
            .overlay(
                createBorder()
                    .frame(width: size.width + 32, height: size.height)
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
        let size = calculateSize()
        return Text(topic.name)
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(width: size.width)
            .background(
                createBackground()
                    .frame(width: size.width + 32, height: size.height)
            )
            .overlay(
                createBorder()
                    .frame(width: size.width + 32, height: size.height)
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