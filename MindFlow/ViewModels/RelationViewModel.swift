import SwiftUI

class RelationViewModel: ObservableObject {
    @Published var topics: [Topic] = []
    @Published var relationDragState: (fromId: UUID, toPosition: CGPoint)?
    
    // MARK: - Relation Management
    
    func addRelation(from sourceId: UUID, to targetId: UUID) {
        // Find the source topic
        guard let (sourceTopic, sourcePath) = findTopicAndPath(sourceId) else { return }
        
        // Find the target topic
        guard findTopic(id: targetId) != nil else { return }
        
        // Check if the relation already exists
        if sourceTopic.relations.contains(targetId) {
            return
        }
        
        // Add the relation
        var updatedSourceTopic = sourceTopic
        updatedSourceTopic.addRelation(targetId)
        
        // Update the topic in the hierarchy
        if let (index, path) = sourcePath {
            if path.isEmpty {
                // Update a main topic
                topics[index] = updatedSourceTopic
            } else {
                // Update a subtopic
                updateSubtopicInPath(updatedSourceTopic, at: path, in: &topics[index])
            }
        }
    }
    
    func removeRelation(from sourceId: UUID, to targetId: UUID) {
        // Find the source topic
        guard let (sourceTopic, sourcePath) = findTopicAndPath(sourceId) else { return }
        
        // Remove the relation
        var updatedSourceTopic = sourceTopic
        updatedSourceTopic.removeRelation(targetId)
        
        // Update the topic in the hierarchy
        if let (index, path) = sourcePath {
            if path.isEmpty {
                // Update a main topic
                topics[index] = updatedSourceTopic
            } else {
                // Update a subtopic
                updateSubtopicInPath(updatedSourceTopic, at: path, in: &topics[index])
            }
        }
    }
    
    func removeAllRelations(to targetId: UUID) {
        // Remove relations to this topic from all main topics
        for i in 0..<topics.count {
            var topic = topics[i]
            topic.removeRelation(targetId)
            removeRelationsToTopicInSubtopics(targetId, in: &topic)
            topics[i] = topic
        }
    }
    
    func startRelationDrag(from sourceId: UUID, to position: CGPoint) {
        relationDragState = (sourceId, position)
    }
    
    func updateRelationDrag(to position: CGPoint) {
        if relationDragState != nil {
            relationDragState?.toPosition = position
        }
    }
    
    func endRelationDrag() {
        relationDragState = nil
    }
    
    // MARK: - Helper Methods
    
    private func findTopicAndPath(_ id: UUID) -> (Topic, (Int, [Int])?)? {
        // Check main topics
        if let index = topics.firstIndex(where: { $0.id == id }) {
            return (topics[index], (index, []))
        }
        
        // Check subtopics
        for (index, topic) in topics.enumerated() {
            if let (found, path) = findTopicAndPathInHierarchy(id, in: topic) {
                return (found, (index, path))
            }
        }
        
        return nil
    }
    
    private func findTopicAndPathInHierarchy(_ id: UUID, in topic: Topic) -> (Topic, [Int])? {
        if topic.id == id {
            return (topic, [])
        }
        
        for (index, subtopic) in topic.subtopics.enumerated() {
            if let (found, path) = findTopicAndPathInHierarchy(id, in: subtopic) {
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
    
    private func removeRelationsToTopicInSubtopics(_ id: UUID, in topic: inout Topic) {
        // Remove relations to this topic from all subtopics
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            subtopic.removeRelation(id)
            removeRelationsToTopicInSubtopics(id, in: &subtopic)
            topic.subtopics[i] = subtopic
        }
    }
} 
