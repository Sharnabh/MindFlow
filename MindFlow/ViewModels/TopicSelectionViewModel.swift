import SwiftUI
import AppKit

class TopicSelectionViewModel: ObservableObject {
    @Published var selectedTopics: Set<Topic> = []
    @Published var selectionRect: CGRect?
    @Published var isSelecting: Bool = false
    @Published var startPoint: CGPoint?
    @Published var currentPoint: CGPoint?
    @Published var selectionError: String?
    
    let onSelectionChange: (Set<Topic>) -> Void
    
    init(onSelectionChange: @escaping (Set<Topic>) -> Void) {
        self.onSelectionChange = onSelectionChange
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSelectionChange),
            name: NSNotification.Name("SelectionChange"),
            object: nil
        )
    }
    
    @objc private func handleSelectionChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let topics = userInfo["topics"] as? Set<Topic> else { return }
        
        updateSelection(to: topics)
    }
    
    func startSelection(at point: CGPoint) {
        isSelecting = true
        startPoint = point
        currentPoint = point
        selectionRect = CGRect(origin: point, size: .zero)
    }
    
    func updateSelection(at point: CGPoint) {
        guard let start = startPoint else { return }
        currentPoint = point
        
        let rect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(point.x - start.x),
            height: abs(point.y - start.y)
        )
        selectionRect = rect
    }
    
    func endSelection() {
        isSelecting = false
        startPoint = nil
        currentPoint = nil
        selectionRect = nil
    }
    
    func updateSelection(to topics: Set<Topic>) {
        selectedTopics = topics
        selectionError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("SelectionChanged"),
            object: nil,
            userInfo: ["topics": topics]
        )
    }
    
    func toggleSelection(_ topic: Topic) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        } else {
            selectedTopics.insert(topic)
        }
        
        updateSelection(to: selectedTopics)
    }
    
    func clearSelection() {
        selectedTopics.removeAll()
        updateSelection(to: selectedTopics)
    }
    
    func selectTopicsInRect(_ topics: [Topic], scale: CGFloat) {
        guard let rect = selectionRect else { return }
        
        let scaledRect = CGRect(
            x: rect.origin.x / scale,
            y: rect.origin.y / scale,
            width: rect.width / scale,
            height: rect.height / scale
        )
        
        for topic in topics {
            let topicRect = CGRect(
                x: topic.position.x - topic.size.width / 2,
                y: topic.position.y - topic.size.height / 2,
                width: topic.size.width,
                height: topic.size.height
            )
            
            if scaledRect.intersects(topicRect) {
                selectedTopics.insert(topic)
            }
        }
        
        updateSelection(to: selectedTopics)
    }
    
    func isTopicSelected(_ topic: Topic) -> Bool {
        selectedTopics.contains(topic)
    }
    
    func getSelectionPath() -> Path? {
        guard let rect = selectionRect else { return nil }
        return Path(rect)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 