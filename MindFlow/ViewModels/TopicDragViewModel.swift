import SwiftUI
import AppKit

class TopicDragViewModel: ObservableObject {
    @Published var isDragging: Bool = false
    @Published var draggedTopic: Topic?
    @Published var dragOffset: CGPoint = .zero
    @Published var dragStartPosition: CGPoint?
    @Published var dragStartScale: CGFloat?
    
    let onDragStart: (Topic) -> Void
    let onDragEnd: (Topic, CGPoint) -> Void
    let onDragCancel: () -> Void
    
    init(onDragStart: @escaping (Topic) -> Void, onDragEnd: @escaping (Topic, CGPoint) -> Void, onDragCancel: @escaping () -> Void) {
        self.onDragStart = onDragStart
        self.onDragEnd = onDragEnd
        self.onDragCancel = onDragCancel
    }
    
    func startDragging(topic: Topic, at point: CGPoint, scale: CGFloat) {
        isDragging = true
        draggedTopic = topic
        dragStartPosition = point
        dragStartScale = scale
        onDragStart(topic)
    }
    
    func updateDrag(at point: CGPoint) {
        guard let start = dragStartPosition,
              let scale = dragStartScale,
              let topic = draggedTopic else { return }
        
        let dx = (point.x - start.x) / scale
        let dy = (point.y - start.y) / scale
        
        dragOffset = CGPoint(x: dx, y: dy)
    }
    
    func endDragging(at point: CGPoint) {
        guard let topic = draggedTopic else { return }
        
        let finalPosition = CGPoint(
            x: topic.position.x + dragOffset.x,
            y: topic.position.y + dragOffset.y
        )
        
        onDragEnd(topic, finalPosition)
        resetDrag()
    }
    
    func cancelDrag() {
        onDragCancel()
        resetDrag()
    }
    
    private func resetDrag() {
        isDragging = false
        draggedTopic = nil
        dragOffset = .zero
        dragStartPosition = nil
        dragStartScale = nil
    }
    
    func getDragPreviewPosition(for topic: Topic) -> CGPoint {
        guard isDragging else { return topic.position }
        return CGPoint(
            x: topic.position.x + dragOffset.x,
            y: topic.position.y + dragOffset.y
        )
    }
    
    func getDragPreviewOpacity() -> Double {
        isDragging ? 0.7 : 1.0
    }
} 