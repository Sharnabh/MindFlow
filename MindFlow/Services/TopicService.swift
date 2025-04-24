import Foundation
import SwiftUI

// Protocol defining topic management operations
protocol TopicServiceProtocol {
    // Read operations
    var topics: [Topic] { get }
    func getTopic(withId id: UUID) -> Topic?
    func findTopicPath(id: UUID) -> (topic: Topic, path: TopicPath)?
    func getAllTopics() -> [Topic]
    
    // Write operations
    func addMainTopic(at position: CGPoint) -> Topic
    func addSubtopic(to parentId: UUID) -> Topic?
    func updateTopic(_ topic: Topic)
    func deleteTopic(withId id: UUID)
    func moveTopic(withId id: UUID, to position: CGPoint)
    
    // Relations
    func addRelation(from sourceId: UUID, to targetId: UUID)
    func removeRelation(from sourceId: UUID, to targetId: UUID)
    func removeAllRelationsToTopic(withId id: UUID)
    
    // State
    func selectTopic(withId id: UUID?)
    var selectedTopicId: UUID? { get }
    func beginEditingTopic(withId id: UUID)
    func endEditingTopic(withId id: UUID)
    func collapseExpandTopic(withId id: UUID)
    
    // Clipboard operations
    func copyTopic(withId id: UUID)
    func pasteTopic(at position: CGPoint) -> Topic?
    
    // Theme
    func applyThemeToTopic(withId id: UUID, fillColor: Color?, borderColor: Color?, textColor: Color?)
    func applyThemeToAllTopics(fillColor: Color?, borderColor: Color?, textColor: Color?)
    
    // Additional operations needed by TopicView
    func isOrphanTopic(_ topic: Topic) -> Bool
    func hasParentChildCycle(parentId: UUID, childId: UUID) -> Bool
    func addTopicAsChild(parentId: UUID, childId: UUID)
    func removeParentChildRelation(childId: UUID)
    func addTopic(_ topic: Topic)
    func updateAllTopics(_ newTopics: [Topic])
    
    // Collaboration
    func enableCollaboration(documentId: String)
    func disableCollaboration()
    func getCurrentDocumentId() -> String?
    var isCollaborating: Bool { get }
}

// Represents a path to a topic in the hierarchy
struct TopicPath {
    let mainTopicIndex: Int
    let subtopicIndices: [Int]
    
    var isEmpty: Bool {
        return subtopicIndices.isEmpty
    }
}

// Main implementation of the TopicService
class TopicService: TopicServiceProtocol, ObservableObject {
    @Published private(set) var topics: [Topic] = []
    @Published private(set) var selectedTopicId: UUID?
    
    // For clipboard operations
    private var copiedTopic: Topic?
    private var mainTopicCount = 0
    
    // Callback when topics are changed
    var onTopicsChanged: (() -> Void)? = nil
    
    // Reference to the change tracker for collaborative editing
    private var changeTracker: TopicChangeTracker?
    private var isCollaborationEnabled: Bool = false
    private var currentDocumentId: String?
    
    // Computed property to expose collaboration state
    var isCollaborating: Bool {
        return isCollaborationEnabled
    }
    
