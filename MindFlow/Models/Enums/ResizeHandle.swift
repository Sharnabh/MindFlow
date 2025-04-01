import Foundation
import AppKit

enum ResizeHandle: CaseIterable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
    
    var cursor: NSCursor {
        switch self {
        case .topLeft, .bottomRight:
            return NSCursor.crosshair
        case .top, .bottom:
            return NSCursor.resizeUpDown
        case .topRight, .bottomLeft:
            return NSCursor.crosshair
        case .left, .right:
            return NSCursor.resizeLeftRight
        }
    }
} 