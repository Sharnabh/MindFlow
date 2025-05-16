import Foundation
import SwiftUI

// A simple extension with a patched version of addTopicAsChild
extension TopicService {
    // Add the required private functions from TopicService to make them available in this extension
    
    // Calculate position for a new subtopic - copied from the original implementation
    fileprivate func calculatePositionForNewSubtopic(_ parentTopic: Topic) -> CGPoint {
        let subtopicOffset: CGFloat = 150
        
        // Default position is to the right of the parent
        var position = CGPoint(
            x: parentTopic.position.x + subtopicOffset,
            y: parentTopic.position.y
        )
        
        // If there are existing subtopics, position below the last one
        if !parentTopic.subtopics.isEmpty {
            let lastSubtopic = parentTopic.subtopics.last!
            position.y = lastSubtopic.position.y + 60 // Vertical spacing
        }
        
        return position
    }
    
    // Update a topic at the specified path - modified to handle immutable topics property
    fileprivate func updateTopicAtPath(_ topic: Topic, path: TopicPath) {
        var updatedTopics = self.topics
        
        if path.isEmpty {
            // It's a main topic
            if path.mainTopicIndex < updatedTopics.count {
                updatedTopics[path.mainTopicIndex] = topic
                // Update the actual topics array with our modified version
                self.updateAllTopics(updatedTopics)
            }
            return
        }
        
        // It's a subtopic
        var mainTopic = updatedTopics[path.mainTopicIndex]
        updateSubtopicAtIndices(topic, indices: path.subtopicIndices, in: &mainTopic)
        updatedTopics[path.mainTopicIndex] = mainTopic
        // Update the actual topics array with our modified version
        self.updateAllTopics(updatedTopics)
    }
    
    // Recursively update a subtopic at the specified indices
    fileprivate func updateSubtopicAtIndices(_ updatedTopic: Topic, indices: [Int], in topic: inout Topic) {
        var currentIndices = indices
        
        // If we've reached the target depth
        if currentIndices.count == 1 {
            let index = currentIndices[0]
            if index < topic.subtopics.count {
                topic.subtopics[index] = updatedTopic
            }
            return
        }
        
        // Otherwise, continue recursively
        let index = currentIndices.removeFirst()
        if index < topic.subtopics.count {
            var subtopic = topic.subtopics[index]
            updateSubtopicAtIndices(updatedTopic, indices: currentIndices, in: &subtopic)
            topic.subtopics[index] = subtopic
        }
    }
    
    // Recursively remove a subtopic from the hierarchy
    fileprivate func removeSubtopicRecursively(id: UUID, from topic: inout Topic) -> Bool {
        // Check direct children
        if let index = topic.subtopics.firstIndex(where: { $0.id == id }) {
            topic.subtopics.remove(at: index)
            return true
        }
        
        // Check deeper in the hierarchy
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            if removeSubtopicRecursively(id: id, from: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    // A more reliable version of addTopicAsChild that avoids the B->A disappearing issue
    func fixedAddTopicAsChild(parentId: UUID, childId: UUID) {
        // Get parent and child topics
        guard let parentPath = findTopicPath(id: parentId),
              let childPath = findTopicPath(id: childId) else { return }
        
        // Don't allow making a topic its own child
        if parentId == childId { return }
        
        // Don't create cycles
        if hasParentChildCycle(parentId: parentId, childId: childId) { return }
        
        // Create complete copies of both topics
        var parentTopic = parentPath.topic
        let childTopicCopy = childPath.topic.deepCopy()
        
        // Keep the original child ID for selection and relation updates
        let originalChildId = childId
        
        // Update the child topic properties for its new role as subtopic
        var updatedChildTopic = childTopicCopy
        updatedChildTopic.parentId = parentTopic.id
        updatedChildTopic.position = calculatePositionForNewSubtopic(parentTopic)
        
        // First add the child to the parent
        parentTopic.subtopics.append(updatedChildTopic)
        
        // Update the parent in the hierarchy
        updateTopicAtPath(parentTopic, path: parentPath.path)
        
        // Now that the parent update is complete with the child added, we need to remove the original child
        // Create a new mutable array of all topics
        var updatedTopics = self.getAllTopics()
        
        // Filter out the original child topic
        updatedTopics = updatedTopics.filter { $0.id != childId }
        
        // Update all topics with the filtered list
        self.updateAllTopics(updatedTopics)
        
        // Select the topic that was moved
        self.selectTopic(withId: originalChildId)
        
        // Ensure all views update
        onTopicsChanged?()
        
        // Post a notification that topics have changed
        NotificationCenter.default.post(name: Notification.Name("TopicsChanged"), object: nil)
    }
}
