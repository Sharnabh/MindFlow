import Foundation
import SwiftUI

// Note model for storing topic notes
struct Note: Identifiable, Equatable, Codable {
    let id: UUID
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isVisible: Bool
    
    init(id: UUID = UUID(), content: String = "", createdAt: Date = Date(), updatedAt: Date = Date(), isVisible: Bool = true) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isVisible = isVisible
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.isVisible == rhs.isVisible
    }
}

struct Topic: Identifiable, Equatable {
    enum Shape: Codable {
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
    
    enum BorderWidth: Double, CaseIterable, Codable {
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
    
    enum BranchStyle: String, CaseIterable, Codable {
        case `default` = "Default"
        case curved = "Curved"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    var id: UUID
    var name: String
    var position: CGPoint
    var parentId: UUID?
    var subtopics: [Topic]
    var isSelected: Bool
    var isEditing: Bool
    var isCollapsed: Bool
    var relations: [UUID] = []
    var shape: Shape
    var backgroundColor: Color
    var backgroundOpacity: Double
    var borderColor: Color
    var borderOpacity: Double
    var borderWidth: BorderWidth
    var branchStyle: BranchStyle = .default
    var note: Note? // Add note property to Topic
    
    // Text formatting properties
    var font: String = "System"
    var fontSize: CGFloat = 16
    var fontWeight: Font.Weight = .medium
    var foregroundColor: Color = .white
    var foregroundOpacity: Double = 1.0
    var textStyles: Set<TextStyle> = []
    var textCase: TextCase = .none
    var textAlignment: TextAlignment = .center
    
    // Add a static property to Topic to store theme colors
    static var themeColors: (backgroundColor: Color?, borderColor: Color?, foregroundColor: Color?) = (nil, nil, nil)
    
    // Additional metadata for the topic
    var metadata: [String: Any]? = nil
    
    // Template type for this topic and its descendants
    var templateType: TemplateType = .mindMap
    
    init(
        id: UUID = UUID(),
        name: String,
        position: CGPoint,
        parentId: UUID? = nil,
        subtopics: [Topic] = [],
        isSelected: Bool = false,
        isEditing: Bool = false,
        isCollapsed: Bool = false,
        relations: [UUID] = [],
        shape: Shape = .roundedRectangle,
        backgroundColor: Color = .blue,
        backgroundOpacity: Double = 1.0,
        borderColor: Color = .blue,
        borderOpacity: Double = 1.0,
        borderWidth: BorderWidth = .medium,
        branchStyle: BranchStyle = .default,
        font: String = "System",
        fontSize: CGFloat = 16,
        fontWeight: Font.Weight = .medium,
        foregroundColor: Color = .white,
        foregroundOpacity: Double = 1.0,
        textStyles: Set<TextStyle> = [],
        textCase: TextCase = .none,
        textAlignment: TextAlignment = .center,
        note: Note? = nil,
        metadata: [String: Any]? = nil,
        templateType: TemplateType = .mindMap
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.parentId = parentId
        self.subtopics = subtopics
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.isCollapsed = isCollapsed
        self.relations = relations
        self.shape = shape
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.borderColor = borderColor
        self.borderOpacity = borderOpacity
        self.borderWidth = borderWidth
        self.branchStyle = branchStyle
        self.font = font
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        self.foregroundOpacity = foregroundOpacity
        self.textStyles = textStyles
        self.textCase = textCase
        self.textAlignment = textAlignment
        self.note = note
        self.metadata = metadata
        self.templateType = templateType
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
        lhs.isCollapsed == rhs.isCollapsed &&
        lhs.relations == rhs.relations &&
        lhs.shape == rhs.shape &&
        lhs.backgroundColor == rhs.backgroundColor &&
        lhs.backgroundOpacity == rhs.backgroundOpacity &&
        lhs.borderColor == rhs.borderColor &&
        lhs.borderOpacity == rhs.borderOpacity &&
        lhs.borderWidth == rhs.borderWidth &&
        lhs.branchStyle == rhs.branchStyle &&
        lhs.font == rhs.font &&
        lhs.fontSize == rhs.fontSize &&
        lhs.fontWeight == rhs.fontWeight &&
        lhs.foregroundColor == rhs.foregroundColor &&
        lhs.foregroundOpacity == rhs.foregroundOpacity &&
        lhs.textStyles == rhs.textStyles &&
        lhs.textCase == rhs.textCase &&
        lhs.textAlignment == rhs.textAlignment &&
        lhs.note == rhs.note &&
        // Compare metadata by checking if both are nil or both have the same count
        ((lhs.metadata == nil && rhs.metadata == nil) || 
         (lhs.metadata?.count == rhs.metadata?.count)) &&
        lhs.templateType == rhs.templateType
    }
}

extension Topic {
    static func createMainTopic(at position: CGPoint, count: Int, templateType: TemplateType = .mindMap) -> Topic {
        Topic(
            name: "Main Topic \(count)",
            position: position,
            templateType: templateType
        )
    }
    
    func createSubtopic(at position: CGPoint, count: Int) -> Topic {
        // First check if theme colors are set, if not use parent's colors
        let backgroundColor = Topic.themeColors.backgroundColor ?? self.backgroundColor
        let borderColor = Topic.themeColors.borderColor ?? self.borderColor
        let foregroundColor = Topic.themeColors.foregroundColor ?? self.foregroundColor
        
        return Topic(
            name: "Subtopic \(count)",
            position: position,
            parentId: self.id,
            backgroundColor: backgroundColor,
            backgroundOpacity: self.backgroundOpacity,
            borderColor: borderColor,
            borderOpacity: self.borderOpacity,
            borderWidth: self.borderWidth,
            branchStyle: self.branchStyle,
            foregroundColor: foregroundColor,
            foregroundOpacity: self.foregroundOpacity,
            templateType: self.templateType // Inherit template type from parent
        )
    }
    
    mutating func addRelation(_ topicId: UUID) {
        // Don't add if it's already a relation or if it's self
        if !relations.contains(topicId) && topicId != self.id {
            relations.append(topicId)
        }
    }
    
    mutating func removeRelation(_ topicId: UUID) {
        relations.removeAll(where: { $0 == topicId })
    }
    
    /// Creates a deep copy of the Topic, including all of its subtopics
    func deepCopy() -> Topic {
        var copy = Topic(
            id: self.id,
            name: self.name,
            position: self.position,
            parentId: self.parentId,
            subtopics: [],
            isSelected: self.isSelected,
            isEditing: self.isEditing,
            isCollapsed: self.isCollapsed,
            relations: self.relations, // Preserve relations
            shape: self.shape,
            backgroundColor: self.backgroundColor,
            backgroundOpacity: self.backgroundOpacity,
            borderColor: self.borderColor,
            borderOpacity: self.borderOpacity,
            borderWidth: self.borderWidth,
            branchStyle: self.branchStyle,
            font: self.font,
            fontSize: self.fontSize,
            fontWeight: self.fontWeight,
            foregroundColor: self.foregroundColor,
            foregroundOpacity: self.foregroundOpacity,
            textStyles: self.textStyles,
            textCase: self.textCase,
            textAlignment: self.textAlignment,
            note: self.note,
            metadata: self.metadata,
            templateType: self.templateType
        )
        
        // Recursively copy subtopics
        copy.subtopics = self.subtopics.map { $0.deepCopy() }
        
        return copy
    }
} 