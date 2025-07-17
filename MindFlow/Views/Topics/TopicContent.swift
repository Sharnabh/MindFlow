//
//  TopicContent.swift
//  MindFlow
//
//  Created by Sharnabh on 08/04/25.
//

import SwiftUI

/// A view that displays and manages the content of a topic, including its text, shape, and styling.
struct TopicContent: View {
    // MARK: - Properties
    
    var topic: Topic
    let isSelected: Bool
    @Binding var editingName: String
    @FocusState var isFocused: Bool
    let onNameChange: (String) -> Void
    let onEditingChange: (Bool) -> Void
    @ObservedObject var viewModel: CanvasViewModel
    
    // MARK: - Private Properties
    
    @State private var textHeight: CGFloat = 40
    
    // MARK: - Size Calculation
    
    /// Calculates the size needed for the topic content based on text and font properties
    private func calculateSize() -> (width: CGFloat, height: CGFloat) {
        let text = topic.isEditing ? editingName : topic.name
        
        // Get shape constraints
        let maxCharsPerLine = getMaxCharactersPerLine()
        let fontSizeScaleFactor = max(1.0, topic.fontSize / 14.0)
        
        // Perform intelligent text wrapping
        let wrappedText = wrapTextForShape(text: text, maxCharsPerLine: maxCharsPerLine)
        let lines = wrappedText.components(separatedBy: "\n")
        
        // Calculate dimensions based on wrapped text
        let maxLineLength = lines.map { $0.count }.max() ?? 0
        let baseWidth = max(120, CGFloat(maxLineLength * 10) * fontSizeScaleFactor)
        
        // Scale line height based on font size and total lines
        let lineHeight = max(24, topic.fontSize * 1.5)
        let baseHeight = max(40, CGFloat(lines.count) * lineHeight)
        
        // Apply shape-specific adjustments for better text fit
        let (width, height) = adjustSizeForShape(baseWidth: baseWidth, baseHeight: baseHeight)
        
        return (width, height)
    }
    
    /// Intelligently wraps text based on shape constraints and word boundaries
    private func wrapTextForShape(text: String, maxCharsPerLine: Int) -> String {
        let lines = text.components(separatedBy: "\n")
        var wrappedLines: [String] = []
        
        for line in lines {
            if line.count <= maxCharsPerLine {
                wrappedLines.append(line)
            } else {
                // Need to wrap this line
                let wrappedLineSegments = wrapLine(line: line, maxCharsPerLine: maxCharsPerLine)
                wrappedLines.append(contentsOf: wrappedLineSegments)
            }
        }
        
        return wrappedLines.joined(separator: "\n")
    }
    
    /// Wraps a single line respecting word boundaries when possible
    private func wrapLine(line: String, maxCharsPerLine: Int) -> [String] {
        var result: [String] = []
        var currentLine = ""
        let words = line.components(separatedBy: " ")
        
        for word in words {
            let potentialLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            
            if potentialLine.count <= maxCharsPerLine {
                currentLine = potentialLine
            } else {
                // Current word won't fit, start new line
                if !currentLine.isEmpty {
                    result.append(currentLine)
                    currentLine = word
                } else {
                    // Single word is too long, force break it
                    if word.count > maxCharsPerLine {
                        let brokenWords = forceBreakWord(word: word, maxCharsPerLine: maxCharsPerLine)
                        result.append(contentsOf: brokenWords.dropLast())
                        currentLine = brokenWords.last ?? ""
                    } else {
                        currentLine = word
                    }
                }
            }
        }
        
        if !currentLine.isEmpty {
            result.append(currentLine)
        }
        
        return result.isEmpty ? [""] : result
    }
    
    /// Force breaks a word that's too long for a single line
    private func forceBreakWord(word: String, maxCharsPerLine: Int) -> [String] {
        var result: [String] = []
        var remaining = word
        
        while remaining.count > maxCharsPerLine {
            let endIndex = remaining.index(remaining.startIndex, offsetBy: maxCharsPerLine)
            let chunk = String(remaining[remaining.startIndex..<endIndex])
            result.append(chunk)
            remaining = String(remaining[endIndex...])
        }
        
        if !remaining.isEmpty {
            result.append(remaining)
        }
        
        return result
    }
    
    /// Returns the maximum characters per line based on the shape to encourage text wrapping
    private func getMaxCharactersPerLine() -> Int {
        // Base character count, then adjust for shape constraints
        let baseFontCharWidth = max(8, topic.fontSize * 0.6) // Rough character width estimation
        let shapeConstraints = getShapeConstraints()
        
        // Calculate max characters based on usable width
        let maxChars = Int(shapeConstraints.usableWidth / baseFontCharWidth)
        
        return max(10, min(maxChars, shapeConstraints.maxCharLimit))
    }
    
