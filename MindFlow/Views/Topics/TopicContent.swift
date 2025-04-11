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
        .overlay {
            if isSelected {
                // Connection handles
                VStack {
                    // Top handle
                    Circle()
                        .fill(topic.borderColor)
                        .frame(width: 8, height: 8)
                        .offset(y: -4)
                    
                    Spacer()
                    
                    // Bottom handle
                    Circle()
                        .fill(topic.borderColor)
                        .frame(width: 8, height: 8)
                        .offset(y: 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                HStack {
                    // Left handle
                    Circle()
                        .fill(topic.borderColor)
                        .frame(width: 8, height: 8)
                        .offset(x: -4)
                    
                    Spacer()
                    
                    // Right handle
                    Circle()
                        .fill(topic.borderColor)
                        .frame(width: 8, height: 8)
                        .offset(x: 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Text Field Creation
    
    private func createTextField() -> some View {
        let size = calculateSize()
        
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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(width: size.width + 40, height: size.height + 24)
            .background(
                createBackground()
                    .frame(width: size.width + 40, height: size.height + 24)
            )
            .overlay(
                createBorder()
                    .frame(width: size.width + 40, height: size.height + 24)
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
        
        return Text(topic.textCase == .uppercase ? topic.name.uppercased() :
                   topic.textCase == .lowercase ? topic.name.lowercased() :
                   topic.textCase == .capitalize ? topic.name.capitalized :
                   topic.name)
            .foregroundColor(topic.foregroundColor.opacity(topic.foregroundOpacity))
            .font(getFontWithStyle())
            .strikethrough(topic.textStyles.contains(.strikethrough))
            .underline(topic.textStyles.contains(.underline))
            .multilineTextAlignment(topic.textAlignment == .left ? .leading : topic.textAlignment == .right ? .trailing : .center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: size.width, height: size.height + 16)
            .background(
                createBackground()
                    .frame(width: size.width + 32, height: size.height + 16)
            )
            .overlay(
                createBorder()
                    .frame(width: size.width + 32, height: size.height + 16)
            )
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
