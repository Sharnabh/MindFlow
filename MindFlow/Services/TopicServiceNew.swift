import Foundation
import SwiftUI

// A simple extension with a patched version of addTopicAsChild
extension TopicService {
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
        
        // Then remove the original child - only after it has been safely added as a subtopic
        if childPath.path.isEmpty {
            // It's a main topic, remove from topics array
            if let index = topics.firstIndex(where: { $0.id == childId }) {
                topics.remove(at: index)
            }
        } else {
            // It's a subtopic, remove from its current parent
            let _ = removeSubtopicRecursively(id: childId, from: &topics[childPath.path.mainTopicIndex])
        }
        
        // Ensure we maintain the selection if this topic was selected
        if selectedTopicId == originalChildId {
            selectedTopicId = originalChildId
        }
        
        // Ensure all views update
        onTopicsChanged?()
        
        // Post a notification that topics have changed
        NotificationCenter.default.post(name: Notification.Name("TopicsChanged"), object: nil)
    }
}
