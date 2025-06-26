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
                                relationshipIsCurved: false // Parent-child relationships don't have persistent curve state
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
                            relationshipIsCurved: relationship.isCurved
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
                    isCircularRelationshipMode: isCircularRelationshipMode
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
    let relationshipIsCurved: Bool
    
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
                if shouldUseCurvedStyle {
                    // Use CircularCurvePath for relationships when they should be curved
                    if isRelationship && (isCircularRelationshipMode || relationshipIsCurved) {
                        CircularCurvePath(start: animatedStartPoint, end: animatedEndPoint)
                            .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
                    } else {
                        // Use standard curved path for branch styles
                        AnimatedCurvePath(start: animatedStartPoint, end: animatedEndPoint)
                            .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
                    }
                } else {
                    // Draw straight line with animation
                    AnimatedLinePath(start: animatedStartPoint, end: animatedEndPoint)
                        .stroke(color.opacity((selectedId == from.id || selectedId == to.id) ? 1.0 : 0.7), lineWidth: 2.5)
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
                .position(calculateButtonPosition(start: animatedStartPoint, end: animatedEndPoint, isCurved: shouldUseCurvedStyle && (isCircularRelationshipMode || relationshipIsCurved)))
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
    private func calculateButtonPosition(start: CGPoint, end: CGPoint, isCurved: Bool) -> CGPoint {
        if isCurved {
            // For curved lines, calculate the midpoint on the actual curve
            let midX = (start.x + end.x) / 2
            let midY = (start.y + end.y) / 2
            
            // Calculate curve offset based on the line orientation and direction
            let dx = end.x - start.x
            let dy = end.y - start.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Use the same curve calculation as CircularCurvePath
            let curveHeight = max(60, distance * 0.4)
            
            // Determine if this is primarily a vertical or horizontal line
            let isVertical = abs(dy) > abs(dx)
            
            if isVertical {
                // For vertical lines, curve horizontally based on the direction
                // If going down (dy > 0), curve to the right side (positive offset)
                // If going up (dy < 0), curve to the left side (negative offset)
                let offsetX = dy > 0 ? curveHeight : -curveHeight
                return CGPoint(x: midX + offsetX, y: midY)
            } else {
                // For horizontal lines, curve vertically based on the direction
                // If going right (dx > 0), curve upward (negative offset)
                // If going left (dx < 0), curve downward (positive offset)
                let offsetY = dx > 0 ? -curveHeight : curveHeight
                return CGPoint(x: midX, y: midY + offsetY)
            }
        } else {
            // For straight lines, use simple midpoint
            return CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
        }
    }
}
