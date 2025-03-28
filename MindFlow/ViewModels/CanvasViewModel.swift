import SwiftUI
import AppKit

class CanvasViewModel: ObservableObject {
    @Published var topics: [Topic] = []
    @Published var selectedTopicId: UUID?
    @Published var relationDragState: (fromId: UUID, toPosition: CGPoint)?
    
    // History for undo/redo
    private var history: [[Topic]] = []
    private var currentHistoryIndex: Int = -1
    private let maxHistorySize: Int = 50
    
    private var mainTopicCount = 0
    private let subtopicSpacing: CGFloat = 200 // Vertical spacing between topics at the same level
    private let subtopicOffset: CGFloat = 150 // Reduced horizontal offset between levels
    private let topicHeight: CGFloat = 60 // Height of a topic node
    private let minTopicWidth: CGFloat = 150 // Minimum width of a topic
    private let horizontalSpacing: CGFloat = 200 // Minimum horizontal spacing between main topics
    private var isDragging = false
    
    init() {
        // Initialize history with current empty state
        history.append([])
        currentHistoryIndex = 0
    }
    
    // MARK: - Topic Management
    
    func addMainTopic(at position: CGPoint) {
        saveState()
        mainTopicCount += 1
        let topic = Topic.createMainTopic(at: position, count: mainTopicCount)
        topics.append(topic)
        selectedTopicId = topic.id
    }
    
    func addSubtopic(to parentTopic: Topic) {
        saveState()
        print("Adding subtopic to parent: \(parentTopic.id), isMainTopic: \(parentTopic.parentId == nil)")
        if parentTopic.parentId == nil {
            // For main topics, add directly to the topics array
            guard let parentIndex = topics.firstIndex(where: { $0.id == parentTopic.id }) else { return }
            addSubtopicToParent(parentTopic, at: parentIndex)
        } else {
            // For nested subtopics, recursively find the parent and add the subtopic
            addNestedSubtopic(to: parentTopic)
        }
    }
    
    private func addSubtopicToParent(_ parentTopic: Topic, at parentIndex: Int) {
        print("Adding direct subtopic to main topic at index: \(parentIndex)")
        let subtopicCount = topics[parentIndex].subtopics.count
        
        // Position the new subtopic relative to its parent
        let subtopicPosition = calculateNewSubtopicPosition(for: parentTopic, subtopicCount: subtopicCount)
        
        let subtopic = parentTopic.createSubtopic(at: subtopicPosition, count: subtopicCount + 1)
        topics[parentIndex].subtopics.append(subtopic)
        
        // Reposition all subtopics to ensure proper spacing
        var updatedTopic = topics[parentIndex]
        positionSubtree(in: &updatedTopic, parentX: updatedTopic.position.x, startY: updatedTopic.position.y)
        topics[parentIndex] = updatedTopic
        
        selectedTopicId = subtopic.id
    }
    
    private func addNestedSubtopic(to parentTopic: Topic) {
        print("Adding nested subtopic to parent: \(parentTopic.id)")
        for topicIndex in 0..<topics.count {
            if var mainTopic = findAndUpdateTopicHierarchy(parentId: parentTopic.id, in: topics[topicIndex]) {
                topics[topicIndex] = mainTopic
                print("Updated main topic hierarchy at index: \(topicIndex)")
                return
            }
        }
        print("Failed to find parent topic in hierarchy")
    }
    
    private func findAndUpdateTopicHierarchy(parentId: UUID, in topic: Topic) -> Topic? {
        var updatedTopic = topic
        
        if topic.id == parentId {
            print("Found target topic, adding new subtopic")
            let subtopicCount = topic.subtopics.count
            
            // Position the new subtopic relative to its parent
            let subtopicPosition = calculateNewSubtopicPosition(for: topic, subtopicCount: subtopicCount)
            
            let subtopic = topic.createSubtopic(at: subtopicPosition, count: subtopicCount + 1)
            updatedTopic.subtopics.append(subtopic)
            selectedTopicId = subtopic.id
            return updatedTopic
        }
        
        for i in 0..<topic.subtopics.count {
            if let updatedSubtopic = findAndUpdateTopicHierarchy(parentId: parentId, in: topic.subtopics[i]) {
                updatedTopic.subtopics[i] = updatedSubtopic
                return updatedTopic
            }
        }
        
        return nil
    }
    
