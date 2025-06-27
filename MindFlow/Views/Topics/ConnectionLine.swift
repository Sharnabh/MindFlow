//
//  ConnectionLine.swift
//  MindFlow
//
//  Created by Sharnabh on 08/04/25.
//

import SwiftUI

// Helper view to recursively render connection lines
struct ConnectionLinesView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let topics: [Topic]
    let onDeleteRelation: (UUID, UUID) -> Void
    let onDeleteParentChild: (UUID, UUID) -> Void
    let selectedId: UUID?
    let isCircularRelationshipMode: Bool
    let isSquaredRelationshipMode: Bool
    
    var body: some View {
        // Draw all lines in a single layer with smooth animations
        ForEach(topics) { topic in
            Group {
                // Draw lines to immediate subtopics only if not collapsed
                if !topic.isCollapsed {
                    ForEach(topic.subtopics) { subtopic in
                        // Look up the most recent subtopic state from the view model
                        if let currentSubtopic = viewModel.findTopic(id: subtopic.id) {
                            ConnectionLine(
                                from: topic,
                                to: currentSubtopic, // Use current state
                                color: currentSubtopic.borderColor,
                                forceCurved: false, // Not forcing curved, will use individual topic settings
                                onDelete: { onDeleteParentChild(topic.id, currentSubtopic.id) }, // Pass parent-child delete action
                                isRelationship: false, // This is a parent-child relationship
                                selectedId: selectedId,
                                isCircularRelationshipMode: isCircularRelationshipMode,
                                isSquaredRelationshipMode: isSquaredRelationshipMode,
                                relationshipIsCurved: false, // Parent-child relationships don't have persistent curve state
                                relationshipType: nil // Parent-child relationships don't have a type
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: topic.position)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentSubtopic.position)
                        }
                    }
                }
                
                // Draw relationship lines (only draw if we're the source topic)
                ForEach(topic.relations, id: \.id) { relationship in // Iterate over Relationship objects
                    // Look up the related topic using the viewModel
                    if let relatedTopic = viewModel.findTopic(id: relationship.targetId) {
                        ConnectionLine(
                            from: topic,
                            to: relatedTopic, // Use current state of related topic
                            color: .purple,
                            forceCurved: false, // Not forcing curved, will use individual topic settings
                            onDelete: { onDeleteRelation(topic.id, relationship.targetId) },
                            isRelationship: true, // This is a relationship line
                            selectedId: selectedId,
                            isCircularRelationshipMode: isCircularRelationshipMode,
                            isSquaredRelationshipMode: isSquaredRelationshipMode,
                            relationshipIsCurved: relationship.isCurved,
                            relationshipType: relationship.relationshipType
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: topic.position)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: relatedTopic.position)
                    }
                }
            }
            
            // Recursively draw lines for nested subtopics only if not collapsed
            if !topic.subtopics.isEmpty && !topic.isCollapsed {
                ConnectionLinesView(
                    viewModel: viewModel, // Pass viewModel down
                    topics: topic.subtopics,
                    onDeleteRelation: onDeleteRelation,
                    onDeleteParentChild: onDeleteParentChild,
                    selectedId: selectedId,
                    isCircularRelationshipMode: isCircularRelationshipMode,
                    isSquaredRelationshipMode: isSquaredRelationshipMode
                )
                .transition(.opacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: !topic.isCollapsed)
            }
        }
    }
}

// Helper view for drawing a single connection line
private struct ConnectionLine: View {
    let from: Topic
    let to: Topic
    let color: Color
    let forceCurved: Bool
    let onDelete: () -> Void
    let isRelationship: Bool
    let selectedId: UUID?
    let isCircularRelationshipMode: Bool
    let isSquaredRelationshipMode: Bool
    let relationshipIsCurved: Bool
    let relationshipType: String?
    
    @State private var animatedStartPoint: CGPoint = .zero
    @State private var animatedEndPoint: CGPoint = .zero
    
    private var shouldUseCurvedStyle: Bool {
        // Use curved style if:
        // 1. Either the source or target topic has curved branch style
        // 2. Or if forceCurved is true (global setting)
        // 3. Or if circular relationship mode is enabled for relationships
        // 4. Or if this relationship was created with curved style (persistent state)
        // For parent-child relationships, use the parent's style
        if !isRelationship {
            return from.branchStyle == .curved
        }
        // For relationships, use curved if any of these conditions are true
        return relationshipIsCurved || isCircularRelationshipMode || forceCurved || from.branchStyle == .curved || to.branchStyle == .curved
    }
    
