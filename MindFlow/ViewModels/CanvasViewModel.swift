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
    
    // Add these properties to store the current theme
    private var currentThemeFillColor: Color?
    private var currentThemeBorderColor: Color?
    private var currentThemeTextColor: Color?
    
    init() {
        // Initialize history with current empty state
        history.append([])
        currentHistoryIndex = 0
        
        // Register for save notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleSaveRequest), name: NSNotification.Name("RequestTopicsForSave"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSaveAsRequest), name: NSNotification.Name("RequestTopicsForSaveAs"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleClearCanvas), name: NSNotification.Name("ClearCanvas"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLoadRequest), name: NSNotification.Name("LoadMindMap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDirectLoadTopics), name: NSNotification.Name("LoadTopics"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Save/Load Functionality
    
    @objc private func handleSaveRequest() {
        MindFlowFileManager.shared.saveCurrentFile(topics: getAllTopics()) { success, errorMessage in
            DispatchQueue.main.async {
                if let error = errorMessage {
                    // Handle error - in a real app, you might want to show an alert
                    print("Failed to save: \(error)")
                }
            }
        }
    }
    
    @objc private func handleSaveAsRequest() {
        MindFlowFileManager.shared.saveFileAs(topics: getAllTopics()) { success, errorMessage in
            DispatchQueue.main.async {
                if let error = errorMessage {
                    // Handle error - in a real app, you might want to show an alert
                    print("Failed to save: \(error)")
                }
            }
        }
    }
    
    @objc private func handleLoadRequest() {
        // First prompt to save if there are unsaved changes
        if !topics.isEmpty {
            // In a real app, you would show a dialog asking to save first
            // For now, we'll just proceed with loading
        }
        
        MindFlowFileManager.shared.loadFile { loadedTopics, errorMessage in
            DispatchQueue.main.async {
                if let topics = loadedTopics {
                    self.loadTopics(topics)
                } else if let error = errorMessage {
                    // Handle error - in a real app, you might want to show an alert
                    print("Failed to load: \(error)")
                }
            }
        }
    }
    
    /// Loads a set of topics into the canvas
    private func loadTopics(_ loadedTopics: [Topic]) {
        saveState() // Save current state for undo
        
        // Replace all topics with the loaded ones
        topics = loadedTopics.map { topic in
            var newTopic = topic
            // Make sure transient properties are properly set
            newTopic.isSelected = false
            newTopic.isEditing = false
            return newTopic
        }
        
        // Reset current selection
        selectedTopicId = nil
        
        // Recalculate main topic count
        mainTopicCount = topics.count
        
        // Ensure branch styles are consistent throughout the loaded mind map
        if let firstTopic = topics.first {
            // Get the branch style from the first topic
            let globalStyle = firstTopic.branchStyle
            
            // Apply it to all topics to ensure consistency
            for i in 0..<topics.count {
                var mainTopic = topics[i]
                updateBranchStyleRecursively(&mainTopic, globalStyle)
                topics[i] = mainTopic
            }
        }
        
        // No need to rebuild relations as they should be preserved in the file
    }
    
    @objc private func handleClearCanvas() {
        saveState() // Save current state for undo
        
        // Clear the canvas - reset all state
        topics = []
        selectedTopicId = nil
        relationDragState = nil
        mainTopicCount = 0
    }
    
    /// Gets all topics from the canvas for saving
    private func getAllTopics() -> [Topic] {
        // Return a copy of the topics array
        return topics.map { $0.deepCopy() }
    }
    
    // MARK: - Topic Management
    
    func addMainTopic(at position: CGPoint) {
        saveState()
        mainTopicCount += 1
        
        // Create new topic at the exact cursor position
        var topic = Topic.createMainTopic(at: position, count: mainTopicCount)
        
        // Apply theme colors if a theme has been selected
        if let fillColor = currentThemeFillColor, 
           let borderColor = currentThemeBorderColor,
           let textColor = currentThemeTextColor {
            topic.backgroundColor = fillColor
            topic.borderColor = borderColor
            topic.foregroundColor = textColor
        }
        
        // Apply the current branch style from existing topics (if any exist)
        if !topics.isEmpty {
            // Use the first topic's branch style as the current global style
            topic.branchStyle = topics[0].branchStyle
        }
        
        topics.append(topic)
        
        // Select the new topic so it becomes the center reference for auto-layout
        selectedTopicId = topic.id
        
        // Apply auto-layout while maintaining the new topic's position
        performAutoLayout()
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
        
        // Automatically adjust spacing after adding a subtopic
        performAutoLayout()
    }
    
    private func addSubtopicToParent(_ parentTopic: Topic, at parentIndex: Int) {
        print("Adding direct subtopic to main topic at index: \(parentIndex)")
        let subtopicCount = topics[parentIndex].subtopics.count
        
        // Position the new subtopic relative to its parent
        let subtopicPosition = calculateNewSubtopicPosition(for: parentTopic, subtopicCount: subtopicCount)
        
        var subtopic = parentTopic.createSubtopic(at: subtopicPosition, count: subtopicCount + 1)
        
        // Inherit the parent's branch style
        subtopic.branchStyle = parentTopic.branchStyle
        
        topics[parentIndex].subtopics.append(subtopic)
        
        // No need to position subtree here since we'll call performAutoLayout after
        
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
            
            var subtopic = topic.createSubtopic(at: subtopicPosition, count: subtopicCount + 1)
            
            // Inherit the parent's branch style
            subtopic.branchStyle = topic.branchStyle
            
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
        // Get the actual height of this topic from its content
        let topicBox = getTopicBox(topic: topic)
        let actualTopicHeight = topicBox.height
        
        if topic.subtopics.isEmpty {
            return actualTopicHeight
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
        
        return max(actualTopicHeight, totalHeight)
    }
    
    private func positionSubtree(in topic: inout Topic, parentX: CGFloat, startY: CGFloat) {
        let numSubtopics = topic.subtopics.count
        if numSubtopics == 0 { return }
        
        // Constants for spacing
        let horizontalSpacing: CGFloat = 200 // Space between parent and child
        let verticalSpacing: CGFloat = 60 // Space between siblings
        
        // Calculate the heights of each subtopic to determine proper spacing
        var subtopicHeights: [CGFloat] = []
        var totalHeightNeeded: CGFloat = 0
        
        for subtopic in topic.subtopics {
            let subtopicBox = getTopicBox(topic: subtopic)
            let height = subtopicBox.height
            subtopicHeights.append(height)
            totalHeightNeeded += height
        }
        
        // Add spacing between topics
        totalHeightNeeded += verticalSpacing * CGFloat(numSubtopics - 1)
        
        // Calculate the starting Y position (top-most subtopic)
        let topY = topic.position.y + totalHeightNeeded/2 - subtopicHeights[0]/2
        
        // Position each subtopic
        var currentY = topY
        for i in 0..<numSubtopics {
            var subtopic = topic.subtopics[i]
            
            // Calculate position
            let x = topic.position.x + horizontalSpacing
            subtopic.position = CGPoint(x: x, y: currentY)
            
            // Recursively position this subtopic's subtree
            if !subtopic.subtopics.isEmpty {
                positionSubtree(in: &subtopic, parentX: x, startY: currentY)
            }
            
            topic.subtopics[i] = subtopic
            
            // Move down for next subtopic, considering its height
            if i < numSubtopics - 1 {
                currentY -= (subtopicHeights[i]/2 + verticalSpacing + subtopicHeights[i+1]/2)
            }
        }
    }
    
    // Add auto layout method for perfect spacing
    func performAutoLayout() {
        saveState() // Save state before rearranging

        // Constants for ideal spacing
        let horizontalSpacing: CGFloat = 250 // Space between parent and child
        let verticalSpacing: CGFloat = 100 // Space between siblings
        let baseMainTopicSpacing: CGFloat = 350 // Base space between main topics
        
        // First position main topics horizontally with equal spacing
        let numMainTopics = topics.count
        if numMainTopics > 0 {
            // Get the selected topic as a reference point
            var centerTopic: Topic?
            var centerTopicIndex: Int = 0
            
            if let selectedId = selectedTopicId, let index = topics.firstIndex(where: { $0.id == selectedId }) {
                // If a main topic is selected, use it as center
                centerTopic = topics[index]
                centerTopicIndex = index
            } else {
                // Otherwise use the first topic
                centerTopic = topics.first
                centerTopicIndex = 0
            }
            
            // Ensure we have a center topic
            guard let centerTopic = centerTopic else { return }
            
            // Keep the center topic fixed at its current position
            let centerPosition = centerTopic.position
            
            // Position topics to the left of center topic
            var currentX = centerPosition.x
            for i in stride(from: centerTopicIndex - 1, through: 0, by: -1) {
                var topic = topics[i]
                
                // Calculate width needed for this topic and get its box
                let topicWidth = calculateTreeWidth(topic)
                let centerTopicBox = getTopicBox(topic: centerTopic)
                let topicBox = getTopicBox(topic: topic)
                
                // Calculate adaptive spacing based on the actual widths of the topics
                let adaptiveSpacing = baseMainTopicSpacing + (centerTopicBox.width + topicBox.width) * 0.3
                
                // Position to the left of the previous topic
                currentX -= (topicWidth/2 + adaptiveSpacing)
                
                topic.position = CGPoint(
                    x: currentX,
                    y: centerPosition.y
                )
                
                // Adjust currentX for the next topic
                currentX -= topicWidth/2
                
                // Position all subtopics in a tree layout
                if !topic.subtopics.isEmpty {
                    layoutSubtopicTreeImproved(in: &topic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
                }
                
                topics[i] = topic
            }
            
            // Reset and position topics to the right of center topic
            currentX = centerPosition.x
            let centerTopicWidth = calculateTreeWidth(centerTopic)
            let centerTopicBox = getTopicBox(topic: centerTopic)
            
            // Position center topic's subtopics without moving the center topic
            var updatedCenterTopic = topics[centerTopicIndex]
            if !updatedCenterTopic.subtopics.isEmpty {
                layoutSubtopicTreeImproved(in: &updatedCenterTopic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
            }
            topics[centerTopicIndex] = updatedCenterTopic
            
            // Position topics to the right of center topic
            for i in (centerTopicIndex + 1)..<numMainTopics {
                var topic = topics[i]
                let topicBox = getTopicBox(topic: topic)
                
                // Calculate adaptive spacing based on the actual widths of the topics
                let adaptiveSpacing = baseMainTopicSpacing + (centerTopicBox.width + topicBox.width) * 0.3
                
                currentX += centerTopicWidth/2 + adaptiveSpacing
                
                topic.position = CGPoint(
                    x: currentX + topicBox.width/2,
                    y: centerPosition.y
                )
                
                // Position all subtopics in a tree layout
                if !topic.subtopics.isEmpty {
                    layoutSubtopicTreeImproved(in: &topic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
                }
                
                // Update currentX for next topic
                currentX += calculateTreeWidth(topic)
                
                topics[i] = topic
            }
            
            // Ensure branch styles are preserved after layout
            if let firstTopic = topics.first {
                // Get the current global branch style from the first topic
                let globalStyle = firstTopic.branchStyle
                
                // Re-apply to all topics to ensure consistency
                for i in 0..<topics.count {
                    var mainTopic = topics[i]
                    updateBranchStyleRecursively(&mainTopic, globalStyle)
                    topics[i] = mainTopic
                }
            }
        }
        
        // Organize relation lines after repositioning
        updateAllRelations()
    }

    // Improved layout function that ensures subtopics maintain order
    private func layoutSubtopicTreeImproved(in topic: inout Topic, horizontalSpacing: CGFloat, verticalSpacing: CGFloat) -> CGFloat {
        let numSubtopics = topic.subtopics.count
        if numSubtopics == 0 { return 0 }
        
        // First level subtopics always go to the right of parent
        let parentX = topic.position.x
        let parentY = topic.position.y
        
        // Get parent topic box
        let parentBox = getTopicBox(topic: topic)
        
        // Calculate how much vertical space we need for each subtopic's tree
        var subtreeHeights: [CGFloat] = []
        var totalHeight: CGFloat = 0
        
        // First calculate all subtree heights
        for i in 0..<numSubtopics {
            let subtopic = topic.subtopics[i]
            let subtopicSubtreeCount = countAllSubtopics(subtopic)
            
            // Get the actual height of the subtopic
            let subtopicBox = getTopicBox(topic: subtopic)
            let actualHeight = subtopicBox.height
            
            // Adapt vertical spacing based on the size of the subtree
            // More topics need more space to avoid crowding
            let adaptiveSpacing = verticalSpacing * (1.0 + log(Double(max(1, subtopicSubtreeCount))) * 0.2)
            
            // Consider the actual height of the topic when calculating spacing
            let height = max(adaptiveSpacing, CGFloat(adaptiveSpacing) * CGFloat(subtopicSubtreeCount))
            let heightWithTopicSize = max(height, actualHeight * 2) // Ensure enough space for the topic
            
            subtreeHeights.append(heightWithTopicSize)
            totalHeight += heightWithTopicSize
        }
        
        // Calculate the starting Y position (top-most subtopic)
        let topY = parentY - totalHeight/2
        
        // Position each subtopic vertically, accounting for their subtree size
        var currentY = topY
        
        for i in 0..<numSubtopics {
            var subtopic = topic.subtopics[i]
            
            // Get the subtopic box for width calculation
            let subtopicBox = getTopicBox(topic: subtopic)
            
            // Calculate adaptive horizontal spacing based on the widths of parent and subtopic
            let adaptiveHorizontalSpacing = horizontalSpacing + (parentBox.width + subtopicBox.width) * 0.25
            
            // Position this subtopic - always to the right of parent at consistent horizontal distance
            subtopic.position = CGPoint(
                x: parentX + parentBox.width/2 + adaptiveHorizontalSpacing,
                y: currentY + subtreeHeights[i]/2
            )
            
            // Recursively position this subtopic's subtree
            if !subtopic.subtopics.isEmpty {
                let usedHeight = layoutSubtopicTreeImproved(in: &subtopic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
                // We'll use the actual height used if it's greater than our initial estimate
                currentY += max(subtreeHeights[i], usedHeight)
            } else {
                currentY += subtreeHeights[i]
            }
            
            topic.subtopics[i] = subtopic
        }
        
        return totalHeight
    }

    // Helper function to count all subtopics in a tree, including nested ones
    private func countAllSubtopics(_ topic: Topic) -> Int {
        if topic.subtopics.isEmpty {
            return 1 // Count this topic
        }
        
        // Use a more efficient approach for larger subtree counts
        let directSubtopicCount = topic.subtopics.count
        
        // For small subtrees, use a simple recursive approach
        if directSubtopicCount < 10 {
            var count = 1 // Count this topic
            for subtopic in topic.subtopics {
                count += countAllSubtopics(subtopic)
            }
            return count
        } else {
            // For larger trees, use a more efficient calculation
            // This approximation works well for most balanced trees
            let nestedCount = topic.subtopics.reduce(0) { count, subtopic in
                return count + (1 + subtopic.subtopics.count * 2)
            }
            return 1 + directSubtopicCount + nestedCount
        }
    }

    // Calculate the width of a topic's subtree for spacing purposes
    private func calculateTreeWidth(_ topic: Topic) -> CGFloat {
        // Get the actual width of this topic based on its content instead of using a fixed value
        let topicBox = getTopicBox(topic: topic)
        let actualWidth = topicBox.width
        
        if topic.subtopics.isEmpty {
            return actualWidth
        }
        
        // Find the deepest nested level
        var maxDepth: Int = 0
        
        func calculateDepth(_ topic: Topic, currentDepth: Int) {
            maxDepth = max(maxDepth, currentDepth)
            for subtopic in topic.subtopics {
                calculateDepth(subtopic, currentDepth: currentDepth + 1)
            }
        }
        
        calculateDepth(topic, currentDepth: 1)
        
        // Each level adds horizontal spacing
        return actualWidth + CGFloat(maxDepth) * 250
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
        saveState() // Save state after dragging ends
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
                saveState() // Save state after adding relation
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
        // Calculate width based on the longest line
        let lines = topic.name.components(separatedBy: "\n")
        let maxLineLength = lines.map { $0.count }.max() ?? 0
        let width = max(120, CGFloat(maxLineLength * 10)) + 32 // Add padding for shape
        
        // Calculate height based on number of lines
        let lineCount = lines.count
        // Use a base height for single-line topics, and increase height for multi-line
        let height = max(40, CGFloat(lineCount * 24)) + 16 // Add vertical padding
        
        return CGRect(
            x: topic.position.x - width/2,
            y: topic.position.y - height/2,
            width: width,
            height: height
        )
    }
    
    // MARK: - Topic Deletion
    
    private func deleteTopic(id: UUID) {
        saveState() // Save state before deletion
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
    
    func updateTopicBranchStyle(_ id: UUID?, style: Topic.BranchStyle) {
        // Save state before making changes
        saveState()
        
        // When updating branch style, apply it to all topics on the canvas
        // Apply the style to all topics in the canvas
        for i in 0..<topics.count {
            var mainTopic = topics[i]
            updateBranchStyleRecursively(&mainTopic, style)
            topics[i] = mainTopic
        }
        
        // Store this style as the current global style
        // This ensures that any new topics or subtopics created will use this style
        if let firstTopic = topics.first {
            // Store the current global style on the first topic (if any exists)
            // New topics will check this to inherit the correct style
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
    
    private func updateSubtopicBranchStyle(_ id: UUID, _ style: Topic.BranchStyle, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                // Update this subtopic and all its descendants
                var subtopic = topic.subtopics[i]
                updateBranchStyleRecursively(&subtopic, style)
                topic.subtopics[i] = subtopic
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if updateSubtopicBranchStyle(id, style, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
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
    
    // MARK: - Relation Management
    
    /// Restores bidirectional relations after loading a state
    private func restoreBidirectionalRelations() {
        // Get all topics including subtopics
        var allTopics = topics
        for topic in topics {
            allTopics.append(contentsOf: getAllSubtopics(from: topic))
        }
        
        // For each topic, ensure its relations are bidirectional
        for topic in allTopics {
            for relatedTopic in topic.relations {
                // If this topic is the source (id < related.id), ensure the target has a relation back
                if topic.id < relatedTopic.id {
                    if var targetTopic = findTopic(id: relatedTopic.id) {
                        if !targetTopic.relations.contains(where: { $0.id == topic.id }) {
                            targetTopic.addRelation(topic)
                            updateTopic(targetTopic)
                        }
                    }
                }
            }
        }
    }
    
    func removeRelation(from: UUID, to: UUID) {
        saveState() // Save state before removing relation
        
        // Find and update both topics
        if var fromTopic = findTopic(id: from) {
            fromTopic.removeRelation(to)
            updateTopic(fromTopic)
        }
        
        if var toTopic = findTopic(id: to) {
            toTopic.removeRelation(from)
            updateTopic(toTopic)
        }
    }
    
    // MARK: - Topic Collapse Functionality
    
    func toggleCollapseState(topicId: UUID) {
        saveState() // Save state before toggling collapse
        
        // Update main topic
        if let index = topics.firstIndex(where: { $0.id == topicId }) {
            topics[index].isCollapsed.toggle()
            return
        }
        
        // Update subtopic
        for i in 0..<topics.count {
            var topic = topics[i]
            if toggleSubtopicCollapseState(topicId, in: &topic) {
                topics[i] = topic
                break
            }
        }
    }
    
    private func toggleSubtopicCollapseState(_ id: UUID, in topic: inout Topic) -> Bool {
        // Check if this topic's subtopics contain the target
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == id {
                topic.subtopics[i].isCollapsed.toggle()
                return true
            }
            
            // Recursively check this subtopic's subtopics
            var subtopic = topic.subtopics[i]
            if toggleSubtopicCollapseState(id, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    func isTopicCollapsed(id: UUID) -> Bool {
        // Check main topics
        if let topic = topics.first(where: { $0.id == id }) {
            return topic.isCollapsed
        }
        
        // Check subtopics
        for topic in topics {
            if let collapsed = isSubtopicCollapsed(id, in: topic) {
                return collapsed
            }
        }
        
        return false
    }
    
    private func isSubtopicCollapsed(_ id: UUID, in topic: Topic) -> Bool? {
        if topic.id == id {
            return topic.isCollapsed
        }
        
        for subtopic in topic.subtopics {
            if let collapsed = isSubtopicCollapsed(id, in: subtopic) {
                return collapsed
            }
        }
        
        return nil
    }
    
    // Count all descendants (including all nested subtopics) for a topic
    func countAllDescendants(for topic: Topic) -> Int {
        var count = 0
        
        // Add direct subtopics
        count += topic.subtopics.count
        
        // Add all nested subtopics recursively
        for subtopic in topic.subtopics {
            count += countAllDescendants(for: subtopic)
        }
        
        return count
    }
    
    @objc private func handleDirectLoadTopics(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let topics = userInfo["topics"] as? [Topic] {
            loadTopics(topics)
        }
    }
    
    // MARK: - Drag Handling
    
    func updateDraggedTopicPosition(_ topicId: UUID, _ newPosition: CGPoint) {
        isDragging = true
        
        // First find and update the topic's position
        if let index = topics.firstIndex(where: { $0.id == topicId }) {
            // Update main topic
            var topic = topics[index]
            // Calculate the offset between old and new position
            let offset = CGPoint(
                x: newPosition.x - topic.position.x,
                y: newPosition.y - topic.position.y
            )
            
            // Update the main topic and all its subtopics with the same offset
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
            // If not a main topic, check subtopics
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
        
        // Update all subtopics recursively with the same offset
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
                // Calculate the offset between old and new position
                let offset = CGPoint(
                    x: newPosition.x - topic.subtopics[i].position.x,
                    y: newPosition.y - topic.subtopics[i].position.y
                )
                
                // Update this subtopic and all its children with the same offset
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
    
    // Get all topic IDs from the mind map
    func getAllTopicIds() -> [UUID] {
        var topicIds = [UUID]()
        
        func collectIds(from topics: [Topic]) {
            for topic in topics {
                topicIds.append(topic.id)
                collectIds(from: topic.subtopics)
            }
        }
        
        collectIds(from: topics)
        return topicIds
    }
    
    // Add this method to set the current theme
    func setCurrentTheme(topicFillColor: Color, topicBorderColor: Color, topicTextColor: Color) {
        // Update local theme colors
        currentThemeFillColor = topicFillColor
        currentThemeBorderColor = topicBorderColor
        currentThemeTextColor = topicTextColor
        
        // Update Topic static theme colors property for subtopics
        Topic.themeColors = (
            backgroundColor: topicFillColor, 
            borderColor: topicBorderColor, 
            foregroundColor: topicTextColor
        )
    }
}
