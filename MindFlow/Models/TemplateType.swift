import SwiftUI

/// Defines different template types for mind maps and their behavior
enum TemplateType: String, CaseIterable, Identifiable, Codable {
    case mindMap = "Mind Map"
    case tree = "Tree"
    case conceptMap = "Concept Map"
    case flowchart = "Flowchart"
    case orgChart = "Org Chart"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .mindMap:
            return "brain"
        case .tree:
            return "tree"
        case .conceptMap:
            return "network"
        case .flowchart:
            return "arrow.triangle.branch"
        case .orgChart:
            return "person.3"
        }
    }
    
    /// Returns how subtopics should be arranged relative to their parent
    var subtopicArrangement: SubtopicArrangement {
        switch self {
        case .mindMap:
            return .rightSide
        case .tree:
            return .below
        case .conceptMap:
            return .radial
        case .flowchart:
            return .below
        case .orgChart:
            return .below
        }
    }
    
    /// Calculates the position for a new subtopic based on the template type
    func calculateSubtopicPosition(parentTopic: Topic, subtopicIndex: Int, totalSubtopics: Int) -> CGPoint {
        // Spacing constants
        let horizontalSpacing: CGFloat = 200
        let verticalSpacing: CGFloat = 60
        
        switch subtopicArrangement {
        case .rightSide:
            // Mind Map style: arrange to the right in a vertical column
            let totalHeight = verticalSpacing * CGFloat(totalSubtopics - 1)
            let startY = parentTopic.position.y + totalHeight/2
            let y = startY - (CGFloat(subtopicIndex) * verticalSpacing)
            let x = parentTopic.position.x + horizontalSpacing
            return CGPoint(x: x, y: y)
            
        case .below:
            // Tree style: arrange below in a horizontal row
            let totalWidth = verticalSpacing * CGFloat(totalSubtopics - 1)
            let startX = parentTopic.position.x - totalWidth/2
            let x = startX + (CGFloat(subtopicIndex) * verticalSpacing)
            let y = parentTopic.position.y + horizontalSpacing
            return CGPoint(x: x, y: y)
            
        case .radial:
            // Concept Map style: arrange in a circle around the parent
            let radius = horizontalSpacing
            let angle = (2.0 * .pi / Double(totalSubtopics)) * Double(subtopicIndex)
            let x = parentTopic.position.x + radius * cos(angle)
            let y = parentTopic.position.y + radius * sin(angle)
            return CGPoint(x: x, y: y)
        }
    }
    
    /// Determines the connection points between two topics based on template type
    func calculateConnectionPoints(fromBox: CGRect, toBox: CGRect, fromCenter: CGPoint, toCenter: CGPoint, isParentChild: Bool) -> (start: CGPoint, end: CGPoint) {
        if !isParentChild {
            // For non-parent-child relationships, use angle-based calculation
            return calculateAngleBasedConnectionPoints(fromBox: fromBox, toBox: toBox, fromCenter: fromCenter, toCenter: toCenter)
        }
        
        switch subtopicArrangement {
        case .rightSide:
            // Mind Map style: connect from right of parent to left of child
            let start = CGPoint(x: fromBox.maxX, y: fromBox.midY)
            let end = CGPoint(x: toBox.minX, y: toBox.midY)
            return (start, end)
            
        case .below:
            // Tree style: connect from bottom of parent to top of child
            let start = CGPoint(x: fromBox.midX, y: fromBox.maxY)
            let end = CGPoint(x: toBox.midX, y: toBox.minY)
            return (start, end)
            
        case .radial:
            // Concept Map style: use angle-based calculation
            return calculateAngleBasedConnectionPoints(fromBox: fromBox, toBox: toBox, fromCenter: fromCenter, toCenter: toCenter)
        }
    }
    
    // Helper method to calculate angle-based connection points
    private func calculateAngleBasedConnectionPoints(fromBox: CGRect, toBox: CGRect, fromCenter: CGPoint, toCenter: CGPoint) -> (start: CGPoint, end: CGPoint) {
        func findBestSideIntersection(box: CGRect, from: CGPoint, towards: CGPoint) -> CGPoint {
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
        
        let fromIntersect = findBestSideIntersection(box: fromBox, from: fromCenter, towards: toCenter)
        let toIntersect = findBestSideIntersection(box: toBox, from: toCenter, towards: fromCenter)
        
        return (fromIntersect, toIntersect)
    }
}

/// Different ways subtopics can be arranged relative to their parent
enum SubtopicArrangement {
    case rightSide  // Mind Map style: parent on left, children to the right
    case below      // Tree style: parent on top, children below
    case radial     // Concept Map style: children in a circle around the parent
} 