    private func calculateNewSubtopicPosition(for parentTopic: Topic, subtopicCount: Int) -> CGPoint {
        // Constants for spacing
        let horizontalSpacing: CGFloat = 200 // Space between parent and child
        let verticalSpacing: CGFloat = 60 // Space between siblings
        
        // Calculate the total height needed for all subtopics
        let totalSubtopics = subtopicCount + 1 // Including the new subtopic
        let totalHeight = verticalSpacing * CGFloat(totalSubtopics - 1)
        
        // Calculate the starting Y position (top-most subtopic)
        let startY = parentTopic.position.y + totalHeight/2
        
        // Calculate this subtopic's Y position
        let y = startY - (CGFloat(subtopicCount) * verticalSpacing)
        
        // Position the subtopic to the right of the parent
        let x = parentTopic.position.x + horizontalSpacing
        
        // After calculating the initial position, check for overlaps with existing subtopics
        var newPosition = CGPoint(x: x, y: y)
        
        // Recursively check and adjust position if needed
        newPosition = adjustPositionForOverlap(newPosition, parentTopic: parentTopic)
        
        return newPosition
    }
    
    private func adjustPositionForOverlap(_ position: CGPoint, parentTopic: Topic) -> CGPoint {
        var adjustedPosition = position
        
        // Check for overlaps with all topics
        for topic in topics {
            // Skip the parent topic itself
            if topic.id == parentTopic.id {
                continue
            }
            
            // Check overlap with the topic and its subtopics recursively
            if let newPos = checkAndAdjustOverlap(adjustedPosition, with: topic) {
                adjustedPosition = newPos
            }
        }
        
        return adjustedPosition
    }
    
    private func checkAndAdjustOverlap(_ position: CGPoint, with topic: Topic) -> CGPoint? {
        let topicBox = getTopicBox(topic: topic)
        let newTopicBox = CGRect(
            x: position.x - 60,  // Half of typical topic width
            y: position.y - 20,  // Half of typical topic height
            width: 120,          // Typical topic width
            height: 40           // Typical topic height
        )
        
        // If there's an overlap, adjust the position
        if topicBox.intersects(newTopicBox) {
            // Move the position down by a bit more than the topic height
            return CGPoint(x: position.x, y: position.y + 70)
        }
        
        // Recursively check subtopics
        for subtopic in topic.subtopics {
            if let adjustedPos = checkAndAdjustOverlap(position, with: subtopic) {
                return adjustedPos
            }
        }
        
        return nil
    }
    
