import SwiftUI
import AppKit

class TopicRelationshipViewModel: ObservableObject {
    @Published var isSelected: Bool = false
    @Published var isHovered: Bool = false
    @Published var isEditing: Bool = false
    @Published var editingLabel: String = ""
    
    let relationship: TopicRelationship
    let onSelect: (TopicRelationship) -> Void
    let onDelete: (TopicRelationship) -> Void
    let onLabelChange: (TopicRelationship) -> Void
    
    init(relationship: TopicRelationship, onSelect: @escaping (TopicRelationship) -> Void, onDelete: @escaping (TopicRelationship) -> Void, onLabelChange: @escaping (TopicRelationship) -> Void) {
        self.relationship = relationship
        self.editingLabel = relationship.label
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onLabelChange = onLabelChange
    }
    
    func handleTap() {
        onSelect(relationship)
    }
    
    func handleDelete() {
        onDelete(relationship)
    }
    
    func startEditing() {
        isEditing = true
    }
    
    func commitEditing() {
        isEditing = false
        if editingLabel != relationship.label {
            var updatedRelationship = relationship
            updatedRelationship.label = editingLabel
            onLabelChange(updatedRelationship)
        }
    }
    
    func cancelEditing() {
        isEditing = false
        editingLabel = relationship.label
    }
    
    func getPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        
        // Calculate control points for curved line
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Adjust control points based on distance
        let controlPoint1 = CGPoint(
            x: start.x + dx * 0.25,
            y: start.y + dy * 0.25
        )
        let controlPoint2 = CGPoint(
            x: start.x + dx * 0.75,
            y: start.y + dy * 0.75
        )
        
        path.move(to: start)
        path.addCurve(to: end, control1: controlPoint1, control2: controlPoint2)
        
        return path
    }
    
    func getLabelPosition(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return CGPoint(
            x: start.x + dx * 0.5,
            y: start.y + dy * 0.5
        )
    }
    
    func getLabelRotation(from start: CGPoint, to end: CGPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return atan2(dy, dx)
    }
} 