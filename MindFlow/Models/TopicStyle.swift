import SwiftUI

struct TopicStyle {
    var shape: TopicShape = .roundedRectangle
    var borderColor: Color = .blue
    var fontStyle: Font = .body
    var foregroundColor: Color = .black
    var backgroundColor: Color = .blue.opacity(0.1)
    var borderWidth: CGFloat = 2
    var borderStyle: TopicBorderStyle = .solid
    
    enum TopicShape {
        case roundedRectangle
        case rectangle
        case capsule
        case ellipse
    }
    
    enum TopicBorderStyle {
        case solid
        case dashed
        case dotted
    }
}

// Extension to provide default styles
extension TopicStyle {
    static let `default` = TopicStyle()
    
    static let modern = TopicStyle(
        shape: .capsule,
        borderColor: .purple,
        fontStyle: .system(.body, design: .rounded),
        foregroundColor: .white,
        backgroundColor: .purple.opacity(0.8),
        borderWidth: 1,
        borderStyle: .solid
    )
    
    static let minimal = TopicStyle(
        shape: .roundedRectangle,
        borderColor: .gray,
        fontStyle: .system(.body, design: .monospaced),
        foregroundColor: .primary,
        backgroundColor: .clear,
        borderWidth: 1,
        borderStyle: .dashed
    )
} 