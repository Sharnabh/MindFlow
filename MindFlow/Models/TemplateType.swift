import SwiftUI

/// Defines different template types for mind maps and their behavior
enum TemplateType: String, CaseIterable, Identifiable, Codable {
    case mindMap = "Mind Map"
    case tree = "Tree"
    case algorithm = "Algorithm"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .mindMap:
            return "brain"
        case .tree:
            return "tree"
        case .algorithm:
            return "arrow.down.right.circle" // Changed icon for flowchart
        }
    }
    
    /// Returns how subtopics should be arranged relative to their parent
    var subtopicArrangement: SubtopicArrangement {
        switch self {
        case .mindMap:
            return .rightSide
        case .tree:
            return .below
        case .algorithm:
            return .flowchart // Changed to flowchart
        }
    }
    
    /// Calculates the position for a new subtopic based on the template type
    func calculateSubtopicPosition(parentTopic: Topic, subtopicIndex: Int, totalSubtopics: Int) -> CGPoint {
        // Spacing constants
        let horizontalSpacing: CGFloat = 150 // Adjusted for flowchart
        let verticalSpacing: CGFloat = 100   // Adjusted for flowchart
        
        switch subtopicArrangement {
        case .rightSide:
            // Mind Map style: arrange to the right in a vertical column
            let totalHeight = verticalSpacing * CGFloat(totalSubtopics - 1)
            let startY = parentTopic.position.y - totalHeight / 2 // Centering the block of subtopics
            let y = startY + (CGFloat(subtopicIndex) * verticalSpacing)
            let x = parentTopic.position.x + horizontalSpacing
            return CGPoint(x: x, y: y)
            
        case .below:
            // Tree style: arrange below in a horizontal row
            let totalWidth = horizontalSpacing * CGFloat(totalSubtopics - 1) // Use horizontalSpacing for width calculation
            let startX = parentTopic.position.x - totalWidth / 2 // Centering the block of subtopics
            let x = startX + (CGFloat(subtopicIndex) * horizontalSpacing)
            let y = parentTopic.position.y + verticalSpacing // Use verticalSpacing for y-offset
            return CGPoint(x: x, y: y)
            
        case .radial:
            // Concept Map style: arrange in a circle around the parent
            let radius = (horizontalSpacing + verticalSpacing) / 2 // Average spacing for radius
            let angle = (2.0 * .pi / Double(totalSubtopics)) * Double(subtopicIndex)
            let x = parentTopic.position.x + radius * cos(angle)
            let y = parentTopic.position.y + radius * sin(angle)
            return CGPoint(x: x, y: y)

        case .flowchart:
            // Flowchart style: arrange primarily downwards, then slightly horizontally for multiple
            // For simplicity, let's arrange them vertically below the parent,
            // with slight horizontal staggering if multiple direct children.
            let y = parentTopic.position.y + verticalSpacing
            // Simple horizontal distribution if multiple subtopics
            let initialXOffset: CGFloat = -CGFloat(totalSubtopics - 1) * horizontalSpacing / 4
            let x = parentTopic.position.x + initialXOffset + (CGFloat(subtopicIndex) * horizontalSpacing / 2)
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

        case .flowchart:
            let dx = toCenter.x - fromCenter.x
            let dy = toCenter.y - fromCenter.y

            // Make the condition for horizontal connections stricter:
            // dx must be significantly larger than dy to be considered "primarily horizontal".
            // Using a factor of 1.5, meaning abs(dx) must be > 1.5 * abs(dy).
            if abs(dx) > abs(dy) * 1.5 { // Primarily horizontal
                if dx > 0 { // Child is to the right of parent
                    let start = CGPoint(x: fromBox.maxX, y: fromBox.midY)
                    let end = CGPoint(x: toBox.minX, y: toBox.midY)
                    return (start, end)
                } else { // Child is to the left of parent
                    let start = CGPoint(x: fromBox.minX, y: fromBox.midY)
                    let end = CGPoint(x: toBox.maxX, y: toBox.midY)
                    return (start, end)
                }
            } else { // Primarily vertical (or diagonal, favoring vertical)
                if dy > 0 { // Child is below parent
                    let start = CGPoint(x: fromBox.midX, y: fromBox.maxY)
                    let end = CGPoint(x: toBox.midX, y: toBox.minY)
                    return (start, end)
                } else { // Child is above parent (or dy is 0, dx is also 0 or small)
                    let start = CGPoint(x: fromBox.midX, y: fromBox.minY)
                    let end = CGPoint(x: toBox.midX, y: toBox.maxY)
                    return (start, end)
                }
            }
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
    case flowchart  // Flowchart style: parent above, children below, or side-by-side for decisions
}
