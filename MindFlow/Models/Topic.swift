import Foundation
import SwiftUI

struct Topic: Identifiable, Equatable, Codable, Hashable {
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
    
    let id: UUID
    var name: String
    var position: CGPoint
    var size: CGSize
    var parentId: UUID?
    var subtopics: [Topic]
    var isSelected: Bool
    var isEditing: Bool
    var isCollapsed: Bool
    var relations: [Topic]
    var shape: Shape
    var backgroundColor: Color
    var backgroundOpacity: Double
    var borderColor: Color
    var borderOpacity: Double
    var borderWidth: BorderWidth
    var branchStyle: BranchStyle = .default
    var rotation: CGFloat = 0
    
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
    
    init(
        id: UUID = UUID(),
        name: String,
        position: CGPoint,
        size: CGSize = CGSize(width: 200, height: 100),
        parentId: UUID? = nil,
        subtopics: [Topic] = [],
        isSelected: Bool = false,
        isEditing: Bool = false,
        isCollapsed: Bool = false,
        relations: [Topic] = [],
        shape: Shape = .roundedRectangle,
        backgroundColor: Color = .white,
        backgroundOpacity: Double = 1.0,
        borderColor: Color = .black,
        borderOpacity: Double = 1.0,
        borderWidth: BorderWidth = .medium,
        branchStyle: BranchStyle = .default,
        font: String = "System",
        fontSize: CGFloat = 16,
        fontWeight: Font.Weight = .medium,
        foregroundColor: Color = .black,
        foregroundOpacity: Double = 1.0,
        textStyles: Set<TextStyle> = [],
        textCase: TextCase = .none,
        textAlignment: TextAlignment = .center
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.size = size
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
        lhs.textAlignment == rhs.textAlignment
    }
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
            foregroundOpacity: self.foregroundOpacity
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
    
    /// Creates a deep copy of the Topic, including all of its subtopics
    func deepCopy() -> Topic {
        var copy = Topic(
            id: self.id,
            name: self.name,
            position: self.position,
            size: self.size,
            parentId: self.parentId,
            subtopics: [],
            isSelected: self.isSelected,
            isEditing: self.isEditing,
            isCollapsed: self.isCollapsed,
            relations: [], // Initialize with empty relations
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
            textAlignment: self.textAlignment
        )
        
        // Recursively copy subtopics
        copy.subtopics = self.subtopics.map { $0.deepCopy() }
        
        // Skip copying relations entirely to prevent circular references during serialization
        
        return copy
    }
}

// MARK: - Codable Implementation
extension Topic {
    enum CodingKeys: String, CodingKey {
        case id, name, position, size, parentId, subtopics, isSelected, isEditing, isCollapsed
        case relations, shape, backgroundComponents, backgroundOpacity, borderComponents, borderOpacity
        case borderWidth, branchStyle, rotation, font, fontSize, fontWeightRaw, foregroundComponents
        case foregroundOpacity, textStyles, textCase, textAlignment
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
        try container.encode(parentId, forKey: .parentId)
        try container.encode(subtopics, forKey: .subtopics)
        try container.encode(isSelected, forKey: .isSelected)
        try container.encode(isEditing, forKey: .isEditing)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        try container.encode(relations, forKey: .relations)
        try container.encode(shape, forKey: .shape)
        
        // Encode Color properties as ColorComponents
        try container.encode(backgroundColor.toComponents(), forKey: .backgroundComponents)
        try container.encode(backgroundOpacity, forKey: .backgroundOpacity)
        try container.encode(borderColor.toComponents(), forKey: .borderComponents)
        try container.encode(borderOpacity, forKey: .borderOpacity)
        
        try container.encode(borderWidth, forKey: .borderWidth)
        try container.encode(branchStyle, forKey: .branchStyle)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(font, forKey: .font)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(fontWeight.rawValue, forKey: .fontWeightRaw)
        
        try container.encode(foregroundColor.toComponents(), forKey: .foregroundComponents)
        try container.encode(foregroundOpacity, forKey: .foregroundOpacity)
        try container.encode(textStyles, forKey: .textStyles)
        try container.encode(textCase, forKey: .textCase)
        try container.encode(textAlignment, forKey: .textAlignment)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        subtopics = try container.decode([Topic].self, forKey: .subtopics)
        isSelected = try container.decode(Bool.self, forKey: .isSelected)
        isEditing = try container.decode(Bool.self, forKey: .isEditing)
        isCollapsed = try container.decode(Bool.self, forKey: .isCollapsed)
        relations = try container.decode([Topic].self, forKey: .relations)
        shape = try container.decode(Shape.self, forKey: .shape)
        
        // Decode Color properties from ColorComponents
        let bgComponents = try container.decode(ColorComponents.self, forKey: .backgroundComponents)
        backgroundColor = Color(.sRGB, red: bgComponents.red, green: bgComponents.green, blue: bgComponents.blue, opacity: bgComponents.opacity)
        backgroundOpacity = try container.decode(Double.self, forKey: .backgroundOpacity)
        
        let borderComponents = try container.decode(ColorComponents.self, forKey: .borderComponents)
        borderColor = Color(.sRGB, red: borderComponents.red, green: borderComponents.green, blue: borderComponents.blue, opacity: borderComponents.opacity)
        borderOpacity = try container.decode(Double.self, forKey: .borderOpacity)
        
        borderWidth = try container.decode(BorderWidth.self, forKey: .borderWidth)
        branchStyle = try container.decode(BranchStyle.self, forKey: .branchStyle)
        rotation = try container.decode(CGFloat.self, forKey: .rotation)
        font = try container.decode(String.self, forKey: .font)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        
        let fontWeightRawValue = try container.decode(Int.self, forKey: .fontWeightRaw)
        switch fontWeightRawValue {
        case 0: fontWeight = .thin
        case 1: fontWeight = .ultraLight
        case 2: fontWeight = .light
        case 3: fontWeight = .regular
        case 4: fontWeight = .medium
        case 5: fontWeight = .semibold
        case 6: fontWeight = .bold
        case 7: fontWeight = .heavy
        default: fontWeight = .regular
        }
        
        let foregroundComponents = try container.decode(ColorComponents.self, forKey: .foregroundComponents)
        foregroundColor = Color(.sRGB, red: foregroundComponents.red, green: foregroundComponents.green, blue: foregroundComponents.blue, opacity: foregroundComponents.opacity)
        foregroundOpacity = try container.decode(Double.self, forKey: .foregroundOpacity)
        
        textStyles = try container.decode(Set<TextStyle>.self, forKey: .textStyles)
        textCase = try container.decode(TextCase.self, forKey: .textCase)
        textAlignment = try container.decode(TextAlignment.self, forKey: .textAlignment)
    }
} 