import SwiftUI
import AppKit

class TopicStyleViewModel: ObservableObject {
    @Published var selectedColor: Color
    @Published var opacity: Double
    @Published var selectedShape: Topic.Shape
    @Published var isShowingColorPicker: Bool = false
    @Published var isShowingShapeSelector: Bool = false
    
    let topic: Topic
    
    init(topic: Topic) {
        self.topic = topic
        self.selectedColor = topic.backgroundColor
        self.opacity = topic.backgroundOpacity
        self.selectedShape = topic.shape
    }
    
    func updateColor(_ color: Color) {
        selectedColor = color
        // Additional action if needed
    }
    
    func updateOpacity(_ newOpacity: Double) {
        opacity = newOpacity
        // Additional action if needed
    }
    
    func updateShape(_ shape: Topic.Shape) {
        selectedShape = shape
        // Additional action if needed
    }
    
    func getShapePath(in rect: CGRect) -> Path {
        switch selectedShape {
        case .rectangle:
            return Path(rect)
        case .roundedRectangle:
            return Path(roundedRect: rect, cornerRadius: 10)
        case .circle:
            return Path(ellipseIn: rect)
        case .diamond:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
            return path
        case .hexagon:
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            let points = (0..<6).map { i -> CGPoint in
                let angle = CGFloat(i) * .pi / 3
                return CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
            }
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
            return path
        default:
            return Path(rect)
        }
    }
} 