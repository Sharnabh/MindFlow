//
//  AnimatedLine.swift
//  MindFlow
//
//  Created by Sharnabh on 08/04/25.
//

import SwiftUI

// Animated path shapes
struct AnimatedLinePath: Shape {
    var start: CGPoint
    var end: CGPoint
    
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(start.animatableData, end.animatableData) }
        set {
            start.animatableData = newValue.first
            end.animatableData = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

struct AnimatedCurvePath: Shape {
    var start: CGPoint
    var end: CGPoint
    
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(start.animatableData, end.animatableData) }
        set {
            start.animatableData = newValue.first
            end.animatableData = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        
        // Calculate control points for the curve
        let dx = end.x - start.x
        let _ = end.y - start.y
        let midX = start.x + dx * 0.5
        
        // Create control points that curve outward
        let control1 = CGPoint(x: midX, y: start.y)
        let control2 = CGPoint(x: midX, y: end.y)
        
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }
}

struct CircularCurvePath: Shape {
    var start: CGPoint
    var end: CGPoint
    
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(start.animatableData, end.animatableData) }
        set {
            start.animatableData = newValue.first
            end.animatableData = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        
        // Calculate distance and direction
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Guard against zero distance
        guard distance > 0 else {
            path.addLine(to: end)
            return path
        }
        
        // Calculate if this is more vertical or horizontal
        let isMoreVertical = abs(dy) > abs(dx)
        
        // Adjust curvature based on orientation - more curve for vertical connections
        let baseCurvature: CGFloat = isMoreVertical ? 0.5 : 0.3
        let offset = distance * baseCurvature
        
        // Calculate perpendicular offset for circular curve with direction-aware curving
        var perpX: CGFloat
        var perpY: CGFloat
        
        if isMoreVertical {
            // For vertical lines, alternate curve direction based on horizontal position
            // This creates more natural curves that don't all go the same way
            let horizontalBias = (start.x + end.x) / 2 // Use midpoint x position
            let curveRight = sin(horizontalBias * 0.01) > 0 // Create variation based on position
            let direction: CGFloat = curveRight ? 1 : -1
            perpX = direction * offset
            perpY = 0
        } else {
            // For horizontal lines, alternate curve direction based on vertical position
            let verticalBias = (start.y + end.y) / 2 // Use midpoint y position
            let curveUp = cos(verticalBias * 0.01) > 0 // Create variation based on position
            let direction: CGFloat = curveUp ? -1 : 1
            perpX = 0
            perpY = direction * offset
        }
        
        // Create control points that create a pronounced circular arc
        let control1 = CGPoint(
            x: start.x + dx * 0.25 + perpX,
            y: start.y + dy * 0.25 + perpY
        )
        let control2 = CGPoint(
            x: start.x + dx * 0.75 + perpX,
            y: start.y + dy * 0.75 + perpY
        )
        
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }
}
