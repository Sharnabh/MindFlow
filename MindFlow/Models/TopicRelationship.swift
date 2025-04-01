import SwiftUI

struct TopicRelationship: Identifiable, Equatable {
    let id: UUID
    let sourceId: UUID
    let targetId: UUID
    var label: String
    var style: RelationshipStyle
    
    init(sourceId: UUID, targetId: UUID, label: String = "", style: RelationshipStyle = .solid) {
        self.id = UUID()
        self.sourceId = sourceId
        self.targetId = targetId
        self.label = label
        self.style = style
    }
    
    static func == (lhs: TopicRelationship, rhs: TopicRelationship) -> Bool {
        lhs.id == rhs.id
    }
}

enum RelationshipStyle {
    case solid
    case dashed
    case dotted
    case arrow
    case doubleArrow
    
    var strokeStyle: StrokeStyle {
        switch self {
        case .solid:
            return StrokeStyle(lineWidth: 2)
        case .dashed:
            return StrokeStyle(lineWidth: 2, dash: [6])
        case .dotted:
            return StrokeStyle(lineWidth: 2, dash: [2])
        case .arrow, .doubleArrow:
            return StrokeStyle(lineWidth: 2)
        }
    }
} 