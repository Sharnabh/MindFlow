//
//  DragPhysics.swift
//  MindFlow
//
//  Created by Sharnabh on 08/04/25.
//

import Foundation

// Physics properties for topic dragging
class DragPhysics: ObservableObject {
    var velocity: CGSize = .zero
    var lastPosition: CGPoint = .zero
    var lastUpdateTime: Date = Date()
    var isDecelerating: Bool = false
    var targetPosition: CGPoint = .zero
    
    func updateVelocity(currentPosition: CGPoint) {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastUpdateTime)
        
        if timeInterval > 0 {
            // Calculate velocity based on position change over time
            let dx = currentPosition.x - lastPosition.x
            let dy = currentPosition.y - lastPosition.y
            
            // Apply some smoothing to the velocity
            let smoothingFactor: CGFloat = 0.3
            velocity.width = velocity.width * (1 - smoothingFactor) + (dx / CGFloat(timeInterval)) * smoothingFactor
            velocity.height = velocity.height * (1 - smoothingFactor) + (dy / CGFloat(timeInterval)) * smoothingFactor
        }
        
        lastPosition = currentPosition
        lastUpdateTime = now
    }
    
    func reset() {
        velocity = .zero
        isDecelerating = false
    }
}