    func updateTopicName(_ id: UUID, newName: String) {
        // Skip saving state for minor text edits to avoid filling history
        // with every keystroke during editing
        if let topic = getTopicById(id), topic.name != newName && !newName.isEmpty {
            saveState()
        }
        
        // Update main topic name
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].name = newName
            return
        }
        
        // Update subtopic name recursively
        for i in 0..<topics.count {
            if updateSubtopicName(id, newName, in: &topics[i]) {
                break
            }
        }
    }
    
    private func updateSubtopicName(_ id: UUID, _ newName: String, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].name = newName
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicName(id, newName, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func selectTopic(id: UUID?) {
        // If we're selecting a different topic, clear editing state first
        if selectedTopicId != id {
            setTopicEditing(selectedTopicId, isEditing: false)
        }
        selectedTopicId = id
    }
    
    func setTopicEditing(_ id: UUID?, isEditing: Bool) {
        // Clear previous editing state
        for i in 0..<topics.count {
            clearEditingStateRecursively(in: &topics[i])
        }
        
        // Set new editing state
        if let id = id {
            // Update main topic
            if let index = topics.firstIndex(where: { $0.id == id }) {
                topics[index].isEditing = isEditing
                return
            }
            
            // Update subtopic
            for i in 0..<topics.count {
                if setSubtopicEditing(id, isEditing, in: &topics[i]) {
                    break
                }
            }
        }
    }
    
    private func clearEditingStateRecursively(in topic: inout Topic) {
        topic.isEditing = false
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            clearEditingStateRecursively(in: &subtopic)
            topic.subtopics[i] = subtopic
        }
    }
    
    private func setSubtopicEditing(_ id: UUID, _ isEditing: Bool, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].isEditing = isEditing
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if setSubtopicEditing(id, isEditing, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Topic Positioning
    
    private func repositionAllTopics() {
        guard !topics.isEmpty else { return }
        
        // Start with the first topic's position as reference
        var currentY = topics[0].position.y
        var maxX = topics[0].position.x
        
        // Position each main topic and its subtree
        for i in 0..<topics.count {
            var topic = topics[i]
            
            // Calculate the width needed for this topic's subtree
            let subtreeWidth = calculateSubtreeWidth(topic)
            let subtreeHeight = calculateSubtreeHeight(topic)
            
            // Ensure horizontal spacing from previous topic
            if i > 0 {
                topic.position = CGPoint(
                    x: maxX + horizontalSpacing + subtreeWidth/2,
                    y: currentY + subtreeHeight/2
                )
            }
            
            // Position all subtopics in this topic's subtree
            if !topic.subtopics.isEmpty {
                positionSubtree(in: &topic, parentX: topic.position.x, startY: currentY)
            }
            
            topics[i] = topic
            
            // Update maxX for next topic
            maxX = topic.position.x + subtreeWidth/2
            
            // Move to the next vertical position with proper spacing
            currentY += subtreeHeight + subtopicSpacing
        }
    }
    
    private func calculateSubtreeWidth(_ topic: Topic) -> CGFloat {
        let topicWidth = max(minTopicWidth, CGFloat(topic.name.count * 10))
        
        if topic.subtopics.isEmpty {
            return topicWidth
        }
        
        // Calculate maximum width needed for subtopics
        let subtopicsWidth = topic.subtopics.reduce(0) { maxWidth, subtopic in
            max(maxWidth, calculateSubtreeWidth(subtopic))
        }
        
        // Return the maximum of topic width and subtopics width plus offset
        return max(topicWidth, subtopicsWidth) + subtopicOffset
    }
    
    private func calculateSubtreeHeight(_ topic: Topic) -> CGFloat {
        let topicHeight = self.topicHeight
        
        if topic.subtopics.isEmpty {
            return topicHeight
        }
        
        // Calculate total height needed for subtopics including spacing
        var totalHeight: CGFloat = 0
        for (index, subtopic) in topic.subtopics.enumerated() {
            let subtreeHeight = calculateSubtreeHeight(subtopic)
            totalHeight += subtreeHeight
            
            // Add spacing after each subtopic except the last one
            if index < topic.subtopics.count - 1 {
                totalHeight += subtopicSpacing
            }
        }
        
        return max(topicHeight, totalHeight)
    }
    
    private func positionSubtree(in topic: inout Topic, parentX: CGFloat, startY: CGFloat) {
        let numSubtopics = topic.subtopics.count
        if numSubtopics == 0 { return }
        
        // Constants for spacing
        let horizontalSpacing: CGFloat = 200 // Space between parent and child
        let verticalSpacing: CGFloat = 60 // Space between siblings
        
        // Calculate the total height needed for all subtopics
        let totalHeight = verticalSpacing * CGFloat(numSubtopics - 1)
        
        // Calculate the starting Y position (top-most subtopic)
        let topY = topic.position.y + totalHeight/2
        
        // Position each subtopic
        for i in 0..<numSubtopics {
            var subtopic = topic.subtopics[i]
            
            // Calculate position
            let x = topic.position.x + horizontalSpacing
            let y = topY - (CGFloat(i) * verticalSpacing)
            subtopic.position = CGPoint(x: x, y: y)
            
            // Recursively position this subtopic's subtree
            if !subtopic.subtopics.isEmpty {
                positionSubtree(in: &subtopic, parentX: x, startY: y)
            }
            
            topic.subtopics[i] = subtopic
        }
    }
    
    // MARK: - Drag Handling
    
    func updateDraggedTopicPosition(_ topicId: UUID, _ newPosition: CGPoint) {
        isDragging = true
        
        // First find and update the topic's position
        if let index = topics.firstIndex(where: { $0.id == topicId }) {
            // Update main topic
            var topic = topics[index]
            let offset = CGPoint(
                x: newPosition.x - topic.position.x,
                y: newPosition.y - topic.position.y
            )
            updatePositionsInTopic(topic: &topic, offset: offset)
            topics[index] = topic
            
            // Update all relations immediately during drag
            updateAllRelations()
            
            // Update preview line if this topic is part of the current relation drag
            if let dragState = relationDragState {
                if dragState.fromId == topicId {
                    relationDragState = (fromId: dragState.fromId, toPosition: newPosition)
                }
            }
        } else {
            // Update subtopic
            for i in 0..<topics.count {
                var mainTopic = topics[i]
                if updateSubtopicPositionRecursively(topicId: topicId, newPosition: newPosition, in: &mainTopic) {
                    topics[i] = mainTopic
                    
                    // Update all relations immediately during drag
                    updateAllRelations()
                    
                    // Update preview line if this topic is part of the current relation drag
                    if let dragState = relationDragState {
                        if dragState.fromId == topicId {
                            relationDragState = (fromId: dragState.fromId, toPosition: newPosition)
                        }
                    }
                    break
                }
            }
        }
    }
    
    private func updatePositionsInTopic(topic: inout Topic, offset: CGPoint) {
        // Update the topic's position
        topic.position = CGPoint(
            x: topic.position.x + offset.x,
            y: topic.position.y + offset.y
        )
        
        // Update all subtopics recursively
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            updatePositionsInTopic(topic: &subtopic, offset: offset)
            topic.subtopics[i] = subtopic
        }
    }
    
    private func updateSubtopicPositionRecursively(topicId: UUID, newPosition: CGPoint, in topic: inout Topic) -> Bool {
        // Check direct subtopics
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == topicId {
                let offset = CGPoint(
                    x: newPosition.x - topic.subtopics[i].position.x,
                    y: newPosition.y - topic.subtopics[i].position.y
                )
                updatePositionsInTopic(topic: &topic.subtopics[i], offset: offset)
                return true
            }
            
            // Check nested subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicPositionRecursively(topicId: topicId, newPosition: newPosition, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        return false
    }
    
    private func updateAllRelations() {
        // First get all topics with their current positions
        var allTopics: [Topic] = []
        
        // Add main topics
        allTopics.append(contentsOf: topics)
        
        // Add all subtopics
        for topic in topics {
            allTopics.append(contentsOf: getAllSubtopics(from: topic))
        }
        
        // Update relations in main topics
        for i in 0..<topics.count {
            var topic = topics[i]
            updateRelationsInTopic(topic: &topic, allTopics: allTopics)
            topics[i] = topic
        }
        
        // Update relations in all subtopics
        for i in 0..<topics.count {
            var topic = topics[i]
            updateRelationsInSubtopics(topic: &topic, allTopics: allTopics)
            topics[i] = topic
        }
    }
    
    private func getAllSubtopics(from topic: Topic) -> [Topic] {
        var subtopics: [Topic] = []
        for subtopic in topic.subtopics {
            subtopics.append(subtopic)
            subtopics.append(contentsOf: getAllSubtopics(from: subtopic))
        }
        return subtopics
    }
    
    private func updateRelationsInTopic(topic: inout Topic, allTopics: [Topic]) {
        // Update relations in the topic
        for i in 0..<topic.relations.count {
            let relationId = topic.relations[i].id
            if let updatedTopic = allTopics.first(where: { $0.id == relationId }) {
                topic.relations[i] = updatedTopic
            }
        }
    }
    
    private func updateRelationsInSubtopics(topic: inout Topic, allTopics: [Topic]) {
        // Update relations in each subtopic
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            updateRelationsInTopic(topic: &subtopic, allTopics: allTopics)
            updateRelationsInSubtopics(topic: &subtopic, allTopics: allTopics)
            topic.subtopics[i] = subtopic
        }
    }
    
    func handleDragEnd(_ topicId: UUID) {
        isDragging = false
        // Optionally add any cleanup or final positioning logic here
    }
    
    // MARK: - Topic Finding
    
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
    
    func getSelectedTopic() -> Topic? {
        guard let selectedId = selectedTopicId else { return nil }
        
        // Check main topics
        if let topic = topics.first(where: { $0.id == selectedId }) {
            return topic
        }
        
        // Check subtopics
        for topic in topics {
            if let found = findTopicInSubtopics(id: selectedId, in: topic) {
                return found
            }
        }
        
        return nil
    }
    
    func getTopicById(_ id: UUID) -> Topic? {
        // Check main topics
        if let topic = topics.first(where: { $0.id == id }) {
            return topic
        }
        
        // Check subtopics
        for topic in topics {
            if let found = findTopicInSubtopics(id: id, in: topic) {
                return found
            }
        }
        
        return nil
    }
    
    // MARK: - Keyboard Events
    
    func handleKeyPress(_ event: NSEvent, at position: CGPoint) {
        // Check if any topic is being edited
        let isAnyTopicEditing = topics.contains { topic in
            isTopicOrSubtopicsEditing(topic)
        }
        
        // If a topic is being edited, don't handle any keyboard events
        if isAnyTopicEditing {
            return
        }
        
        switch event.keyCode {
        case 36: // Return key
            addMainTopic(at: position)
            
        case 48: // Tab key
            if let selectedTopic = getSelectedTopic() {
                print("Selected topic for subtopic creation: \(selectedTopic.id)")
                addSubtopic(to: selectedTopic)
                NSApp.keyWindow?.makeFirstResponder(nil) // Remove focus from any UI element
            }
            
        case 49: // Space bar
            if let selectedId = selectedTopicId {
                setTopicEditing(selectedId, isEditing: true)
            }
            
        case 51: // Delete/Backspace key
            if let selectedId = selectedTopicId {
                deleteTopic(id: selectedId)
                selectedTopicId = nil
            }
            
        default:
            break
        }
    }
    
    private func isTopicOrSubtopicsEditing(_ topic: Topic) -> Bool {
        if topic.isEditing {
            return true
        }
        return topic.subtopics.contains { isTopicOrSubtopicsEditing($0) }
    }
    
    // Handle relationship drag
    func handleRelationDragChanged(_ fromId: UUID, toPosition: CGPoint) {
        // If the source topic is being dragged, use its current position
        if let fromTopic = findTopic(id: fromId) {
            relationDragState = (fromId: fromId, toPosition: toPosition)
        }
    }
    
    func handleRelationDragEnded(_ fromId: UUID) {
        defer { relationDragState = nil }
        
        guard let toPosition = relationDragState?.toPosition,
              let targetTopic = findTopicAt(position: toPosition) else { return }
        
        // Don't create relation to self or if already exists
        guard fromId != targetTopic.id else { return }
        
        // Add relation to both topics
        if var fromTopic = findTopic(id: fromId) {
            // Check if relation already exists
            if !fromTopic.relations.contains(where: { $0.id == targetTopic.id }) {
                fromTopic.addRelation(targetTopic)
                updateTopic(fromTopic)
                
                var updatedTargetTopic = targetTopic
                updatedTargetTopic.addRelation(fromTopic)
                updateTopic(updatedTargetTopic)
                
                // Update all relations to ensure proper positioning
                updateAllRelations()
            }
        }
    }
    
    private func updateTopic(_ updatedTopic: Topic) {
        // Update in main topics
        if let index = topics.firstIndex(where: { $0.id == updatedTopic.id }) {
            topics[index] = updatedTopic
            return
        }
        
        // Update in subtopics
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateTopicInHierarchy(updatedTopic, in: &topic) {
                topics[i] = topic
            }
        }
    }
    
    private func updateTopicInHierarchy(_ updatedTopic: Topic, in topic: inout Topic) -> Bool {
        // Check direct subtopics
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == updatedTopic.id {
                topic.subtopics[i] = updatedTopic
                return true
            }
            
            // Check nested subtopics
            var subtopic = topic.subtopics[i]
            if updateTopicInHierarchy(updatedTopic, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        return false
    }
    
    func findTopic(id: UUID) -> Topic? {
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
    
    private func findTopicAt(position: CGPoint) -> Topic? {
        // Check main topics
        for topic in topics {
            if getTopicBox(topic: topic).contains(position) {
                return topic
            }
            
            if let found = findTopicAtPositionInHierarchy(position: position, in: topic) {
                return found
            }
        }
        return nil
    }
    
    private func findTopicAtPositionInHierarchy(position: CGPoint, in topic: Topic) -> Topic? {
        for subtopic in topic.subtopics {
            if getTopicBox(topic: subtopic).contains(position) {
                return subtopic
            }
            
            if let found = findTopicAtPositionInHierarchy(position: position, in: subtopic) {
                return found
            }
        }
        return nil
    }
    
    private func getTopicBox(topic: Topic) -> CGRect {
        let width = max(120, CGFloat(topic.name.count * 10)) + 32 // Add padding for shape
        let height: CGFloat = 40 // Total height including vertical padding
        return CGRect(
            x: topic.position.x - width/2,
            y: topic.position.y - height/2,
            width: width,
            height: height
        )
    }
    
    // MARK: - Topic Deletion
    
    private func deleteTopic(id: UUID) {
        // First try to delete from main topics
        if let index = topics.firstIndex(where: { $0.id == id }) {
            // Remove relations to this topic from all other topics
            removeRelationsToTopic(id)
            // Remove the topic and all its subtopics
            topics.remove(at: index)
            return
        }
        
        // If not found in main topics, try to delete from subtopics
        for i in 0..<topics.count {
            var topic = topics[i]
            if deleteSubtopic(id: id, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func deleteSubtopic(id: UUID, in topic: inout Topic) -> Bool {
        // Check direct subtopics
        if let index = topic.subtopics.firstIndex(where: { $0.id == id }) {
            // Remove relations to this subtopic and its children from all topics
            removeRelationsToTopic(id)
            removeRelationsToSubtopics(topic.subtopics[index])
            // Remove the subtopic
            topic.subtopics.remove(at: index)
            return true
        }
        
        // Check nested subtopics
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            if deleteSubtopic(id: id, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    private func removeRelationsToTopic(_ id: UUID) {
        // Remove relations from main topics
        for i in 0..<topics.count {
            var topic = topics[i]
            topic.relations.removeAll { $0.id == id }
            topics[i] = topic
        }
        
        // Remove relations from subtopics
        for i in 0..<topics.count {
            var topic = topics[i]
            removeRelationsToTopicInSubtopics(id, in: &topic)
            topics[i] = topic
        }
    }
    
    private func removeRelationsToTopicInSubtopics(_ id: UUID, in topic: inout Topic) {
        // Remove relations in current topic's subtopics
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            subtopic.relations.removeAll { $0.id == id }
            removeRelationsToTopicInSubtopics(id, in: &subtopic)
            topic.subtopics[i] = subtopic
        }
    }
    
    private func removeRelationsToSubtopics(_ topic: Topic) {
        // Remove relations to all subtopics recursively
        for subtopic in topic.subtopics {
            removeRelationsToTopic(subtopic.id)
            removeRelationsToSubtopics(subtopic)
        }
    }
    
    func updateTopicShape(_ id: UUID, shape: Topic.Shape) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].shape = shape
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicShape(id, shape, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicShape(_ id: UUID, _ shape: Topic.Shape, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].shape = shape
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicShape(id, shape, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func findTopicIndex(_ id: UUID) -> Int? {
        // First check main topics
        if let index = topics.firstIndex(where: { $0.id == id }) {
            return index
        }
        
        // Then check subtopics
        for (index, topic) in topics.enumerated() {
            if findTopicInSubtopics(id: id, in: topic) != nil {
                return index
            }
        }
        
        return nil
    }
    
    private func findTopicInSubtopics(id: UUID, in topic: Topic) -> Topic? {
        if topic.id == id {
            return topic
        }
        
        for subtopic in topic.subtopics {
            if let found = findTopicInSubtopics(id: id, in: subtopic) {
                return found
            }
        }
        
        return nil
    }
    
    func updateTopicBackgroundColor(_ id: UUID, color: Color) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].backgroundColor = color
            // Update all subtopics recursively
            updateSubtopicsBackgroundColor(&topics[index], color)
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicBackgroundColor(id, color, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicBackgroundColor(_ id: UUID, _ color: Color, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].backgroundColor = color
                // Update all subtopics recursively
                updateSubtopicsBackgroundColor(&topic.subtopics[i], color)
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicBackgroundColor(id, color, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    // Helper function to recursively update all subtopics' background color
    private func updateSubtopicsBackgroundColor(_ topic: inout Topic, _ color: Color) {
        for i in 0..<topic.subtopics.count {
            topic.subtopics[i].backgroundColor = color
            var subtopic = topic.subtopics[i]
            updateSubtopicsBackgroundColor(&subtopic, color)
            topic.subtopics[i] = subtopic
        }
    }
    
    func updateTopicBorderColor(_ id: UUID, color: Color) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].borderColor = color
            // Update all subtopics recursively
            updateSubtopicsBorderColor(&topics[index], color)
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicBorderColor(id, color, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicBorderColor(_ id: UUID, _ color: Color, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].borderColor = color
                // Update all subtopics recursively
                updateSubtopicsBorderColor(&topic.subtopics[i], color)
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicBorderColor(id, color, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    // Helper function to recursively update all subtopics' border color
    private func updateSubtopicsBorderColor(_ topic: inout Topic, _ color: Color) {
        for i in 0..<topic.subtopics.count {
            topic.subtopics[i].borderColor = color
            var subtopic = topic.subtopics[i]
            updateSubtopicsBorderColor(&subtopic, color)
            topic.subtopics[i] = subtopic
        }
    }
    
    func updateTopicBackgroundOpacity(_ id: UUID, opacity: Double) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].backgroundOpacity = opacity
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicBackgroundOpacity(id, opacity, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicBackgroundOpacity(_ id: UUID, _ opacity: Double, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].backgroundOpacity = opacity
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicBackgroundOpacity(id, opacity, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func updateTopicBorderOpacity(_ id: UUID, opacity: Double) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].borderOpacity = opacity
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicBorderOpacity(id, opacity, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicBorderOpacity(_ id: UUID, _ opacity: Double, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].borderOpacity = opacity
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicBorderOpacity(id, opacity, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func updateTopicBorderWidth(_ id: UUID, width: Topic.BorderWidth) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].borderWidth = width
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicBorderWidth(id, width, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicBorderWidth(_ id: UUID, _ width: Topic.BorderWidth, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].borderWidth = width
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicBorderWidth(id, width, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Text Formatting
    
    func updateTopicFont(_ id: UUID, font: String) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].font = font
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicFont(id, font, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicFont(_ id: UUID, _ font: String, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].font = font
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicFont(id, font, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func updateTopicFontSize(_ id: UUID, size: CGFloat) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].fontSize = size
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicFontSize(id, size, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicFontSize(_ id: UUID, _ size: CGFloat, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].fontSize = size
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicFontSize(id, size, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func updateTopicFontWeight(_ id: UUID, weight: Font.Weight) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].fontWeight = weight
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicFontWeight(id, weight, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicFontWeight(_ id: UUID, _ weight: Font.Weight, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].fontWeight = weight
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicFontWeight(id, weight, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func updateTopicForegroundColor(_ id: UUID, color: Color) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].foregroundColor = color
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicForegroundColor(id, color, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicForegroundColor(_ id: UUID, _ color: Color, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].foregroundColor = color
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicForegroundColor(id, color, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func updateTopicForegroundOpacity(_ id: UUID, opacity: Double) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].foregroundOpacity = opacity
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicForegroundOpacity(id, opacity, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicForegroundOpacity(_ id: UUID, _ opacity: Double, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].foregroundOpacity = opacity
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicForegroundOpacity(id, opacity, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func updateTopicTextStyle(_ id: UUID, style: TextStyle, isEnabled: Bool) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            if isEnabled {
                topics[index].textStyles.insert(style)
            } else {
                topics[index].textStyles.remove(style)
            }
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicTextStyle(id, style, isEnabled, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicTextStyle(_ id: UUID, _ style: TextStyle, _ isEnabled: Bool, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                if isEnabled {
                    topic.subtopics[i].textStyles.insert(style)
                } else {
                    topic.subtopics[i].textStyles.remove(style)
                }
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicTextStyle(id, style, isEnabled, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func updateTopicTextCase(_ id: UUID, textCase: TextCase) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].textCase = textCase
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicTextCase(id, textCase, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    func updateTopicBranchStyle(_ id: UUID, style: Topic.BranchStyle) {
        // Update all topics to use the new style
        for i in 0..<topics.count {
            var topic = topics[i]
            updateBranchStyleRecursively(&topic, style)
            topics[i] = topic
        }
    }
    
    private func updateBranchStyleRecursively(_ topic: inout Topic, _ style: Topic.BranchStyle) {
        // Update the current topic
        topic.branchStyle = style
        
        // Update all subtopics recursively
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            updateBranchStyleRecursively(&subtopic, style)
            topic.subtopics[i] = subtopic
        }
    }
    
    private func updateSubtopicTextCase(_ id: UUID, _ textCase: TextCase, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].textCase = textCase
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicTextCase(id, textCase, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func updateTopicTextAlignment(_ id: UUID, alignment: TextAlignment) {
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].textAlignment = alignment
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if updateSubtopicTextAlignment(id, alignment, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func updateSubtopicTextAlignment(_ id: UUID, _ alignment: TextAlignment, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].textAlignment = alignment
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicTextAlignment(id, alignment, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Undo/Redo Functionality
    
    /// Save current state for undo history
    private func saveState() {
        // If we're not at the end of history, truncate it
        if currentHistoryIndex < history.count - 1 {
            history = Array(history[0...currentHistoryIndex])
        }
        
        // Create a deep copy of the topics array
        let topicsCopy = topics.map { $0.deepCopy() }
        
        // Add to history
        history.append(topicsCopy)
        currentHistoryIndex = history.count - 1
        
        // Limit history size
        if history.count > maxHistorySize {
            history.removeFirst()
            currentHistoryIndex = history.count - 1
        }
    }
    
    /// Perform undo operation
    func undo() {
        guard currentHistoryIndex > 0 else { return }
        
        currentHistoryIndex -= 1
        topics = history[currentHistoryIndex].map { $0.deepCopy() }
    }
    
    /// Perform redo operation
    func redo() {
        guard currentHistoryIndex < history.count - 1 else { return }
        
        currentHistoryIndex += 1
        topics = history[currentHistoryIndex].map { $0.deepCopy() }
    }
} 
