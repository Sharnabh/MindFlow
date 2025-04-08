//
//  ConnectionLine.swift
//  MindFlow
//
//  Created by Sharnabh on 08/04/25.
//

import SwiftUI

// Helper view to recursively render connection lines
struct ConnectionLinesView: View {
    let topics: [Topic]
    let onDeleteRelation: (UUID, UUID) -> Void
    let selectedId: UUID?
    
    var body: some View {
        // Draw all lines in a single layer with smooth animations
        ForEach(topics) { topic in
            Group {
                // Draw lines to immediate subtopics only if not collapsed
                if !topic.isCollapsed {
                    ForEach(topic.subtopics) { subtopic in
                        ConnectionLine(
                            from: topic,
                            to: subtopic,
                            color: subtopic.borderColor,
                            forceCurved: false, // Not forcing curved, will use individual topic settings
                            onDelete: {}, // No delete for parent-child relationships
                            isRelationship: false, // This is a parent-child relationship
                            selectedId: selectedId
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: topic.position)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: subtopic.position)
                    }
                }
                
                // Draw relationship lines (only draw if we're the source topic)
                ForEach(topic.relations) { relatedTopic in
                    ConnectionLine(
                        from: topic,
                        to: relatedTopic,
                        color: .purple,
                        forceCurved: false, // Not forcing curved, will use individual topic settings
                        onDelete: { onDeleteRelation(topic.id, relatedTopic.id) },
                        isRelationship: true, // This is a relationship line
                        selectedId: selectedId
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: topic.position)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: relatedTopic.position)
                }
            }
            
            // Recursively draw lines for nested subtopics only if not collapsed
            if !topic.subtopics.isEmpty && !topic.isCollapsed {
                ConnectionLinesView(
                    topics: topic.subtopics,
                    onDeleteRelation: onDeleteRelation,
                    selectedId: selectedId
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
    
    @State private var isHovered = false
    @State private var hoverPoint: CGPoint = .zero
    @State private var animatedStartPoint: CGPoint = .zero
    @State private var animatedEndPoint: CGPoint = .zero
    
    private var shouldUseCurvedStyle: Bool {
        // Use curved style if:
        // 1. Either the source or target topic has curved branch style
        // 2. Or if forceCurved is true (global setting)
        // For parent-child relationships, use the parent's style
        if !isRelationship {
            return from.branchStyle == .curved
        }
        // For relationships, use curved if either topic has curved style
        return forceCurved || from.branchStyle == .curved || to.branchStyle == .curved
    }
    
    var body: some View {
        let points = calculateTopicIntersection(from: from, to: to)
        
        ZStack {
            // Draw the line
            Group {
                if shouldUseCurvedStyle {
                    // Draw curved path with animation
                    AnimatedCurvePath(start: animatedStartPoint, end: animatedEndPoint)
                        .stroke(color.opacity(1.0), lineWidth: 1)
                } else {
                    // Draw straight line with animation
                    AnimatedLinePath(start: animatedStartPoint, end: animatedEndPoint)
                        .stroke(color.opacity(1.0), lineWidth: 1)
                }
            }
            
            // Add hover area with smaller width
            Path { path in
                path.move(to: animatedStartPoint)
                path.addLine(to: animatedEndPoint)
            }
            .stroke(Color.clear, lineWidth: 10) // 10px hover area
            .onHover { hovering in
                if hovering {
                    // Get the current mouse position
                    if let window = NSApp.keyWindow,
                       let contentView = window.contentView {
                        let mouseLocation = NSEvent.mouseLocation
                        let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                        let viewPoint = contentView.convert(windowPoint, from: nil)
                        hoverPoint = viewPoint
                        
                        // Calculate distance from point to line
                        let distance = distanceFromPointToLine(point: hoverPoint, lineStart: animatedStartPoint, lineEnd: animatedEndPoint)
                        isHovered = distance < 10 // Show button if within 10px of the line
                    }
                } else {
                    isHovered = false
                }
            }
            
            // Delete button - show for relationship lines when hovered or when connected topics are selected
            if isRelationship && (isHovered || from.id == selectedId || to.id == selectedId) {
                Button(action: onDelete) {
                    ZStack {
                        // Background circle with line color and very low opacity
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 24, height: 24)
                        
                        // Minus icon
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(color)
                            .font(.system(size: 16))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .position(
                    x: (animatedStartPoint.x + animatedEndPoint.x) / 2,
                    y: (animatedStartPoint.y + animatedEndPoint.y) / 2
                )
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
}
