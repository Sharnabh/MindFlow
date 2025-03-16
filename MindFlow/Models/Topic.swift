import Foundation
import SwiftUI

struct Topic: Identifiable, Equatable {
    enum Shape {
        case rectangle
        case roundedRectangle
        case circle
        case roundedSquare
        case line
        case diamond
        case hexagon
        case octagon
        case parallelogram
        case cloud
        case heart
        case shield
        case star
        case document
        case doubleRectangle
        case flag
        case leftArrow
        case rightArrow
    }
    
    enum BorderWidth: Double, CaseIterable {
        case none = 0
        case extraThin = 0.5
        case thin = 1
        case medium = 2
        case bold = 3
        case extraBold = 4
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .extraThin: return "Extra Thin"
            case .thin: return "Thin"
            case .medium: return "Medium"
            case .bold: return "Bold"
            case .extraBold: return "Extra Bold"
            }
        }
    }
    
    let id: UUID
    var name: String
    var position: CGPoint
    var parentId: UUID?
    var subtopics: [Topic]
    var isSelected: Bool
    var isEditing: Bool
    var relations: [Topic]
    var shape: Shape
    var backgroundColor: Color
    var backgroundOpacity: Double
    var borderColor: Color
    var borderOpacity: Double
    var borderWidth: BorderWidth
    
    // Text formatting properties
    var font: String = "System"
    var fontSize: CGFloat = 16
    var fontWeight: Font.Weight = .medium
    var foregroundColor: Color = .white
    var foregroundOpacity: Double = 1.0
    var textStyles: Set<TextStyle> = []
    var textCase: TextCase = .none
    var textAlignment: TextAlignment = .center
    
    init(
        id: UUID = UUID(),
        name: String,
        position: CGPoint,
        parentId: UUID? = nil,
        subtopics: [Topic] = [],
        isSelected: Bool = false,
        isEditing: Bool = false,
        relations: [Topic] = [],
        shape: Shape = .roundedRectangle,
        backgroundColor: Color = .blue,
        backgroundOpacity: Double = 1.0,
        borderColor: Color = .blue,
        borderOpacity: Double = 1.0,
        borderWidth: BorderWidth = .medium,
        font: String = "System",
        fontSize: CGFloat = 16,
        fontWeight: Font.Weight = .medium,
        foregroundColor: Color = .white,
        foregroundOpacity: Double = 1.0,
        textStyles: Set<TextStyle> = [],
        textCase: TextCase = .none,
        textAlignment: TextAlignment = .center
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.parentId = parentId
        self.subtopics = subtopics
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.relations = relations
        self.shape = shape
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.borderColor = borderColor
        self.borderOpacity = borderOpacity
        self.borderWidth = borderWidth
        self.font = font
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        self.foregroundOpacity = foregroundOpacity
        self.textStyles = textStyles
        self.textCase = textCase
        self.textAlignment = textAlignment
    }
    
    // Implement Equatable
    static func == (lhs: Topic, rhs: Topic) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.position == rhs.position &&
        lhs.parentId == rhs.parentId &&
        lhs.subtopics == rhs.subtopics &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isEditing == rhs.isEditing &&
        lhs.relations == rhs.relations &&
        lhs.shape == rhs.shape &&
        lhs.backgroundColor == rhs.backgroundColor &&
        lhs.backgroundOpacity == rhs.backgroundOpacity &&
        lhs.borderColor == rhs.borderColor &&
        lhs.borderOpacity == rhs.borderOpacity &&
        lhs.borderWidth == rhs.borderWidth &&
        lhs.font == rhs.font &&
        lhs.fontSize == rhs.fontSize &&
        lhs.fontWeight == rhs.fontWeight &&
        lhs.foregroundColor == rhs.foregroundColor &&
        lhs.foregroundOpacity == rhs.foregroundOpacity &&
        lhs.textStyles == rhs.textStyles &&
        lhs.textCase == rhs.textCase &&
        lhs.textAlignment == rhs.textAlignment
    }
}

extension Topic {
    static func createMainTopic(at position: CGPoint, count: Int) -> Topic {
        Topic(
            name: "Main Topic \(count)",
            position: position
        )
    }
    
    func createSubtopic(at position: CGPoint, count: Int) -> Topic {
        Topic(
            name: "Subtopic \(count)",
            position: position,
            parentId: self.id,
            backgroundColor: self.backgroundColor,
            backgroundOpacity: self.backgroundOpacity,
            borderColor: self.borderColor,
            borderOpacity: self.borderOpacity
        )
    }
    
    mutating func addRelation(_ topic: Topic) {
        // Don't add if it's already a relation or if it's self
        if !relations.contains(where: { $0.id == topic.id }) && topic.id != self.id {
            relations.append(topic)
        }
    }
    
    mutating func removeRelation(_ topicId: UUID) {
        relations.removeAll(where: { $0.id == topicId })
    }
} 