    /// Returns shape-specific constraints for text layout
    private func getShapeConstraints() -> (usableWidth: CGFloat, maxCharLimit: Int) {
        switch topic.shape {
        case .hexagon, .octagon:
            // Polygonal shapes: usable area is roughly 70% of total width at the center
            return (usableWidth: 140, maxCharLimit: 20)
        case .diamond:
            // Diamond shape: usable area is roughly 50% of total width at the center
            return (usableWidth: 100, maxCharLimit: 15)
        case .circle:
            // Circular shapes: usable area is roughly 80% of total width at the center
            return (usableWidth: 160, maxCharLimit: 22)
        case .parallelogram:
            // Parallelogram: slightly reduced due to slanted sides
            return (usableWidth: 200, maxCharLimit: 30)
        case .star:
            // Star shape: very limited usable area due to points
            return (usableWidth: 120, maxCharLimit: 18)
        case .heart, .cloud, .shield:
            // Organic shapes: variable but generally constrained
            return (usableWidth: 180, maxCharLimit: 25)
        case .leftArrow, .rightArrow:
            // Arrow shapes: good width in body, constrained by arrow head
            return (usableWidth: 240, maxCharLimit: 35)
        case .flag:
            // Flag shape: constrained by pole and flag geometry
            return (usableWidth: 200, maxCharLimit: 30)
        case .document:
            // Document shape: mostly rectangular with small fold
            return (usableWidth: 280, maxCharLimit: 40)
        default:
            // Rectangle-based shapes: full width available
            return (usableWidth: 320, maxCharLimit: 45)
        }
    }
    
    /// Adjusts the calculated size based on the topic's shape to ensure text fits properly
    private func adjustSizeForShape(baseWidth: CGFloat, baseHeight: CGFloat) -> (width: CGFloat, height: CGFloat) {
        switch topic.shape {
        case .hexagon, .octagon:
            // Polygonal shapes need significantly more space due to angled edges - increased multipliers
            return (baseWidth * 1.8, baseHeight * 1.6)
        case .diamond:
            // Diamond shape needs the most space due to pointed corners
            return (baseWidth * 2.0, baseHeight * 1.8)
        case .circle:
            // Circular shapes need more space to account for curved edges
            return (baseWidth * 1.5, baseHeight * 1.4)
        case .parallelogram:
            // Parallelogram needs extra width due to slanted sides
            return (baseWidth * 1.5, baseHeight * 1.2)
        case .star:
            // Star shape needs more space due to pointed edges
            return (baseWidth * 1.7, baseHeight * 1.6)
        case .heart, .cloud, .shield:
            // Organic shapes need extra space for irregular boundaries
            return (baseWidth * 1.6, baseHeight * 1.5)
        case .leftArrow, .rightArrow:
            // Arrow shapes need extra width for the arrow head
            return (baseWidth * 1.6, baseHeight * 1.2)
        case .flag:
            // Flag shape needs extra space for the flag portion
            return (baseWidth * 1.5, baseHeight * 1.2)
        case .document:
            // Document shape is fairly rectangular, minimal adjustment
            return (baseWidth * 1.2, baseHeight * 1.1)
        default:
            // Rectangle-based shapes (rectangle, rounded rectangle, etc.) work well with base sizing
            return (baseWidth, baseHeight)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Recursively counts all descendants of a topic
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
    
    /// Creates a font with the appropriate style based on topic properties
    private func getFontWithStyle() -> Font {
        // Start with base font
        var font = Font.custom(topic.font, size: topic.fontSize, relativeTo: .body)
        
        // Apply italic
        if topic.textStyles.contains(.italic) {
            font = font.italic()
        }
        
        // Apply weight - use bold from text styles if present, otherwise use the selected weight
        if topic.textStyles.contains(.bold) {
            font = font.weight(.bold)
        } else {
            font = font.weight(topic.fontWeight)
        }
        
        return font
    }
    
    // MARK: - View Body
    
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
        .overlay(alignment: .topLeading) {
            // Note indicator
            if viewModel.topicHasNote(topic) {
                Button(action: {
                    // Open note editor for this topic
                    viewModel.showingNoteEditorForTopicId = topic.id
                    if let note = topic.note {
                        viewModel.currentNoteContent = note.content
                        viewModel.isEditingNote = true
                    }
                }) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .padding(4)
                        .background(Circle().fill(Color.white.opacity(0.7)))
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: -8, y: -8)
            }
            
            // Note editor popover
            if viewModel.showingNoteEditorForTopicId == topic.id && viewModel.isEditingNote {
                NoteEditorPopover(viewModel: viewModel, topicId: topic.id)
                    .offset(x: 30, y: 30)
            }
        }
    }
    
    // MARK: - Text Field Creation
    
