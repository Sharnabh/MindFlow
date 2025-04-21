import SwiftUI
import AppKit

class LayoutViewModel: ObservableObject {
    @Published var topics: [Topic] = []
    @Published var selectedTopicId: UUID?
    @Published var dragState: DragState = .none
    
    private var dragStartPosition: CGPoint?
    private var dragStartTopicPosition: CGPoint?
    private var dragStartTopic: Topic?
    private var dragStartTopicIndex: Int?
    private var dragStartSubtopicPath: [Int]?
    
    // MARK: - Drag State
    
    enum DragState {
        case none
        case dragging(topicId: UUID)
        case draggingCanvas
    }
    
    // MARK: - Drag Handling
    
    func handleDragStart(at position: CGPoint, in topic: Topic?) {
        if let topic = topic {
            // Start dragging a topic
            dragState = .dragging(topicId: topic.id)
            dragStartPosition = position
            dragStartTopicPosition = topic.position
            dragStartTopic = topic
            
            // Find the topic's index and path
            if let index = topics.firstIndex(where: { $0.id == topic.id }) {
                dragStartTopicIndex = index
            } else {
                // Search in subtopics
                for (index, mainTopic) in topics.enumerated() {
                    if let (_, path) = findTopicAndPath(topic.id, in: mainTopic) {
                        dragStartTopicIndex = index
                        dragStartSubtopicPath = path
                        break
                    }
                }
            }
        } else {
            // Start dragging the canvas
            dragState = .draggingCanvas
            dragStartPosition = position
        }
    }
    
    func handleDragMove(to position: CGPoint) {
        switch dragState {
        case .dragging(_):
            guard let startPos = dragStartPosition,
                  let startTopicPos = dragStartTopicPosition,
                  let topic = dragStartTopic else { return }
            
            // Calculate the drag delta
            let delta = CGPoint(
                x: position.x - startPos.x,
                y: position.y - startPos.y
            )
            
            // Calculate the new position
            let newPosition = CGPoint(
                x: startTopicPos.x + delta.x,
                y: startTopicPos.y + delta.y
            )
            
            // Update the topic's position
            var updatedTopic = topic
            updatedTopic.position = newPosition
            
            // Update the topic in the hierarchy
            if let index = dragStartTopicIndex {
                if let path = dragStartSubtopicPath {
                    // Update a subtopic
                    updateSubtopicInPath(updatedTopic, at: path, in: &topics[index])
                } else {
                    // Update a main topic
                    topics[index] = updatedTopic
                }
            }
            
        case .draggingCanvas:
            // Handle canvas dragging if needed
            break
            
        case .none:
            break
        }
    }
    
    func handleDragEnd() {
        dragState = .none
        dragStartPosition = nil
        dragStartTopicPosition = nil
        dragStartTopic = nil
        dragStartTopicIndex = nil
        dragStartSubtopicPath = nil
    }
    
    // MARK: - Layout
    
    func layoutTopics() {
        // Layout main topics
        for i in 0..<topics.count {
            layoutTopicAndSubtopics(&topics[i])
        }
    }
    
    private func layoutTopicAndSubtopics(_ topic: inout Topic) {
        // Layout subtopics
        for i in 0..<topic.subtopics.count {
            layoutTopicAndSubtopics(&topic.subtopics[i])
        }
        
        // Adjust position if needed
        if let parentId = topic.parentId,
           let parent = findTopic(id: parentId) {
            // Calculate ideal position relative to parent
            let idealPosition = calculateIdealPosition(for: topic, relativeTo: parent)
            
            // Only adjust if the position is significantly different
            let distance = hypot(topic.position.x - idealPosition.x, topic.position.y - idealPosition.y)
            if distance > 10 {
                topic.position = idealPosition
            }
        }
    }
    
    private func calculateIdealPosition(for topic: Topic, relativeTo parent: Topic) -> CGPoint {
        // Constants for spacing
        let horizontalSpacing: CGFloat = 200 // Space between parent and child
        let verticalSpacing: CGFloat = 60 // Space between siblings
        
        // Find the topic's index among its siblings
        let siblings = parent.subtopics
        let index = siblings.firstIndex(where: { $0.id == topic.id }) ?? 0
        
        // Calculate vertical offset based on index
        let totalSiblings = CGFloat(siblings.count)
        let verticalOffset = CGFloat(index) * verticalSpacing - (totalSiblings - 1) * verticalSpacing / 2
        
        // Calculate position
        return CGPoint(
            x: parent.position.x + horizontalSpacing,
            y: parent.position.y + verticalOffset
        )
    }
    
    // MARK: - Helper Methods
    
    private func findTopicAndPath(_ id: UUID, in topic: Topic) -> (Topic, [Int])? {
        if topic.id == id {
            return (topic, [])
        }
        
        for (index, subtopic) in topic.subtopics.enumerated() {
            if let (found, path) = findTopicAndPath(id, in: subtopic) {
                return (found, [index] + path)
            }
        }
        
        return nil
    }
    
    private func findTopic(id: UUID) -> Topic? {
        // Check main topics
        if let topic = topics.first(where: { $0.id == id }) {
            return topic
        }
        
        // Check subtopics
        for topic in topics {
            if let found = findTopicInHierarchy(id: id, in: topic) {
                return found
            }
        }
        
        return nil
    }
    
    private func findTopicInHierarchy(id: UUID, in topic: Topic) -> Topic? {
        if topic.id == id {
            return topic
        }
        
        for subtopic in topic.subtopics {
            if let found = findTopicInHierarchy(id: id, in: subtopic) {
                return found
            }
        }
        
        return nil
    }
    
    private func updateSubtopicInPath(_ updatedTopic: Topic, at path: [Int], in topic: inout Topic) {
        var currentTopic = topic
        var currentPath = path
        
        while !currentPath.isEmpty {
            let index = currentPath.removeFirst()
            if index < currentTopic.subtopics.count {
                if currentPath.isEmpty {
                    // We've reached the target subtopic
                    currentTopic.subtopics[index] = updatedTopic
                } else {
                    // Continue down the path
                    var subtopic = currentTopic.subtopics[index]
                    updateSubtopicInPath(updatedTopic, at: currentPath, in: &subtopic)
                    currentTopic.subtopics[index] = subtopic
                }
            }
        }
        
        topic = currentTopic
    }
} 
