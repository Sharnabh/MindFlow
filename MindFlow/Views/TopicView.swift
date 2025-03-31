import SwiftUI

// Add CGPoint animation extensions
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

// Add View extension for conditional modifiers
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

// Physics properties for topic dragging
class DragPhysics: ObservableObject {
    var velocity: CGSize = .zero
    var lastPosition: CGPoint = .zero
    var lastUpdateTime: Date = Date()
    var isDecelerating: Bool = false
    var targetPosition: CGPoint = .zero
    
    func updateVelocity(currentPosition: CGPoint) {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastUpdateTime)
        
        if timeInterval > 0 {
            // Calculate velocity based on position change over time
            let dx = currentPosition.x - lastPosition.x
            let dy = currentPosition.y - lastPosition.y
            
            // Apply some smoothing to the velocity
            let smoothingFactor: CGFloat = 0.3
            velocity.width = velocity.width * (1 - smoothingFactor) + (dx / CGFloat(timeInterval)) * smoothingFactor
            velocity.height = velocity.height * (1 - smoothingFactor) + (dy / CGFloat(timeInterval)) * smoothingFactor
        }
        
        lastPosition = currentPosition
        lastUpdateTime = now
    }
    
    func reset() {
        velocity = .zero
        isDecelerating = false
    }
}

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
    let isRelationshipMode: Bool
    
    @GestureState private var dragOffset: CGSize = .zero
    @State private var editingName: String = ""
    @FocusState private var isFocused: Bool
    @State private var isControlPressed: Bool = false
    
    // Physics state
    @StateObject private var physics = DragPhysics()
    @State private var animatedPosition: CGPoint
    @State private var isDragging: Bool = false
    
    // Timer for deceleration
    @State private var decelerationTimer: Timer?
    
    init(topic: Topic, isSelected: Bool, onSelect: @escaping () -> Void, onDragChanged: @escaping (CGPoint) -> Void, onDragEnded: @escaping () -> Void, onNameChange: @escaping (String) -> Void, onEditingChange: @escaping (Bool) -> Void, onRelationDragChanged: ((CGPoint) -> Void)?, onRelationDragEnded: (() -> Void)?, isRelationshipMode: Bool) {
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
        
        // Initialize position state
        self._animatedPosition = State(initialValue: topic.position)
    }
    
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
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .offset(isControlPressed || isRelationshipMode ? .zero : dragOffset) // Only apply drag offset when not in relation mode
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if !topic.isEditing {
                        onSelect()
                    }
                }
        )
        .gesture(createDragGesture())
        .position(animatedPosition)
        .onChange(of: topic.isEditing) { oldValue, newValue in
            if newValue {
                editingName = topic.name
                isFocused = true
            }
        }
        .onChange(of: topic.position) { oldValue, newPosition in
            // When position is updated externally, update the animated position immediately during drag
            // This ensures subtopics move with their parent without delay
            if isDragging {
                // During active dragging, update position immediately without animation
                animatedPosition = newPosition
            } else {
                // When position updates from other sources (like auto-layout), use spring animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    animatedPosition = newPosition
                }
            }
        }
        .onAppear {
            animatedPosition = topic.position
            physics.lastPosition = topic.position
            
            NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
                isControlPressed = event.modifierFlags.contains(.control)
                return event
            }
        }
        .onDisappear {
            decelerationTimer?.invalidate()
        }
    }
    
    private func createDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($dragOffset) { value, state, _ in
                if !topic.isEditing {
                    if isControlPressed || isRelationshipMode {
                        if let onRelationDragChanged = onRelationDragChanged {
                            // For relation dragging, only update the visual line without moving the topic
                            onRelationDragChanged(CGPoint(
                                x: topic.position.x + value.translation.width,
                                y: topic.position.y + value.translation.height
                            ))
                        }
                    } else {
                        // For normal dragging, update both the visual offset and topic position
                        state = value.translation
                        
                        // Update position for real-time movement
                        let newPosition = CGPoint(
                            x: topic.position.x + value.translation.width,
                            y: topic.position.y + value.translation.height
                        )
                        
                        // Update animated position using DispatchQueue to avoid state modification during view update
                        DispatchQueue.main.async {
                            // Update animated position directly during drag for responsiveness
                            animatedPosition = newPosition
                        }
                        
                        // Inform parent about the position change
                        onDragChanged(newPosition)
                    }
                }
            }
            .onChanged { _ in
                // Set dragging flag to true when gesture starts
                if !isDragging && !topic.isEditing && !isControlPressed && !isRelationshipMode {
                    // Use DispatchQueue.main.async to modify state outside the view update cycle
                    DispatchQueue.main.async {
                        isDragging = true
                        
                        // Cancel any existing deceleration
                        decelerationTimer?.invalidate()
                    }
                }
            }
            .onEnded { value in
                if !topic.isEditing {
                    if isControlPressed || isRelationshipMode {
                        onRelationDragEnded?()
                    } else {
                        // Simply update the final position without inertia
                        let finalPosition = CGPoint(
                            x: topic.position.x + value.translation.width,
                            y: topic.position.y + value.translation.height
                        )
                        
                        // Update position with spring animation to final resting point
                        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
                            animatedPosition = finalPosition
                        }
                        
                        // Immediately notify about drag end
                        onDragEnded()
                        isDragging = false
                    }
                }
            }
    }
    
    // We'll keep this method but it won't be called anymore
    private func startDeceleration() {
        // Just immediately call onDragEnded without any deceleration
        onDragEnded()
        physics.reset()
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
        let lines = text.components(separatedBy: "\n")
        let maxLineLength = lines.map { $0.count }.max() ?? 0
        
        // Scale width based on font size - larger fonts need more width per character
        let fontSizeScaleFactor = max(1.0, topic.fontSize / 14.0)
        let width = max(120, CGFloat(maxLineLength * 10) * fontSizeScaleFactor)
        
        let lineCount = lines.count
        // Scale line height based on font size
        let lineHeight = max(24, topic.fontSize * 1.5)
        let height = max(40, CGFloat(lineCount) * lineHeight)
        
        return (width, height)
    }
    
    // Recursively count all descendants
    private func countAllDescendants(for topic: Topic) -> Int {
        var count = 0
        // Add direct subtopics
        count += topic.subtopics.count
        // Add all nested subtopics recursively
        for subtopic in topic.subtopics {
            count += countAllDescendants(for: subtopic)
        }
        return count
    }
    
    var body: some View {
        Group {
            if topic.isEditing {
                createTextField()
            } else {
                createTextDisplay()
            }
        }
        .overlay(alignment: .topTrailing) {
            if topic.isCollapsed && !topic.subtopics.isEmpty {
                let totalDescendants = countAllDescendants(for: topic)
                Image(systemName: "\(totalDescendants).circle")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(4)
                    .background(Circle().fill(Color.white.opacity(0.7)))
                    .offset(x: 8, y: -8)
            }
        }
    }
    
    private func createTextField() -> some View {
        let size = calculateSize()
        
        return TextEditor(text: $editingName)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .foregroundColor(topic.foregroundColor.opacity(topic.foregroundOpacity))
            .font(.custom(topic.font, size: topic.fontSize, relativeTo: .body).weight(topic.fontWeight))
            .fontWeight(topic.textStyles.contains(.bold) ? .bold : nil)
            .italic(topic.textStyles.contains(.italic))
            .strikethrough(topic.textStyles.contains(.strikethrough))
            .underline(topic.textStyles.contains(.underline))
            .textCase(topic.textCase == .uppercase ? Text.Case.uppercase :
                     topic.textCase == .lowercase ? Text.Case.lowercase :
                     nil)
            .multilineTextAlignment(topic.textAlignment == .left ? .leading : topic.textAlignment == .right ? .trailing : .center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(width: size.width, height: size.height)
            .background(
                createBackground()
                    .frame(width: size.width + 32, height: size.height)
            )
            .overlay(
                createBorder()
                    .frame(width: size.width + 32, height: size.height)
            )
            .focused($isFocused)
            .onChange(of: editingName) { oldValue, newValue in
                onNameChange(newValue)
            }
            .onExitCommand {
                isFocused = false
                onEditingChange(false)
            }
            .onAppear {
                // Setup a local key monitor that specifically handles Return keys
                setupReturnKeyMonitor()
            }
            .onDisappear {
                // Remove the local monitor when not editing
                removeReturnKeyMonitor()
            }
    }
    
    // Local key monitor using NSEvent directly for reliable Shift+Return detection
    private func setupReturnKeyMonitor() {
        // Handle Return key
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ReturnKeyPressed"), object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let event = userInfo["event"] as? NSEvent,
               event.keyCode == 36, // Return key
               self.isFocused {
                
                if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command) {
                    // Shift+Return or Command+Return: add a new line
                    // The KeyboardMonitor has already blocked the system event,
                    // so we need to manually insert exactly one newline
                    
                    // Use dispatch async to ensure we're outside the view update cycle
                    DispatchQueue.main.async {
                        // Check if we can get the current text view
                        if let currentEditor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            // Get the current selection
                            let range = currentEditor.selectedRange()
                            
                            // Insert a single newline at the selection
                            currentEditor.insertText("\n", replacementRange: range)
                            
                            // Update the bound text value
                            if let updatedText = currentEditor.string as String? {
                                self.editingName = updatedText
                                self.onNameChange(updatedText)
                            }
                        } else {
                            // Fallback if we can't get the text view
                            self.editingName += "\n"
                            self.onNameChange(self.editingName)
                        }
                    }
                } else {
                    // Regular Return: commit changes
                    DispatchQueue.main.async {
                        self.onNameChange(self.editingName)
                        self.isFocused = false
                        self.onEditingChange(false)
                    }
                }
            }
        }
    }
    
    private func removeReturnKeyMonitor() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ReturnKeyPressed"), object: nil)
    }
    
    private func createTextDisplay() -> some View {
        let size = calculateSize()
        return Text(topic.textCase == .uppercase ? topic.name.uppercased() :
                   topic.textCase == .lowercase ? topic.name.lowercased() :
                   topic.textCase == .capitalize ? topic.name.capitalized :
                   topic.name)
            .foregroundColor(topic.foregroundColor.opacity(topic.foregroundOpacity))
            .font(.custom(topic.font, size: topic.fontSize, relativeTo: .body).weight(topic.fontWeight))
            .fontWeight(topic.textStyles.contains(.bold) ? .bold : nil)
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
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .circle:
                Capsule()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .roundedSquare:
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .line:
                Rectangle()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .frame(height: 2)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .diamond:
                Diamond()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .hexagon:
                RegularPolygon(sides: 6)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .octagon:
                RegularPolygon(sides: 8)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .parallelogram:
                Parallelogram()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .cloud:
                Cloud()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .heart:
                Heart()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .shield:
                Shield()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .star:
                Star()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .document:
                Document()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .doubleRectangle:
                DoubleRectangle()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .flag:
                Flag()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .leftArrow:
                Arrow(pointing: .left)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
            case .rightArrow:
                Arrow(pointing: .right)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .selectionGlow(isSelected: isSelected, color: topic.borderColor)
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

// Helper view to recursively render connection lines
private struct ConnectionLinesView: View {
    let topics: [Topic]
    let onDeleteRelation: (UUID, UUID) -> Void
    let selectedId: UUID?
    
    var body: some View {
        // Draw all lines in a single layer with smooth animations
        ForEach(topics) { topic in
            Group {
                // Draw lines to immediate subtopics only if not collapsed
                if !topic.isCollapsed {
                    ForEach(topic.subtopics) { subtopic in
                        ConnectionLine(
                            from: topic,
                            to: subtopic,
                            color: subtopic.borderColor,
                            forceCurved: false, // Not forcing curved, will use individual topic settings
                            onDelete: {}, // No delete for parent-child relationships
                            isRelationship: false, // This is a parent-child relationship
                            selectedId: selectedId
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: topic.position)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: subtopic.position)
                    }
                }
                
                // Draw relationship lines (only draw if we're the source topic)
                ForEach(topic.relations) { relatedTopic in
                    ConnectionLine(
                        from: topic,
                        to: relatedTopic,
                        color: .purple,
                        forceCurved: false, // Not forcing curved, will use individual topic settings
                        onDelete: { onDeleteRelation(topic.id, relatedTopic.id) },
                        isRelationship: true, // This is a relationship line
                        selectedId: selectedId
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: topic.position)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: relatedTopic.position)
                }
            }
            
            // Recursively draw lines for nested subtopics only if not collapsed
            if !topic.subtopics.isEmpty && !topic.isCollapsed {
                ConnectionLinesView(
                    topics: topic.subtopics,
                    onDeleteRelation: onDeleteRelation,
                    selectedId: selectedId
                )
                .transition(.opacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: !topic.isCollapsed)
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
    let onDelete: () -> Void
    let isRelationship: Bool
    let selectedId: UUID?
    
    @State private var isHovered = false
    @State private var hoverPoint: CGPoint = .zero
    @State private var animatedStartPoint: CGPoint = .zero
    @State private var animatedEndPoint: CGPoint = .zero
    
    private var shouldUseCurvedStyle: Bool {
        // Use curved style if:
        // 1. Either the source or target topic has curved branch style
        // 2. Or if forceCurved is true (global setting)
        // For parent-child relationships, use the parent's style
        if !isRelationship {
            return from.branchStyle == .curved
        }
        // For relationships, use curved if either topic has curved style
        return forceCurved || from.branchStyle == .curved || to.branchStyle == .curved
    }
    
    var body: some View {
        let points = calculateTopicIntersection(from: from, to: to)
        
        ZStack {
            // Draw the line
            Group {
                if shouldUseCurvedStyle {
                    // Draw curved path with animation
                    AnimatedCurvePath(start: animatedStartPoint, end: animatedEndPoint)
                        .stroke(color.opacity(1.0), lineWidth: 1)
                } else {
                    // Draw straight line with animation
                    AnimatedLinePath(start: animatedStartPoint, end: animatedEndPoint)
                        .stroke(color.opacity(1.0), lineWidth: 1)
                }
            }
            
            // Add hover area with smaller width
            Path { path in
                path.move(to: animatedStartPoint)
                path.addLine(to: animatedEndPoint)
            }
            .stroke(Color.clear, lineWidth: 10) // 10px hover area
            .onHover { hovering in
                if hovering {
                    // Get the current mouse position
                    if let window = NSApp.keyWindow,
                       let contentView = window.contentView {
                        let mouseLocation = NSEvent.mouseLocation
                        let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                        let viewPoint = contentView.convert(windowPoint, from: nil)
                        hoverPoint = viewPoint
                        
                        // Calculate distance from point to line
                        let distance = distanceFromPointToLine(point: hoverPoint, lineStart: animatedStartPoint, lineEnd: animatedEndPoint)
                        isHovered = distance < 10 // Show button if within 10px of the line
                    }
                } else {
                    isHovered = false
                }
            }
            
            // Delete button - show for relationship lines when hovered or when connected topics are selected
            if isRelationship && (isHovered || from.id == selectedId || to.id == selectedId) {
                Button(action: onDelete) {
                    ZStack {
                        // Background circle with line color and very low opacity
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 24, height: 24)
                        
                        // Minus icon
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(color)
                            .font(.system(size: 16))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .position(
                    x: (animatedStartPoint.x + animatedEndPoint.x) / 2,
                    y: (animatedStartPoint.y + animatedEndPoint.y) / 2
                )
            }
        }
        .onChange(of: points.start) { oldValue, newStart in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                animatedStartPoint = newStart
            }
        }
        .onChange(of: points.end) { oldValue, newEnd in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                animatedEndPoint = newEnd
            }
        }
        .onAppear {
            // Initialize animated points
            animatedStartPoint = points.start
            animatedEndPoint = points.end
        }
    }
    
    // Helper function to calculate distance from a point to a line segment
    private func distanceFromPointToLine(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        // Calculate the length of the line segment
        let lineLength = sqrt(dx * dx + dy * dy)
        
        // If the line segment is just a point, return the distance to that point
        if lineLength == 0 {
            return sqrt((point.x - lineStart.x) * (point.x - lineStart.x) + (point.y - lineStart.y) * (point.y - lineStart.y))
        }
        
        // Calculate the projection of the point onto the line
        let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (lineLength * lineLength)
        
        // If the projection is outside the line segment, return the distance to the nearest endpoint
        if t < 0 {
            return sqrt((point.x - lineStart.x) * (point.x - lineStart.x) + (point.y - lineStart.y) * (point.y - lineStart.y))
        }
        if t > 1 {
            return sqrt((point.x - lineEnd.x) * (point.x - lineEnd.x) + (point.y - lineEnd.y) * (point.y - lineEnd.y))
        }
        
        // Calculate the projection point
        let projectionX = lineStart.x + t * dx
        let projectionY = lineStart.y + t * dy
        
        // Return the distance from the point to the projection point
        return sqrt((point.x - projectionX) * (point.x - projectionX) + (point.y - projectionY) * (point.y - projectionY))
    }
}

// Animated path shapes
struct AnimatedLinePath: Shape {
    var start: CGPoint
    var end: CGPoint
    
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(start.animatableData, end.animatableData) }
        set { 
            start.animatableData = newValue.first
            end.animatableData = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

struct AnimatedCurvePath: Shape {
    var start: CGPoint
    var end: CGPoint
    
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(start.animatableData, end.animatableData) }
        set { 
            start.animatableData = newValue.first
            end.animatableData = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        
        // Calculate control points for the curve
        let dx = end.x - start.x
        let _ = end.y - start.y
        let midX = start.x + dx * 0.5
        
        // Create control points that curve outward
        let control1 = CGPoint(x: midX, y: start.y)
        let control2 = CGPoint(x: midX, y: end.y)
        
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }
}

struct TopicsCanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isRelationshipMode: Bool
    
    // State for temporary relationship line animation
    @State private var animatedTemporaryLineStart: CGPoint = .zero
    @State private var animatedTemporaryLineEnd: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // Draw all connection lines first (background layer)
            ConnectionLinesView(
                topics: viewModel.topics,
                onDeleteRelation: viewModel.removeRelation,
                selectedId: viewModel.selectedTopicId
            )
            
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
                onRelationDragEnded: viewModel.handleRelationDragEnded,
                isRelationshipMode: isRelationshipMode
            )
            
            // Draw temporary relation line if dragging
            if let (fromId, toPosition) = viewModel.relationDragState,
               let fromTopic = viewModel.findTopic(id: fromId) {
                // Check if target topic exists at the current position
                let _ = findTopicAt(position: toPosition, in: viewModel.topics)
                let points = calculateIntersection(from: fromTopic, toPosition: toPosition, topics: viewModel.topics)
                
                // Use curved style if the source topic has curved branch style
                let shouldUseCurvedStyle = fromTopic.branchStyle == .curved
                
                Group {
                    if shouldUseCurvedStyle {
                        // Animated curved path
                        AnimatedCurvePath(start: animatedTemporaryLineStart, end: animatedTemporaryLineEnd)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                    } else {
                        // Animated straight line
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
    let isRelationshipMode: Bool
    
    var body: some View {
        ZStack {
            // Draw all topics in order, ensuring proper z-index
            ForEach(topics) { topic in
                // Draw the topic with spring animations
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
                    },
                    isRelationshipMode: isRelationshipMode
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(topic.id == selectedId ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: topic.id == selectedId)
                
                // Draw subtopics for this topic only if not collapsed
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
                        isRelationshipMode: isRelationshipMode
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: !topic.isCollapsed)
                }
            }
        }
    }
}
