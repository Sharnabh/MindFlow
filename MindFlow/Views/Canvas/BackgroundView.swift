import SwiftUI

struct BackgroundView: View {
    let backgroundColor: Color
    let backgroundOpacity: Double
    let backgroundStyle: BackgroundStyle
    let gridSize: CGFloat
    let scale: CGFloat
    let offset: CGPoint
    
    var body: some View {
        Canvas { context, size in
            // Draw background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(backgroundColor.opacity(backgroundOpacity))
            )
            
            // Calculate visible area in canvas coordinates
            let visibleArea = CGRect(
                x: -offset.x / scale,
                y: -offset.y / scale,
                width: size.width / scale,
                height: size.height / scale
            )
            
            // Calculate grid bounds with padding
            let padding = max(size.width, size.height) / scale
            let gridBounds = visibleArea.insetBy(dx: -padding, dy: -padding)
            
            // Apply canvas transformations
            context.translateBy(x: offset.x, y: offset.y)
            context.scaleBy(x: scale, y: scale)
            
            // Draw the selected background style
            switch backgroundStyle {
            case .none:
                // No grid or pattern
                break
                
            case .grid:
                // Calculate grid line ranges
                let startX = floor(gridBounds.minX / gridSize) * gridSize
                let endX = ceil(gridBounds.maxX / gridSize) * gridSize
                let startY = floor(gridBounds.minY / gridSize) * gridSize
                let endY = ceil(gridBounds.maxY / gridSize) * gridSize
                
                // Draw vertical grid lines
                for x in stride(from: startX, through: endX, by: gridSize) {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x, y: startY))
                            path.addLine(to: CGPoint(x: x, y: endY))
                        },
                        with: .color(.gray.opacity(0.2)),
                        lineWidth: 0.5 / scale
                    )
                }
                
                // Draw horizontal grid lines
                for y in stride(from: startY, through: endY, by: gridSize) {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: startX, y: y))
                            path.addLine(to: CGPoint(x: endX, y: y))
                        },
                        with: .color(.gray.opacity(0.2)),
                        lineWidth: 0.5 / scale
                    )
                }
                
            case .dots:
                // Calculate dot positions
                let dotSize: CGFloat = 2.0 / scale
                let startX = floor(gridBounds.minX / gridSize) * gridSize
                let endX = ceil(gridBounds.maxX / gridSize) * gridSize
                let startY = floor(gridBounds.minY / gridSize) * gridSize
                let endY = ceil(gridBounds.maxY / gridSize) * gridSize
                
                // Draw dots at grid intersections
                for x in stride(from: startX, through: endX, by: gridSize) {
                    for y in stride(from: startY, through: endY, by: gridSize) {
                        let dotRect = CGRect(
                            x: x - (dotSize / 2),
                            y: y - (dotSize / 2),
                            width: dotSize,
                            height: dotSize
                        )
                        context.fill(
                            Path(ellipseIn: dotRect),
                            with: .color(.gray.opacity(0.3))
                        )
                    }
                }
            }
        }
    }
} 