    // Initialize with optional dependency injection for the change tracker
    init(changeTracker: TopicChangeTracker? = nil) {
        self.changeTracker = changeTracker
        
        // Register for remote change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: NSNotification.Name("ApplyRemoteTopicChange"),
            object: nil
        )
    }
    
    // MARK: - Collaboration
    
    func enableCollaboration(documentId: String) {
        guard let changeTracker = changeTracker else {
            print("Cannot enable collaboration: change tracker not available")
            return
        }
        
        self.isCollaborationEnabled = true
        self.currentDocumentId = documentId
        changeTracker.startTracking(for: documentId)
    }
    
    func disableCollaboration() {
        isCollaborationEnabled = false
        currentDocumentId = nil
        changeTracker?.stopTracking()
    }
    
    func getCurrentDocumentId() -> String? {
        return currentDocumentId
    }
    
    @objc private func handleRemoteChange(_ notification: Notification) {
        guard let change = notification.userInfo?["change"] as? TopicChange else {
            return
        }
        
        DispatchQueue.main.async {
            self.applyRemoteChange(change)
        }
    }
    
    private func applyRemoteChange(_ change: TopicChange) {
        // Convert UUID string to UUID
        guard let topicId = UUID(uuidString: change.topicId) else { return }
        
        switch change.changeType {
        case .create:
            applyRemoteTopicCreation(change, topicId: topicId)
        case .update:
            applyRemoteTopicUpdate(change, topicId: topicId)
        case .delete:
            deleteTopic(withId: topicId)
        case .move:
            applyRemoteTopicMove(change, topicId: topicId)
        case .connect:
            applyRemoteTopicConnection(change)
        case .disconnect:
            applyRemoteTopicDisconnection(change)
        }
    }
    
    private func applyRemoteTopicCreation(_ change: TopicChange, topicId: UUID) {
        // Extract topic properties from the change
        guard let nameValue = change.properties["name"]?.unwrapped as? String,
              let positionDict = change.properties["position"]?.unwrapped as? [String: CGFloat],
              let x = positionDict["x"],
              let y = positionDict["y"] else {
            return
        }
        
        let position = CGPoint(x: x, y: y)
        
        // Extract optional properties
        let templateTypeStr = change.properties["templateType"]?.unwrapped as? String ?? TemplateType.mindMap.rawValue
        let templateType = TemplateType(rawValue: templateTypeStr) ?? .mindMap
        
        var parentId: UUID? = nil
        if let parentIdStr = change.properties["parentId"]?.unwrapped as? String {
            parentId = UUID(uuidString: parentIdStr)
        }
        
        // Create the topic
        var topic = Topic(
            id: topicId,
            name: nameValue,
            position: position,
            parentId: parentId,
            templateType: templateType
        )
        
        // Extract color information if available
        if let colorHex = change.properties["color"]?.unwrapped as? String, !colorHex.isEmpty {
            let color = Color(hex: colorHex) ?? .blue
            topic.backgroundColor = color
            topic.borderColor = color
        }
        
        // Add notes if available
        if let notes = change.properties["notes"]?.unwrapped as? String {
            topic.note = Note(content: notes)
        }
        
        // Add icon if available
        if let icon = change.properties["icon"]?.unwrapped as? String {
            topic.metadata = ["icon": icon]
        }
        
        // If it has a parent, add it as a subtopic
        if let parentId = parentId {
            if let parentPath = findTopicPath(id: parentId) {
                var parent = parentPath.topic
                parent.subtopics.append(topic)
                updateTopicAtPath(parent, path: parentPath.path)
            }
        } else {
            // Otherwise add as a main topic
            topics.append(topic)
        }
        
        onTopicsChanged?()
    }
    
    private func applyRemoteTopicUpdate(_ change: TopicChange, topicId: UUID) {
        guard let path = findTopicPath(id: topicId) else { return }
        var topic = path.topic
        
        // Update properties based on what's in the change
        if let nameValue = change.properties["name"]?.unwrapped as? String {
            topic.name = nameValue
        }
        
        if let positionDict = change.properties["position"]?.unwrapped as? [String: CGFloat],
           let x = positionDict["x"],
           let y = positionDict["y"] {
            topic.position = CGPoint(x: x, y: y)
        }
        
        if let colorHex = change.properties["color"]?.unwrapped as? String, !colorHex.isEmpty {
            let color = Color(hex: colorHex) ?? topic.backgroundColor
            topic.backgroundColor = color
            topic.borderColor = color
        }
        
        if let notes = change.properties["notes"]?.unwrapped as? String {
            topic.note = Note(content: notes)
        }
        
        if let icon = change.properties["icon"]?.unwrapped as? String {
            if topic.metadata == nil {
                topic.metadata = ["icon": icon]
            } else {
                topic.metadata?["icon"] = icon
            }
        }
        
        updateTopicAtPath(topic, path: path.path)
        onTopicsChanged?()
    }
    
    private func applyRemoteTopicMove(_ change: TopicChange, topicId: UUID) {
        // Extract position
        guard let positionDict = change.properties["position"]?.unwrapped as? [String: CGFloat],
              let x = positionDict["x"],
              let y = positionDict["y"] else {
            return
        }
        
        let newPosition = CGPoint(x: x, y: y)
        moveTopic(withId: topicId, to: newPosition)
    }
    
    private func applyRemoteTopicConnection(_ change: TopicChange) {
        // Extract parent and child IDs
        guard let parentIdStr = change.properties["parentId"]?.unwrapped as? String,
              let childIdStr = change.properties["childId"]?.unwrapped as? String,
              let parentId = UUID(uuidString: parentIdStr),
              let childId = UUID(uuidString: childIdStr) else {
            return
        }
        
        addTopicAsChild(parentId: parentId, childId: childId)
    }
    
    private func applyRemoteTopicDisconnection(_ change: TopicChange) {
        // Extract child ID
        guard let childIdStr = change.properties["childId"]?.unwrapped as? String,
              let childId = UUID(uuidString: childIdStr) else {
            return
        }
        
        removeParentChildRelation(childId: childId)
    }
    
    // MARK: - Topic Retrieval
    
    func getTopic(withId id: UUID) -> Topic? {
        // Check main topics first
        if let topic = topics.first(where: { $0.id == id }) {
            return topic
        }
        
        // Search in subtopics recursively
        for topic in topics {
            if let found = findTopicInHierarchy(id: id, in: topic) {
                return found
            }
        }
        
        return nil
    }
    
    func findTopicPath(id: UUID) -> (topic: Topic, path: TopicPath)? {
        // Check if it's a main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            return (topics[index], TopicPath(mainTopicIndex: index, subtopicIndices: []))
        }
        
        // Search in subtopics
        for (index, topic) in topics.enumerated() {
            if let (found, indices) = findTopicAndIndicesInHierarchy(id: id, in: topic) {
                return (found, TopicPath(mainTopicIndex: index, subtopicIndices: indices))
            }
        }
        
        return nil
    }
    
    func getAllTopics() -> [Topic] {
        // Return a deep copy of all topics to prevent unintended mutations
        return topics.map { $0.deepCopy() }
    }
    
    // MARK: - Topic Manipulation
    
    func addTopic(_ topic: Topic) {
        topics.append(topic)
        
        // Track change for collaboration
        if isCollaborationEnabled {
            changeTracker?.trackTopicCreation(topic)
        }
        
        onTopicsChanged?()
    }
    
    func addMainTopic(at position: CGPoint) -> Topic {
        mainTopicCount += 1
        
        // Determine the template type to use
        // Use the template type of the first topic if available, otherwise default to mindMap
        let templateType: TemplateType = topics.first?.templateType ?? .mindMap
        
        var topic = Topic.createMainTopic(
            at: position, 
            count: mainTopicCount, 
            templateType: templateType
        )
        
        // Apply theme colors if available
        if let fillColor = Topic.themeColors.backgroundColor,
           let borderColor = Topic.themeColors.borderColor,
           let textColor = Topic.themeColors.foregroundColor {
            topic.backgroundColor = fillColor
            topic.borderColor = borderColor
            topic.foregroundColor = textColor
        }
        
        // Use existing branch style if topics exist
        if !topics.isEmpty {
            topic.branchStyle = topics[0].branchStyle
        }
        
        topics.append(topic)
        
        // Select the new topic
        selectedTopicId = topic.id
        
        // Track change for collaboration
        if isCollaborationEnabled {
            changeTracker?.trackTopicCreation(topic)
        }
        
        onTopicsChanged?()
        
        return topic
    }
    
    func addSubtopic(to parentId: UUID) -> Topic? {
        guard let parentTopic = getTopic(withId: parentId) else { return nil }
        
        // Calculate position for new subtopic
        let subtopicPosition = calculatePositionForNewSubtopic(parentTopic)
        
        // Create the subtopic
        let count = parentTopic.subtopics.count + 1
        let subtopic = parentTopic.createSubtopic(at: subtopicPosition, count: count)
        
        // Add to parent
        if let parentPath = findTopicPath(id: parentId) {
            var parent = parentPath.topic
            parent.subtopics.append(subtopic)
            updateTopicAtPath(parent, path: parentPath.path)
            
            // Track change for collaboration
            if isCollaborationEnabled {
                changeTracker?.trackTopicCreation(subtopic)
                changeTracker?.trackTopicConnection(parentId.uuidString, childId: subtopic.id.uuidString)
            }
            
            // Return the newly created subtopic
            return subtopic
        }
        
        return nil
    }
    
    func updateTopic(_ topic: Topic) {
        guard let originalTopic = getTopic(withId: topic.id),
              let path = findTopicPath(id: topic.id)?.path else { return }
        
        updateTopicAtPath(topic, path: path)
        
        // Track change for collaboration
        if isCollaborationEnabled {
            // Determine which properties changed
            var changedProperties: [String: Any] = [:]
            
            if originalTopic.name != topic.name {
                changedProperties["name"] = topic.name
            }
            
            if originalTopic.position != topic.position {
                changedProperties["position"] = [
                    "x": topic.position.x,
                    "y": topic.position.y
                ]
            }
            
            if originalTopic.backgroundColor != topic.backgroundColor {
                changedProperties["color"] = topic.backgroundColor.hexString
            }
            
            if originalTopic.note?.content != topic.note?.content {
                changedProperties["notes"] = topic.note?.content ?? ""
            }
            
            // Only track if something actually changed
            if !changedProperties.isEmpty {
                changeTracker?.trackTopicUpdate(topic, changedProperties: changedProperties)
            }
        }
        
        onTopicsChanged?()
    }
    
    func deleteTopic(withId id: UUID) {
        // Don't allow deleting if it's the only main topic and has no subtopics
        if topics.count == 1 && topics[0].id == id && topics[0].subtopics.isEmpty {
            return
        }
        
        // Track change for collaboration before deletion
        if isCollaborationEnabled {
            changeTracker?.trackTopicDeletion(id.uuidString)
        }
        
        // Remove any relations to this topic
        removeAllRelationsToTopic(withId: id)
        
        // If it's a main topic, remove it from the topics array
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics.remove(at: index)
            
            // Update selection if needed
            if selectedTopicId == id {
                selectedTopicId = topics.isEmpty ? nil : topics[0].id
            }
            
            onTopicsChanged?()
            return
        }
        
        // Otherwise, find its parent and remove it from there
        for i in 0..<topics.count {
            var topic = topics[i]
            if removeSubtopicRecursively(id: id, from: &topic) {
                topics[i] = topic
                onTopicsChanged?()
                return
            }
        }
    }
    
    func moveTopic(withId id: UUID, to position: CGPoint) {
        guard let path = findTopicPath(id: id) else { return }
        var topic = path.topic
        
        // Store original position for change tracking
        let originalPosition = topic.position
        
        topic.position = position
        updateTopicAtPath(topic, path: path.path)
        
        // Track change for collaboration
        if isCollaborationEnabled && originalPosition != position {
            changeTracker?.trackTopicMovement(id.uuidString, newPosition: position)
        }
        
        onTopicsChanged?()
    }
    
    // MARK: - Relations
    
    func addRelation(from sourceId: UUID, to targetId: UUID) {
        // Prevent adding relation to self
        if sourceId == targetId { return }

        // Ensure both topics exist
        guard let sourcePath = findTopicPath(id: sourceId),
              let _ = getTopic(withId: targetId) else { return }

        // Check if relation already exists
        var source = sourcePath.topic
        if source.relations.contains(targetId) {
            return
        }

        // Add relation (using ID)
        source.addRelation(targetId)
        updateTopicAtPath(source, path: sourcePath.path)
        
        // Track change for collaboration
        if isCollaborationEnabled {
            let changedProperties: [String: Any] = [
                "relation": targetId.uuidString,
                "action": "add"
            ]
            changeTracker?.trackTopicUpdate(source, changedProperties: changedProperties)
        }
    }

    func removeRelation(from sourceId: UUID, to targetId: UUID) {
        guard let sourcePath = findTopicPath(id: sourceId) else { return }

        var source = sourcePath.topic
        // Remove relation (using ID)
        source.removeRelation(targetId)
        updateTopicAtPath(source, path: sourcePath.path)
        
        // Track change for collaboration
        if isCollaborationEnabled {
            let changedProperties: [String: Any] = [
                "relation": targetId.uuidString,
                "action": "remove"
            ]
            changeTracker?.trackTopicUpdate(source, changedProperties: changedProperties)
        }
    }
    
    func removeAllRelationsToTopic(withId id: UUID) {
        // Remove relations in all main topics
        for i in 0..<topics.count {
            var topic = topics[i]
            // Remove relation (using ID)
            topic.removeRelation(id)
            removeRelationsToTopicInSubtopics(id, in: &topic)
            topics[i] = topic
        }
    }

    // Helper to remove relations recursively from subtopics
    private func removeRelationsToTopicInSubtopics(_ topicIdToRemove: UUID, in topic: inout Topic) {
        topic.removeRelation(topicIdToRemove)
        for i in 0..<topic.subtopics.count {
            removeRelationsToTopicInSubtopics(topicIdToRemove, in: &topic.subtopics[i])
        }
    }
    
    func addTopicAsChild(parentId: UUID, childId: UUID) {
        // Get parent and child topics
        guard let parentPath = findTopicPath(id: parentId),
              let childPath = findTopicPath(id: childId) else { return }
        
        // Don't allow making a topic its own child
        if parentId == childId { return }
        
        // Don't create cycles
        if hasParentChildCycle(parentId: parentId, childId: childId) { return }
        
        // Get copies of both topics
        var parentTopic = parentPath.topic
        var childTopic = childPath.topic
        
        // Remove child from its current location
        // If it's a main topic, remove from topics array
        if childPath.path.isEmpty {
            if let index = topics.firstIndex(where: { $0.id == childId }) {
                topics.remove(at: index)
            }
        } else {
            // It's a subtopic, remove from its current parent
            let _ = removeSubtopicRecursively(id: childId, from: &topics[childPath.path.mainTopicIndex])
        }
        
        // Update child's parent reference and position
        childTopic.parentId = parentTopic.id
        
        // Calculate a good position for the child topic
        let newPosition = calculatePositionForNewSubtopic(parentTopic)
        childTopic.position = newPosition
        
        // Add child to parent's subtopics
        parentTopic.subtopics.append(childTopic)
        
        // Update parent in the hierarchy
        updateTopicAtPath(parentTopic, path: parentPath.path)
        
        // Track change for collaboration
        if isCollaborationEnabled {
            changeTracker?.trackTopicConnection(parentId.uuidString, childId: childId.uuidString)
        }
    }
    
    func removeParentChildRelation(childId: UUID) {
        guard let childPath = findTopicPath(id: childId) else { return }
        
        // Only applicable to subtopics with a parent
        if childPath.path.isEmpty { return }
        
        // Get the child topic
        var childTopic = childPath.topic
        
        // Store the parent ID for change tracking
        let parentId = childTopic.parentId
        
        // Remove child from its current location
        let _ = removeSubtopicRecursively(id: childId, from: &topics[childPath.path.mainTopicIndex])
        
        // Reset parent reference
        childTopic.parentId = nil
        
        // Calculate a new position for the main topic
        // Move it slightly away from existing topics
        let offset: CGFloat = 100
        var newPosition = childTopic.position
        newPosition.x += offset
        newPosition.y += offset
        childTopic.position = newPosition
        
        // Add as a main topic
        topics.append(childTopic)
        
        // Track change for collaboration
        if isCollaborationEnabled, let parentId = parentId {
            changeTracker?.trackTopicDisconnection(parentId.uuidString, childId: childId.uuidString)
        }
    }
    
    // MARK: - Clipboard Operations
    
    func copyTopic(withId id: UUID) {
        guard let topic = getTopic(withId: id) else { return }
        copiedTopic = topic.deepCopy()
    }
    
    func pasteTopic(at position: CGPoint) -> Topic? {
        guard let template = copiedTopic else { return nil }
        
        // Create a new instance based on the copied topic
        var newTopic = template.deepCopy()
        newTopic.id = UUID() // New ID
        newTopic.position = position
        newTopic.isSelected = false
        newTopic.isEditing = false
        newTopic.parentId = nil
        newTopic.relations = [] // Don't copy relations
        
        // Also generate new IDs for all subtopics
        regenerateIdsForSubtopics(in: &newTopic)
        
        // Add to main topics
        topics.append(newTopic)
        return newTopic
    }
    
    // MARK: - Theme Management
    
    func applyThemeToTopic(withId id: UUID, fillColor: Color?, borderColor: Color?, textColor: Color?) {
        guard let path = findTopicPath(id: id) else { return }
        var topic = path.topic
        
        if let fillColor = fillColor {
            topic.backgroundColor = fillColor
        }
        
        if let borderColor = borderColor {
            topic.borderColor = borderColor
        }
        
        if let textColor = textColor {
            topic.foregroundColor = textColor
        }
        
        updateTopicAtPath(topic, path: path.path)
    }
    
    func applyThemeToAllTopics(fillColor: Color?, borderColor: Color?, textColor: Color?) {
        // Update static theme properties
        Topic.themeColors = (fillColor, borderColor, textColor)
        
        // Apply to existing topics
        for i in 0..<topics.count {
            var topic = topics[i]
            applyThemeRecursively(
                to: &topic,
                fillColor: fillColor,
                borderColor: borderColor,
                textColor: textColor
            )
            topics[i] = topic
        }
    }
    
    // Method to update all topics at once
    func updateAllTopics(_ newTopics: [Topic]) {
        // Replace all topics with the new array
        topics = newTopics
        onTopicsChanged?()
    }
    
    // MARK: - Helper Methods
    
    // Find a topic by ID in the hierarchy
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
    
    // Find a topic and its path in the hierarchy
    private func findTopicAndIndicesInHierarchy(id: UUID, in topic: Topic) -> (Topic, [Int])? {
        if topic.id == id {
            return (topic, [])
        }
        
        for (index, subtopic) in topic.subtopics.enumerated() {
            if let (found, path) = findTopicAndIndicesInHierarchy(id: id, in: subtopic) {
                return (found, [index] + path)
            }
        }
        
        return nil
    }
    
    // Check if a topic is an ancestor of another topic
    private func isAncestor(potentialAncestorId: UUID, ofTopicId topicId: UUID) -> Bool {
        guard let topic = getTopic(withId: topicId) else { return false }
        
        // If topic has no parent, it's not a descendant of anything
        guard let parentId = topic.parentId else { return false }
        
        // If the parent is the potential ancestor, we found a cycle
        if parentId == potentialAncestorId {
            return true
        }
        
        // Recursively check if the parent has the potential ancestor as its ancestor
        return isAncestor(potentialAncestorId: potentialAncestorId, ofTopicId: parentId)
    }
    
    // Update a topic at the specified path
    private func updateTopicAtPath(_ topic: Topic, path: TopicPath) {
        if path.isEmpty {
            // It's a main topic
            if path.mainTopicIndex < topics.count {
                topics[path.mainTopicIndex] = topic
            }
            return
        }
        
        // It's a subtopic
        var mainTopic = topics[path.mainTopicIndex]
        updateSubtopicAtIndices(topic, indices: path.subtopicIndices, in: &mainTopic)
        topics[path.mainTopicIndex] = mainTopic
    }
    
    // Recursively update a subtopic at the specified indices
    private func updateSubtopicAtIndices(_ updatedTopic: Topic, indices: [Int], in topic: inout Topic) {
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
    private func removeSubtopicRecursively(id: UUID, from topic: inout Topic) -> Bool {
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
    
    // Calculate position for a new subtopic
    private func calculatePositionForNewSubtopic(_ parentTopic: Topic) -> CGPoint {
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
    
    // Regenerate IDs for all subtopics to ensure uniqueness when pasting
    private func regenerateIdsForSubtopics(in topic: inout Topic) {
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            subtopic.id = UUID()
            subtopic.parentId = topic.id
            regenerateIdsForSubtopics(in: &subtopic)
            topic.subtopics[i] = subtopic
        }
    }
    
    // Apply theme recursively to a topic and all its subtopics
    private func applyThemeRecursively(to topic: inout Topic, fillColor: Color?, borderColor: Color?, textColor: Color?) {
        if let fillColor = fillColor {
            topic.backgroundColor = fillColor
        }
        
        if let borderColor = borderColor {
            topic.borderColor = borderColor
        }
        
        if let textColor = textColor {
            topic.foregroundColor = textColor
        }
        
        // Apply to all subtopics
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            applyThemeRecursively(
                to: &subtopic,
                fillColor: fillColor,
                borderColor: borderColor,
                textColor: textColor
            )
            topic.subtopics[i] = subtopic
        }
    }
    
    // MARK: - State Management
    
    func selectTopic(withId id: UUID?) {
        // Deselect previous selection
        if let previousId = selectedTopicId, let previousPath = findTopicPath(id: previousId) {
            var previous = previousPath.topic
            previous.isSelected = false
            updateTopicAtPath(previous, path: previousPath.path)
        }
        
        // Select new topic
        selectedTopicId = id
        if let id = id, let topicPath = findTopicPath(id: id) {
            var topic = topicPath.topic
            topic.isSelected = true
            updateTopicAtPath(topic, path: topicPath.path)
        }
    }
    
    func beginEditingTopic(withId id: UUID) {
        guard let path = findTopicPath(id: id) else { return }
        var topic = path.topic
        topic.isEditing = true
        updateTopicAtPath(topic, path: path.path)
    }
    
    func endEditingTopic(withId id: UUID) {
        guard let path = findTopicPath(id: id) else { return }
        var topic = path.topic
        topic.isEditing = false
        updateTopicAtPath(topic, path: path.path)
    }
    
    func collapseExpandTopic(withId id: UUID) {
        guard let path = findTopicPath(id: id) else { return }
        var topic = path.topic
        topic.isCollapsed = !topic.isCollapsed
        updateTopicAtPath(topic, path: path.path)
    }
    
    // MARK: - Parent-Child Operations
    
    func isOrphanTopic(_ topic: Topic) -> Bool {
        // A topic is an orphan if it's a main topic (no parent)
        return topic.parentId == nil
    }
    
    func hasParentChildCycle(parentId: UUID, childId: UUID) -> Bool {
        guard getTopic(withId: parentId) != nil else { return false }
        
        // Check if the potential child is an ancestor of the parent
        return isAncestor(potentialAncestorId: childId, ofTopicId: parentId)
    }
} 