    private func createTextField() -> some View {
        let size = calculateSize()
        let padding = getPaddingForShape()
        let maxWidth = size.width - (padding.horizontal * 2)
        
        return TextEditor(text: $editingName)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .foregroundColor(topic.foregroundColor.opacity(topic.foregroundOpacity))
            .font(getFontWithStyle())
            .strikethrough(topic.textStyles.contains(.strikethrough))
            .underline(topic.textStyles.contains(.underline))
            .textCase(topic.textCase == .uppercase ? .uppercase :
                     topic.textCase == .lowercase ? .lowercase :
                     nil)
            .multilineTextAlignment(topic.textAlignment == .left ? .leading : topic.textAlignment == .right ? .trailing : .center)
            .padding(.horizontal, padding.horizontal + 4) // Extra padding for text editing
            .padding(.vertical, padding.vertical + 4)
            .frame(width: size.width + (padding.horizontal + 4) * 2, height: size.height + (padding.vertical + 4) * 2)
            .background(
                createBackground()
                    .frame(width: size.width + (padding.horizontal + 4) * 2, height: size.height + (padding.vertical + 4) * 2)
            )
            .overlay(
                createBorder()
                    .frame(width: size.width + (padding.horizontal + 4) * 2, height: size.height + (padding.vertical + 4) * 2)
            )
            .focused($isFocused)
            .onChange(of: editingName) { oldValue, newValue in
                onNameChange(newValue)
            }
            .onChange(of: isFocused) { oldValue, newValue in
                viewModel.isTextInputActive = newValue
            }
            .onExitCommand {
                isFocused = false
                onEditingChange(false)
            }
            .onAppear {
                setupReturnKeyMonitor()
            }
            .onDisappear {
                removeReturnKeyMonitor()
            }
    }
    
    // MARK: - Text Display Creation
    
    private func createTextDisplay() -> some View {
        let size = calculateSize()
        let padding = getPaddingForShape()
        let maxWidth = size.width - (padding.horizontal * 2)
        
        // Get the wrapped text for display
        let originalText = topic.textCase == .uppercase ? topic.name.uppercased() :
                          topic.textCase == .lowercase ? topic.name.lowercased() :
                          topic.textCase == .capitalize ? topic.name.capitalized :
                          topic.name
        
        let maxCharsPerLine = getMaxCharactersPerLine()
        let wrappedText = wrapTextForShape(text: originalText, maxCharsPerLine: maxCharsPerLine)
        
        return Text(wrappedText)
            .foregroundColor(topic.foregroundColor.opacity(topic.foregroundOpacity))
            .font(getFontWithStyle())
            .strikethrough(topic.textStyles.contains(.strikethrough))
            .underline(topic.textStyles.contains(.underline))
            .multilineTextAlignment(topic.textAlignment == .left ? .leading : topic.textAlignment == .right ? .trailing : .center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: maxWidth) // Constrain text width to force wrapping
            .padding(.horizontal, padding.horizontal)
            .padding(.vertical, padding.vertical)
            .frame(width: size.width + padding.horizontal * 2, height: size.height + padding.vertical * 2)
            .background(
                createBackground()
                    .frame(width: size.width + padding.horizontal * 2, height: size.height + padding.vertical * 2)
            )
            .overlay(
                createBorder()
                    .frame(width: size.width + padding.horizontal * 2, height: size.height + padding.vertical * 2)
            )
    }
    
    /// Returns appropriate padding values for different shapes
    private func getPaddingForShape() -> (horizontal: CGFloat, vertical: CGFloat) {
        switch topic.shape {
        case .hexagon, .octagon:
            // Polygonal shapes need more padding due to angled edges - increased values
            return (32, 28)
        case .diamond:
            // Diamond shape needs significant padding due to pointed corners
            return (40, 32)
        case .circle:
            // Circular shapes need generous padding for curved edges
            return (28, 24)
        case .parallelogram:
            // Parallelogram needs extra horizontal padding for slanted sides
            return (32, 16)
        case .star:
            // Star shape needs extra padding for pointed edges
            return (36, 28)
        case .heart, .cloud, .shield:
            // Organic shapes need extra padding for irregular boundaries
            return (32, 24)
        case .leftArrow, .rightArrow:
            // Arrow shapes need extra horizontal padding for arrow head
            return (36, 16)
        case .flag:
            // Flag shape needs padding for flag portion
            return (28, 16)
        case .document:
            // Document shape works well with standard padding
            return (24, 16)
        default:
            // Rectangle-based shapes use standard padding
            return (16, 12)
        }
    }
    
    // MARK: - Background Creation
    
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
    
    // MARK: - Border Creation
    
