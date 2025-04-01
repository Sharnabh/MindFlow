import SwiftUI
import AppKit

class TopicContentViewModel: ObservableObject {
    @Published var editingName: String
    @Published var isFocused: Bool = false
    @Published var textHeight: CGFloat = 40
    
    let topic: Topic
    let isSelected: Bool
    let onNameChange: (String) -> Void
    let onEditingChange: (Bool) -> Void
    
    init(topic: Topic, isSelected: Bool, editingName: String, onNameChange: @escaping (String) -> Void, onEditingChange: @escaping (Bool) -> Void) {
        self.topic = topic
        self.isSelected = isSelected
        self.editingName = editingName
        self.onNameChange = onNameChange
        self.onEditingChange = onEditingChange
        setupObservers()
    }
    
    private func setupObservers() {
        // Handle Return key
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ReturnKeyPressed"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let event = userInfo["event"] as? NSEvent,
                  event.keyCode == 36, // Return key
                  self.isFocused else { return }
            
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
                // Regular Return: commit changes
                DispatchQueue.main.async {
                    self.onNameChange(self.editingName)
                    self.isFocused = false
                    self.onEditingChange(false)
                }
            }
        }
    }
    
    func calculateWidth() -> CGFloat {
        let text = topic.isEditing ? editingName : topic.name
        let lines = text.components(separatedBy: "\n")
        let maxLineLength = lines.map { $0.count }.max() ?? 0
        return max(120, CGFloat(maxLineLength * 10))
    }
    
    func calculateHeight() -> CGFloat {
        let text = topic.isEditing ? editingName : topic.name
        let lineCount = text.components(separatedBy: "\n").count
        return max(40, CGFloat(lineCount * 24))
    }
    
    func getFontWithStyle() -> Font {
        var font = Font.custom(topic.font, size: topic.fontSize, relativeTo: .body)
        
        if topic.textStyles.contains(.italic) {
            font = font.italic()
        }
        
        if topic.textStyles.contains(.bold) {
            font = font.weight(.bold)
        } else {
            font = font.weight(topic.fontWeight)
        }
        
        return font
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 