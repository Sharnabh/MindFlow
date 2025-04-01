import SwiftUI
import AppKit

class TopicRotationViewModel: ObservableObject {
    @Published var isRotating: Bool = false
    @Published var rotatedTopic: Topic?
    @Published var rotationStartAngle: Double?
    @Published var rotationStartPosition: CGPoint?
    @Published var rotationStartScale: CGFloat?
    @Published var rotationError: String?
    
    private var startRotation: CGFloat = 0
    private var currentRotation: CGFloat = 0
    
    let onRotationStart: (Topic) -> Void
    let onRotationEnd: (Topic, Double) -> Void
    let onRotationCancel: () -> Void
    
    init(onRotationStart: @escaping (Topic) -> Void, onRotationEnd: @escaping (Topic, Double) -> Void, onRotationCancel: @escaping () -> Void) {
        self.onRotationStart = onRotationStart
        self.onRotationEnd = onRotationEnd
        self.onRotationCancel = onRotationCancel
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRotationStart),
            name: NSNotification.Name("RotationStart"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRotationMove),
            name: NSNotification.Name("RotationMove"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRotationEnd),
            name: NSNotification.Name("RotationEnd"),
            object: nil
        )
    }
    
    @objc private func handleRotationStart(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let topic = userInfo["topic"] as? Topic,
              let start = userInfo["start"] as? CGPoint,
              let scale = userInfo["scale"] as? CGFloat else { return }
        
        isRotating = true
        rotatedTopic = topic
        rotationStartPosition = start
        rotationStartScale = scale
        rotationStartAngle = calculateRotationAngle(from: start, scale: scale)
        currentRotation = topic.rotation
        onRotationStart(topic)
    }
    
    @objc private func handleRotationMove(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let topic = userInfo["topic"] as? Topic,
              let current = userInfo["current"] as? CGPoint,
              let scale = userInfo["scale"] as? CGFloat else { return }
        
        let newRotation = calculateRotationAngle(from: current, scale: scale)
        let deltaAngle = newRotation - startRotation
        
        // Create a new topic with updated rotation
        var updatedTopic = topic
        updatedTopic.rotation = currentRotation + deltaAngle
        
        // Post notification with updated topic
        NotificationCenter.default.post(
            name: NSNotification.Name("TopicUpdated"),
            object: nil,
            userInfo: ["topic": updatedTopic]
        )
    }
    
    @objc private func handleRotationEnd(_ notification: Notification) {
        isRotating = false
        rotatedTopic = nil
        rotationStartAngle = nil
        rotationStartPosition = nil
        rotationStartScale = nil
    }
    
    func endRotating() {
        guard let topic = rotatedTopic,
              let startAngle = rotationStartAngle else { return }
        
        let finalRotation = topic.rotation + startAngle
        onRotationEnd(topic, finalRotation)
        resetRotation()
    }
    
    func cancelRotation() {
        onRotationCancel()
        resetRotation()
    }
    
    private func resetRotation() {
        isRotating = false
        rotatedTopic = nil
        rotationStartAngle = nil
        rotationStartPosition = nil
        rotationStartScale = nil
    }
    
    private func calculateRotationAngle(from point: CGPoint, scale: CGFloat) -> CGFloat {
        let center = CGPoint(x: 0, y: 0)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return atan2(dy, dx)
    }
    
    func getRotationPreviewAngle(for topic: Topic) -> Double {
        guard isRotating,
              let startAngle = rotationStartAngle else { return topic.rotation }
        return topic.rotation + startAngle
    }
    
    func getRotationPreviewOpacity() -> Double {
        isRotating ? 0.7 : 1.0
    }
    
    func getRotationHandlePosition(for topic: Topic) -> CGPoint {
        let size = topic.size
        let radius = sqrt(size.width * size.width + size.height * size.height) / 2
        let angle = getRotationPreviewAngle(for: topic)
        
        return CGPoint(
            x: topic.position.x + radius * cos(angle),
            y: topic.position.y + radius * sin(angle)
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 