    private func createBorder() -> some View {
        Group {
            switch topic.shape {
            case .rectangle:
                Rectangle()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .circle:
                Capsule()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .roundedSquare:
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .line:
                Rectangle()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .frame(height: 2)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .diamond:
                Diamond()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .hexagon:
                RegularPolygon(sides: 6)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .octagon:
                RegularPolygon(sides: 8)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .parallelogram:
                Parallelogram()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .cloud:
                Cloud()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .heart:
                Heart()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .shield:
                Shield()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .star:
                Star()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .document:
                Document()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .doubleRectangle:
                DoubleRectangle()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .flag:
                Flag()
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .leftArrow:
                Arrow(pointing: .left)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            case .rightArrow:
                Arrow(pointing: .right)
                    .stroke(isSelected ? topic.borderColor : topic.borderColor.opacity(topic.borderOpacity), lineWidth: topic.borderWidth.rawValue)
                    .shapeAwareSelectionGlow(isSelected: isSelected, color: topic.borderColor, shape: topic.shape)
            }
        }
    }
    
    // MARK: - Keyboard Handling
    
    private func setupReturnKeyMonitor() {
        // Handle Return key
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ReturnKeyPressed"), object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let event = userInfo["event"] as? NSEvent,
               event.keyCode == 36, // Return key
               self.isFocused {
                
                if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command) {
                    // Shift+Return or Command+Return: add a new line
                    DispatchQueue.main.async {
                        if let currentEditor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            let range = currentEditor.selectedRange()
                            currentEditor.insertText("\n", replacementRange: range)
                            
                            if let updatedText = currentEditor.string as String? {
                                self.editingName = updatedText
                                self.onNameChange(updatedText)
                            }
                        } else {
                            self.editingName += "\n"
                            self.onNameChange(self.editingName)
                        }
                    }
                } else {
                    // Regular Return: commit changes without adding a new line
                    DispatchQueue.main.async {
                        self.onNameChange(self.editingName.trimmingCharacters(in: .whitespacesAndNewlines))
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
}

// MARK: - Note Editor Popover

struct NoteEditorPopover: View {
    @ObservedObject var viewModel: CanvasViewModel
    let topicId: UUID
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Topic Note")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.saveNote()
                    viewModel.showingNoteEditorForTopicId = nil
                    viewModel.isEditingNote = false
                }) {
                    Text("Save")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button(action: {
                    viewModel.deleteNoteFromSelectedTopic()
                    viewModel.showingNoteEditorForTopicId = nil
                    viewModel.isEditingNote = false
                }) {
                    Text("Delete")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: {
                    viewModel.showingNoteEditorForTopicId = nil
                    viewModel.isEditingNote = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            TextEditor(text: $viewModel.currentNoteContent)
                .font(.body)
                .padding(8)
                .frame(width: 300, height: 200)
                .overlay(
                    Group {
                        if viewModel.currentNoteContent.isEmpty {
                            Text("Enter note text here...")
                                .foregroundColor(.gray)
                                .padding(16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
                )
                .onChange(of: viewModel.currentNoteContent) { _, _ in
                    // Auto-save as content changes without closing the editor
                    viewModel.autoSaveCurrentNote()
                }
        }
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        )
        .onAppear {
            // Make sure the selected topic is the one we're editing notes for
            viewModel.selectedTopicId = topicId
        }
        .onDisappear {
            // Final save on disappear
            viewModel.saveNote()
            // Clean up and reset state
            viewModel.isEditingNote = false
            viewModel.showingNoteEditorForTopicId = nil
        }
    }
}

// MARK: - Shape-Aware Selection Glow Extension

extension View {
    @ViewBuilder func shapeAwareSelectionGlow(isSelected: Bool, color: Color, shape: Topic.Shape) -> some View {
        self
            .shadow(color: isSelected ? color.opacity(0.9) : .clear, radius: 4, x: 0, y: 0)
            .overlay(
                ZStack {
                    if isSelected {
                        Group {
                            switch shape {
                            case .rectangle:
                                Rectangle()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .roundedRectangle:
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .circle:
                                Capsule()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .roundedSquare:
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .line:
                                Rectangle()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                                    .frame(height: 2)
                            case .diamond:
                                Diamond()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .hexagon:
                                RegularPolygon(sides: 6)
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .octagon:
                                RegularPolygon(sides: 8)
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .parallelogram:
                                Parallelogram()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .cloud:
                                Cloud()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .heart:
                                Heart()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .shield:
                                Shield()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .star:
                                Star()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .document:
                                Document()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .doubleRectangle:
                                DoubleRectangle()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .flag:
                                Flag()
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .leftArrow:
                                Arrow(pointing: .left)
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            case .rightArrow:
                                Arrow(pointing: .right)
                                    .stroke(color.opacity(0.6), lineWidth: 2)
                            }
                        }
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