    var body: some View {
        let points = calculateTopicIntersection(from: from, to: to)
        
        ZStack {
            // Draw the line
            Group {
                if isRelationship {
                    // For relationships, use the STORED relationship type, NOT the current toggle states
                    // This ensures existing relationships maintain their style when toggles change
                    if let storedType = relationshipType {
                        switch storedType {
                        case "squared":
                            SquaredSPath(start: animatedStartPoint, end: animatedEndPoint)
                                .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
                        case "curved":
                            CircularCurvePath(start: animatedStartPoint, end: animatedEndPoint)
                                .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
                        default: // "straight" or any other value
                            AnimatedLinePath(start: animatedStartPoint, end: animatedEndPoint)
                                .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
                        }
                    } else {
                        // Fallback for old relationships without relationshipType (backward compatibility)
                        if relationshipIsCurved {
                            CircularCurvePath(start: animatedStartPoint, end: animatedEndPoint)
                                .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
                        } else {
                            AnimatedLinePath(start: animatedStartPoint, end: animatedEndPoint)
                                .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
                        }
                    }
                } else {
                    // For parent-child relationships, use branch style or force curved
                    if shouldUseCurvedStyle {
                        AnimatedCurvePath(start: animatedStartPoint, end: animatedEndPoint)
                            .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
                    } else {
                        AnimatedLinePath(start: animatedStartPoint, end: animatedEndPoint)
                            .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
                    }
                }
            }
            
            // Detach button for parent-child relationships
            if !isRelationship && (selectedId == from.id || selectedId == to.id) {
                Button(action: onDelete) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                        Image(systemName: "scissors")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .position(
                    x: (animatedStartPoint.x + animatedEndPoint.x) / 2,
                    y: (animatedStartPoint.y + animatedEndPoint.y) / 2
                )
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            
            // Delete button for relationship lines
            if isRelationship && (selectedId == from.id || selectedId == to.id) {
                Button(action: onDelete) {
                    ZStack {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 32, height: 32)
                        Image(systemName: "scissors")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .position(calculateButtonPosition(start: animatedStartPoint, end: animatedEndPoint, relationshipType: isRelationship ? relationshipType : nil, isParentChildCurved: shouldUseCurvedStyle))
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
        .onChange(of: points.start) { oldValue, newStart in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                animatedStartPoint = newStart
            }
        }
        .onChange(of: points.end) { oldValue, newEnd in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                animatedEndPoint = newEnd
            }
        }
        .onAppear {
            // Initialize animated points
            animatedStartPoint = points.start
            animatedEndPoint = points.end
        }
    }
    
    // Helper function to calculate distance from a point to a line segment
    private func distanceFromPointToLine(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        // Calculate the length of the line segment
        let lineLength = sqrt(dx * dx + dy * dy)
        
        // If the line segment is just a point, return the distance to that point
        if lineLength == 0 {
            return sqrt((point.x - lineStart.x) * (point.x - lineStart.x) + (point.y - lineStart.y) * (point.y - lineStart.y))
        }
        
        // Calculate the projection of the point onto the line
        let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (lineLength * lineLength)
        
        // If the projection is outside the line segment, return the distance to the nearest endpoint
        if t < 0 {
            return sqrt((point.x - lineStart.x) * (point.x - lineStart.x) + (point.y - lineStart.y) * (point.y - lineStart.y))
        }
        if t > 1 {
            return sqrt((point.x - lineEnd.x) * (point.x - lineEnd.x) + (point.y - lineEnd.y) * (point.y - lineEnd.y))
        }
        
        // Calculate the projection point
        let projectionX = lineStart.x + t * dx
        let projectionY = lineStart.y + t * dy
        
        // Return the distance from the point to the projection point
        return sqrt((point.x - projectionX) * (point.x - projectionX) + (point.y - projectionY) * (point.y - projectionY))
    }
    
    // Calculate button position for straight or curved lines
    private func calculateButtonPosition(start: CGPoint, end: CGPoint, relationshipType: String?, isParentChildCurved: Bool) -> CGPoint {
        // Handle relationship lines with stored types
        if let storedType = relationshipType {
            switch storedType {
            case "squared":
                return calculateSquaredPathButtonPosition(start: start, end: end)
            case "curved":
                return calculateCurvedButtonPosition(start: start, end: end)
            default: // "straight"
                return calculateStraightButtonPosition(start: start, end: end)
            }
        } else {
            // Handle parent-child relationships or old relationships without type
            if isParentChildCurved {
                return calculateCurvedButtonPosition(start: start, end: end)
            } else {
                return calculateStraightButtonPosition(start: start, end: end)
            }
        }
    }
    
    private func calculateStraightButtonPosition(start: CGPoint, end: CGPoint) -> CGPoint {
        // For straight lines, use simple midpoint
        return CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2
        )
    }
    
    private func calculateCurvedButtonPosition(start: CGPoint, end: CGPoint) -> CGPoint {
        // Use the exact same curve calculation as CircularCurvePath to find the midpoint
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Guard against zero distance
        guard distance > 0 else {
            return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }
        
        // Use the same logic as CircularCurvePath
        let isMoreVertical = abs(dy) > abs(dx)
        let baseCurvature: CGFloat = isMoreVertical ? 0.5 : 0.3
        let offset = distance * baseCurvature
        
        // Calculate perpendicular offset for circular curve with direction-aware curving
        var perpX: CGFloat
        var perpY: CGFloat
        
        if isMoreVertical {
            let horizontalBias = (start.x + end.x) / 2
            let curveRight = sin(horizontalBias * 0.01) > 0
            let direction: CGFloat = curveRight ? 1 : -1
            perpX = direction * offset
            perpY = 0
        } else {
            let verticalBias = (start.y + end.y) / 2
            let curveUp = cos(verticalBias * 0.01) > 0
            let direction: CGFloat = curveUp ? -1 : 1
            perpX = 0
            perpY = direction * offset
        }
        
        // Calculate the control points (same as CircularCurvePath)
        let control1 = CGPoint(
            x: start.x + dx * 0.25 + perpX,
            y: start.y + dy * 0.25 + perpY
        )
        let control2 = CGPoint(
            x: start.x + dx * 0.75 + perpX,
            y: start.y + dy * 0.75 + perpY
        )
        
        // Calculate the midpoint on the Bézier curve (t = 0.5)
        // Bézier curve formula: B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
        let t: CGFloat = 0.5
        let oneMinusT = 1 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let oneMinusTCubed = oneMinusTSquared * oneMinusT
        let tSquared = t * t
        let tCubed = tSquared * t
        
        let midPointX = oneMinusTCubed * start.x + 
                       3 * oneMinusTSquared * t * control1.x + 
                       3 * oneMinusT * tSquared * control2.x + 
                       tCubed * end.x
        
        let midPointY = oneMinusTCubed * start.y + 
                       3 * oneMinusTSquared * t * control1.y + 
                       3 * oneMinusT * tSquared * control2.y + 
                       tCubed * end.y
        
        return CGPoint(x: midPointX, y: midPointY)
    }
    
    private func calculateSquaredPathButtonPosition(start: CGPoint, end: CGPoint) -> CGPoint {
        // For squared S-shaped paths, place the button at the middle of the path
        // The path has 3 segments, so we want to position it on the middle (vertical/horizontal) segment
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        
        // Use the same logic as SquaredSPath to determine path direction
        let isMoreHorizontal = abs(dx) > abs(dy)
        
        if isMoreHorizontal {
            // Horizontal-first path: horizontal -> vertical -> horizontal
            let segmentLength = abs(dx) * 0.4
            let direction = dx > 0 ? 1 : -1
            
            // The middle segment is vertical, so place button in the middle of that vertical line
            let middleX = start.x + CGFloat(direction) * segmentLength
            let middleY = (start.y + end.y) / 2
            
            return CGPoint(x: middleX, y: middleY)
        } else {
            // Vertical-first path: vertical -> horizontal -> vertical
            let segmentLength = abs(dy) * 0.4
            let direction = dy > 0 ? 1 : -1
            
            // The middle segment is horizontal, so place button in the middle of that horizontal line
            let middleX = (start.x + end.x) / 2
            let middleY = start.y + CGFloat(direction) * segmentLength
            
            return CGPoint(x: middleX, y: middleY)
        }
    }
}
