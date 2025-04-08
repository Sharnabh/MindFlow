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
