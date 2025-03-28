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
            .foregroundColor(topic.foregroundColor.opacity(topic.foregroundOpacity))
            .font(.custom(topic.font, size: topic.fontSize, relativeTo: .body).weight(topic.fontWeight))
            .bold(topic.textStyles.contains(.bold))
            .italic(topic.textStyles.contains(.italic))
            .strikethrough(topic.textStyles.contains(.strikethrough))
            .underline(topic.textStyles.contains(.underline))
            .textCase(topic.textCase == .uppercase ? .uppercase :
                     topic.textCase == .lowercase ? .lowercase :
                     nil)
            .multilineTextAlignment(topic.textAlignment == .left ? .leading : topic.textAlignment == .right ? .trailing : .center)
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
            .onKeyPress(.tab) {
                isFocused = true
                return .handled
            }
            .submitLabel(.return)
    }
    
    private func createTextDisplay() -> some View {
        let size = calculateSize()
        return Text(topic.textCase == .uppercase ? topic.name.uppercased() :
                   topic.textCase == .lowercase ? topic.name.lowercased() :
                   topic.textCase == .capitalize ? topic.name.capitalized :
                   topic.name)
            .foregroundColor(topic.foregroundColor.opacity(topic.foregroundOpacity))
            .font(.custom(topic.font, size: topic.fontSize, relativeTo: .body).weight(topic.fontWeight))
            .bold(topic.textStyles.contains(.bold))
            .italic(topic.textStyles.contains(.italic))
            .strikethrough(topic.textStyles.contains(.strikethrough))
            .underline(topic.textStyles.contains(.underline))
            .multilineTextAlignment(topic.textAlignment == .left ? .leading : topic.textAlignment == .right ? .trailing : .center)
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
    let width = max(120, CGFloat(topic.name.count * 10)) + 32 // Add padding for shape
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
    
    // Constants for automatic arrangement
    let horizontalSpacing: CGFloat = 200 // Horizontal space between parent and child
    let minVerticalSpacing: CGFloat = 60 // Minimum vertical space between siblings
    
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

// Helper view to recursively render connection lines
private struct ConnectionLinesView: View {
    let topics: [Topic]
    
    // Helper function to check if any topic in the entire canvas has curved style
    private func hasCurvedStyle(_ topics: [Topic]) -> Bool {
        // First check all root topics
        for topic in topics {
            if topic.branchStyle == .curved {
                return true
            }
        }
        
        // Then check all subtopics recursively
        for topic in topics {
            if checkSubtopicsForCurvedStyle(topic) {
                return true
            }
        }
        
        return false
    }
    
    // Helper function to check subtopics recursively
    private func checkSubtopicsForCurvedStyle(_ topic: Topic) -> Bool {
        // Check immediate subtopics
        for subtopic in topic.subtopics {
            if subtopic.branchStyle == .curved {
                return true
            }
            
            // Recursively check deeper subtopics
            if checkSubtopicsForCurvedStyle(subtopic) {
                return true
            }
        }
        
        // Check relations
        for relation in topic.relations {
            if relation.branchStyle == .curved {
                return true
            }
        }
        
        return false
    }
    
    var body: some View {
        // Check if any topic in the entire canvas has curved style
        let shouldUseCurvedStyle = hasCurvedStyle(topics)
        
        // Draw all lines in a single layer
        ForEach(topics) { topic in
            Group {
                // Draw lines to immediate subtopics
                ForEach(topic.subtopics) { subtopic in
                    ConnectionLine(from: topic, to: subtopic, color: subtopic.borderColor, forceCurved: shouldUseCurvedStyle)
                }
                
                // Draw relationship lines (only draw if we're the source topic)
                ForEach(topic.relations) { relatedTopic in
                    if topic.id < relatedTopic.id {  // Only draw once for each relationship
                        ConnectionLine(from: topic, to: relatedTopic, color: .purple, forceCurved: shouldUseCurvedStyle)
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
    let forceCurved: Bool
    
    var body: some View {
        let points = calculateTopicIntersection(from: from, to: to)
        
        // Use curved style if forced (meaning any topic has curved style)
        if forceCurved {
            // Draw curved path
            Path { path in
                path.move(to: points.start)
                
                // Calculate control points for the curve
                let dx = points.end.x - points.start.x
                let dy = points.end.y - points.start.y
                let midX = points.start.x + dx * 0.5
                
                // Create control points that curve outward
                let control1 = CGPoint(x: midX, y: points.start.y)
                let control2 = CGPoint(x: midX, y: points.end.y)
                
                path.addCurve(to: points.end,
                             control1: control1,
                             control2: control2)
            }
            .stroke(color.opacity(1.0), lineWidth: 1)
        } else {
            // Draw straight line
            Path { path in
                path.move(to: points.start)
                path.addLine(to: points.end)
            }
            .stroke(color.opacity(1.0), lineWidth: 1)
        }
    }
}

struct TopicsCanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    
    // Helper function to check if any topic in the entire canvas has curved style
    private func hasCurvedStyle(_ topics: [Topic]) -> Bool {
        // First check all root topics
        for topic in topics {
            if topic.branchStyle == .curved {
                return true
            }
        }
        
        // Then check all subtopics recursively
        for topic in topics {
            if checkSubtopicsForCurvedStyle(topic) {
                return true
            }
        }
        
        return false
    }
    
    // Helper function to check subtopics recursively
    private func checkSubtopicsForCurvedStyle(_ topic: Topic) -> Bool {
        // Check immediate subtopics
        for subtopic in topic.subtopics {
            if subtopic.branchStyle == .curved {
                return true
            }
            
            // Recursively check deeper subtopics
            if checkSubtopicsForCurvedStyle(subtopic) {
                return true
            }
        }
        
        // Check relations
        for relation in topic.relations {
            if relation.branchStyle == .curved {
                return true
            }
        }
        
        return false
    }
    
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
                // Check if target topic exists at the current position
                let targetTopic = findTopicAt(position: toPosition, in: viewModel.topics)
                let points = calculateIntersection(from: fromTopic, toPosition: toPosition, topics: viewModel.topics)
                
                // Use curved style if any topic in the canvas has curved style
                if hasCurvedStyle(viewModel.topics) {
                    // Draw curved path
                Path { path in
                    path.move(to: points.start)
                        
                        // Calculate control points for the curve
                        let dx = points.end.x - points.start.x
                        let dy = points.end.y - points.start.y
                        let midX = points.start.x + dx * 0.5
                        
                        // Create control points that curve outward
                        let control1 = CGPoint(x: midX, y: points.start.y)
                        let control2 = CGPoint(x: midX, y: points.end.y)
                        
                        path.addCurve(to: points.end,
                                     control1: control1,
                                     control2: control2)
                    }
                    .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                } else {
                    // Draw straight line
                    Path { path in
                        path.move(to: points.start)
                        path.addLine(to: points.end)
                    }
                    .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                }
            }
        }
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