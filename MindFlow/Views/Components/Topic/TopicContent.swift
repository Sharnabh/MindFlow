//
//  TopicContent.swift
//  MindFlow
//
//  Created by Sharnabh on 01/04/25.
//

import SwiftUI

private struct TopicContent: View {
   var topic: Topic
   let isSelected: Bool
   @Binding var editingName: String
   @FocusState var isFocused: Bool
   let onNameChange: (String) -> Void
   let onEditingChange: (Bool) -> Void
   @State private var textHeight: CGFloat = 40
   
   private func calculateWidth() -> CGFloat {
       let text = topic.isEditing ? editingName : topic.name
       let lines = text.components(separatedBy: "\n")
       let maxLineLength = lines.map { $0.count }.max() ?? 0
       return max(120, CGFloat(maxLineLength * 10))
   }
   
   private func calculateHeight() -> CGFloat {
       let text = topic.isEditing ? editingName : topic.name
       let lineCount = text.components(separatedBy: "\n").count
       return max(40, CGFloat(lineCount * 24))
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
       let height = calculateHeight()
       
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
           .padding(.horizontal, 16)
           .padding(.vertical, 8)
           .frame(width: width, height: height)
           .background(
               createBackground()
                   .frame(width: width + 32, height: height)
           )
           .overlay(
               createBorder()
                   .frame(width: width + 32, height: height)
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
                   // Use dispatch async to ensure we don't conflict with the TextEditor's built-in behavior
                   DispatchQueue.main.async {
                       // Get the current selection to determine where to insert the newline
                       if let currentEditor = NSApp.keyWindow?.firstResponder as? NSTextView {
                           // Create an NSTextView operation instead of directly modifying the string
                           // This ensures proper undo registration and avoids duplicating newlines
                           let range = currentEditor.selectedRange()
                           currentEditor.insertText("\n", replacementRange: range)
                           
                           // Update the topic name with the editor text
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
       
       // Handle Undo/Redo commands
       NotificationCenter.default.addObserver(forName: NSNotification.Name("UndoRequested"), object: nil, queue: .main) { _ in
           if self.isFocused {
               // When editing text, let the system handle Cmd+Z for text undo
               // We don't need to do anything special here
           }
       }
       
       NotificationCenter.default.addObserver(forName: NSNotification.Name("RedoRequested"), object: nil, queue: .main) { _ in
           if self.isFocused {
               // When editing text, let the system handle Cmd+Shift+Z for text redo
               // We don't need to do anything special here
           }
       }
   }
   
   private func removeReturnKeyMonitor() {
       NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ReturnKeyPressed"), object: nil)
       NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UndoRequested"), object: nil)
       NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RedoRequested"), object: nil)
   }
   
   private func createTextDisplay() -> some View {
       let width = calculateWidth()
       let height = calculateHeight()
       
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
           .padding(.vertical, 8)
           .frame(width: width)
           .background(
               createBackground()
                   .frame(width: width + 32, height: height)
           )
           .overlay(
               createBorder()
                   .frame(width: width + 32, height: height)
           )
   }
   
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
