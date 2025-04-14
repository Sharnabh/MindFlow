import SwiftUI
import AppKit

class CanvasViewModel: ObservableObject {
    @Published var topics: [Topic] = []
    @Published var selectedTopicId: UUID?
    @Published var relationDragState: (fromId: UUID, toPosition: CGPoint)?
    @Published var isTextInputActive: Bool = false
    
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
    
    // MARK: - Notes Management
    
    // Property to track currently editing note
    @Published var isEditingNote: Bool = false
    @Published var currentNoteContent: String = ""
    @Published var showingNoteEditorForTopicId: UUID? = nil
    
    // This flag prevents keyboard shortcuts from affecting topics when editing notes
    var shouldBlockKeyboardShortcuts: Bool {
        return isEditingNote
    }
    
    // Time of the last state save for notes
    private var lastNoteSaveTime = Date()
    private let noteSaveStateInterval: TimeInterval = 3.0 // Save state every 3 seconds for notes
    
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
        
        // Select the new topic
        selectedTopicId = topic.id
        
        // Don't call performAutoLayout() to maintain exact cursor position
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
            if let mainTopic = findAndUpdateTopicHierarchy(parentId: parentTopic.id, in: topics[topicIndex]) {
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
        
        // If there's an overlap, adjust the position down by a bit more than the topic height
        if topicBox.intersects(newTopicBox) {
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
        
        // Ensure text input is not active when selecting a topic
        isTextInputActive = false
    }
    
    func setTopicEditing(_ id: UUID?, isEditing: Bool) {
        // Create a copy of the topics array
        var updatedTopics = topics
        
        // Clear previous editing state on the copy
        for i in 0..<updatedTopics.count {
            clearEditingStateRecursively(in: &updatedTopics[i])
        }
        
        // Set new editing state if we have an ID
        if let id = id {
            // Check if it's a main topic
            if let index = updatedTopics.firstIndex(where: { $0.id == id }) {
                updatedTopics[index].isEditing = isEditing
            } else {
                // Check subtopics
                for i in 0..<updatedTopics.count {
                    if setSubtopicEditing(id, isEditing, in: &updatedTopics[i]) {
                        break
                    }
                }
            }
        }
        
        // Update the published property once with all changes
        self.topics = updatedTopics
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
        
        // Create a copy of topics to work with
        var updatedTopics = topics
        
        // First position main topics horizontally with equal spacing
        let numMainTopics = updatedTopics.count
        if numMainTopics > 0 {
            // If there's only one main topic, position it in the center
            if numMainTopics == 1 {
                var firstTopic = updatedTopics[0]
                firstTopic.position = CGPoint(x: 400, y: 300) // Center position
                
                // Position all subtopics in a tree layout
                if !firstTopic.subtopics.isEmpty {
                    layoutSubtopicTreeImproved(in: &firstTopic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
                }
                
                updatedTopics[0] = firstTopic
            } else {
                // For multiple main topics, only auto-layout their subtopics
                for i in 0..<numMainTopics {
                    var topic = updatedTopics[i]
                    if !topic.subtopics.isEmpty {
                        layoutSubtopicTreeImproved(in: &topic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
                    }
                    updatedTopics[i] = topic
                }
            }
            
            // Ensure branch styles are preserved after layout
            if let firstTopic = updatedTopics.first {
                // Get the current global branch style from the first topic
                let globalStyle = firstTopic.branchStyle
                
                // Re-apply to all topics to ensure consistency
                for i in 0..<updatedTopics.count {
                    var mainTopic = updatedTopics[i]
                    updateBranchStyleRecursively(&mainTopic, globalStyle)
                    updatedTopics[i] = mainTopic
                }
            }
        }
        
        // Update the published property with all changes
        DispatchQueue.main.async {
            // Store the current selected topic ID
            let currentSelectedId = self.selectedTopicId
            
            // Update topics
            self.topics = updatedTopics
            
            // Ensure selection is maintained
            self.selectedTopicId = currentSelectedId
            
            // Organize relation lines after repositioning
            self.updateAllRelations()
        }
    }

    // New function for the auto-layout button that implements the previous behavior
    func performFullAutoLayout() {
        saveState() // Save state before rearranging

        // Constants for ideal spacing
        let horizontalSpacing: CGFloat = 250 // Space between parent and child
        let verticalSpacing: CGFloat = 100 // Space between siblings
        let baseMainTopicSpacing: CGFloat = 350 // Base space between main topics
        
        // Create a copy of topics to work with
        var updatedTopics = topics
        
        // First position main topics horizontally with equal spacing
        let numMainTopics = updatedTopics.count
        if numMainTopics > 0 {
            // Calculate total width needed for all main topics
            var totalWidth: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            // First pass: calculate dimensions
            for topic in updatedTopics {
                let topicBox = getTopicBox(topic: topic)
                totalWidth += topicBox.width
                maxHeight = max(maxHeight, topicBox.height)
            }
            
            // Add spacing between topics
            totalWidth += baseMainTopicSpacing * CGFloat(numMainTopics - 1)
            
            // Calculate starting X position (centered)
            let startX = 400 - totalWidth / 2
            var currentX = startX
            
            // Second pass: position topics
            for i in 0..<numMainTopics {
                var topic = updatedTopics[i]
                let topicBox = getTopicBox(topic: topic)
                
                // Position the main topic
                topic.position = CGPoint(
                    x: currentX + topicBox.width / 2,
                    y: 300 // Center vertically
                )
                
                // Position all subtopics in a tree layout
                if !topic.subtopics.isEmpty {
                    layoutSubtopicTreeImproved(in: &topic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
                }
                
                updatedTopics[i] = topic
                currentX += topicBox.width + baseMainTopicSpacing
            }
            
            // Ensure branch styles are preserved after layout
            if let firstTopic = updatedTopics.first {
                // Get the current global branch style from the first topic
                let globalStyle = firstTopic.branchStyle
                
                // Re-apply to all topics to ensure consistency
                for i in 0..<updatedTopics.count {
                    var mainTopic = updatedTopics[i]
                    updateBranchStyleRecursively(&mainTopic, globalStyle)
                    updatedTopics[i] = mainTopic
                }
            }
        }
        
        // Update the published property with all changes
        DispatchQueue.main.async {
            // Store the current selected topic ID
            let currentSelectedId = self.selectedTopicId
            
            // Update topics
            self.topics = updatedTopics
            
            // Ensure selection is maintained
            self.selectedTopicId = currentSelectedId
            
            // Organize relation lines after repositioning
            self.updateAllRelations()
        }
    }

    // Improved layout function that ensures subtopics maintain order
    @discardableResult
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
    
    func updateAllRelations() {
        // Collect all topics including subtopics
        var allTopics: [Topic] = []
        for topic in topics {
            allTopics.append(topic)
            allTopics.append(contentsOf: getAllSubtopics(from: topic))
        }
        
        // Create a copy of the topics array for editing
        var updatedTopics = topics
        
        // Update relations in all main topics
        for i in 0..<updatedTopics.count {
            var topic = updatedTopics[i]
            updateRelationsInTopic(topic: &topic, allTopics: allTopics)
            updatedTopics[i] = topic
        }
        
        // Update relations in all subtopics
        for i in 0..<updatedTopics.count {
            var topic = updatedTopics[i]
            updateRelationsInSubtopics(topic: &topic, allTopics: allTopics)
            updatedTopics[i] = topic
        }
        
        // Update the published property outside of view update cycle
        DispatchQueue.main.async {
            self.topics = updatedTopics
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
        // Don't handle keyboard events if text input is active or any topic is being edited
        guard !isTextInputActive && !isAnyTopicEditing() && !shouldBlockKeyboardShortcuts else { 
            // When text input is active, let the system handle the keyboard events naturally
            // without trying to process them for canvas shortcuts
            return 
        }
        
        // Handle key events
        switch event.keyCode {
        case 51: // Delete key
            if let selectedId = selectedTopicId {
                deleteTopic(id: selectedId)
            }
        case 36: // Return key
            addMainTopic(at: position)
        case 49: // Space key
            if let selectedId = selectedTopicId {
                if event.modifierFlags.contains(.control) {
                    // Control+Space to toggle collapse
                    toggleCollapseState(topicId: selectedId)
                } else {
                    // Regular Space to edit topic
                    setTopicEditing(selectedId, isEditing: true)
                }
            }
        case 48: // Tab key
            if let selectedId = selectedTopicId,
               let selectedTopic = getTopicById(selectedId) {
                if event.modifierFlags.contains(.shift) {
                    // Shift+Tab: Move topic up one level if possible
                    if let parentId = findParentTopicId(for: selectedId) {
                        moveTopicToParentLevel(topicId: selectedId, parentId: parentId)
                    }
                } else {
                    // Tab: Create subtopic
                    addSubtopic(to: selectedTopic)
                }
            }
        default:
            break
        }
    }
    
    // Check if a key event was handled by the canvas actions
    // Returns true if the event was handled and should not be propagated
    func handleCanvasAction(_ event: NSEvent) -> Bool {
        // We're specifically checking for Tab key actions
        if event.keyCode == 48 { // Tab key
            // Only consider it handled if there's a selected topic
            if let selectedId = selectedTopicId,
               let _ = getTopicById(selectedId) {
                return true // Tab was used for a mind map operation
            }
        }
        return false // Event wasn't handled by canvas actions
    }
    
    // Check if any topic in the mind map is currently being edited
    private func isAnyTopicEditing() -> Bool {
        for topic in topics {
            if isTopicOrSubtopicsEditing(topic) {
                return true
            }
        }
        return false
    }

    // Find the parent topic ID for a given topic ID
    private func findParentTopicId(for topicId: UUID) -> UUID? {
        // Check main topics' subtopics first
        for topic in topics {
            if topic.subtopics.contains(where: { $0.id == topicId }) {
                return topic.id
            }
            
            // Check nested subtopics
            if let parentId = findParentTopicIdInSubtopics(topicId, in: topic) {
                return parentId
            }
        }
        return nil
    }
    
    // Recursively search for parent topic ID in subtopics
    private func findParentTopicIdInSubtopics(_ targetId: UUID, in topic: Topic) -> UUID? {
        for subtopic in topic.subtopics {
            if subtopic.subtopics.contains(where: { $0.id == targetId }) {
                return subtopic.id
            }
            
            if let parentId = findParentTopicIdInSubtopics(targetId, in: subtopic) {
                return parentId
            }
        }
        return nil
    }
    
    // Move a topic up one level in the hierarchy
    private func moveTopicToParentLevel(topicId: UUID, parentId: UUID) {
        saveState()
        
        // Find the topic to move
        guard let topicToMove = getTopicById(topicId) else { return }
        
        // Find the parent's parent (grandparent) if it exists
        let grandparentId = findParentTopicId(for: parentId)
        
        // Remove the topic from its current parent
        if let parentIndex = topics.firstIndex(where: { $0.id == parentId }) {
            // If parent is a main topic, move the topic to main level
            topics[parentIndex].subtopics.removeAll { $0.id == topicId }
            
            var newTopic = Topic.createMainTopic(at: topicToMove.position, count: mainTopicCount + 1)
            newTopic.name = topicToMove.name
            newTopic.subtopics = topicToMove.subtopics
            newTopic.backgroundColor = topicToMove.backgroundColor
            newTopic.borderColor = topicToMove.borderColor
            newTopic.foregroundColor = topicToMove.foregroundColor
            newTopic.branchStyle = topicToMove.branchStyle
            
            topics.append(newTopic)
            mainTopicCount += 1
        } else {
            // Find and update the topic in the hierarchy
            for i in 0..<topics.count {
                var topic = topics[i]
                if moveTopicUpInHierarchy(topicId: topicId, parentId: parentId, in: &topic) {
                    topics[i] = topic
                    break
                }
            }
        }
        
        // Update layout
        performAutoLayout()
    }
    
    // Recursively move a topic up in the hierarchy
    private func moveTopicUpInHierarchy(topicId: UUID, parentId: UUID, in topic: inout Topic) -> Bool {
        for i in 0..<topic.subtopics.count {
            if topic.subtopics[i].id == parentId {
                // Found the parent, remove the topic from its subtopics
                let topicToMove = topic.subtopics[i].subtopics.first(where: { $0.id == topicId })
                topic.subtopics[i].subtopics.removeAll { $0.id == topicId }
                
                // Add it to the current level
                if let movedTopic = topicToMove {
                    topic.subtopics.append(movedTopic)
                }
                return true
            }
            
            var subtopic = topic.subtopics[i]
            if moveTopicUpInHierarchy(topicId: topicId, parentId: parentId, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        return false
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
        if findTopic(id: fromId) != nil {
            // Update relation drag state
            DispatchQueue.main.async {
                self.relationDragState = (fromId: fromId, toPosition: toPosition)
            }
        }
    }
    
    func handleRelationDragEnded(_ fromId: UUID) {
        // Store current state to work with
        let currentRelationDragState = relationDragState
        
        // Clear the relation drag state first
        relationDragState = nil
        
        // Process the relation if needed
        guard let toPosition = currentRelationDragState?.toPosition,
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
        // Create a copy of the topics array
        var updatedTopics = topics
        
        // Check if it's a main topic
        if let index = updatedTopics.firstIndex(where: { $0.id == updatedTopic.id }) {
            updatedTopics[index] = updatedTopic
            
            // Update the published property at once
            self.topics = updatedTopics
            return
        }
        
        // If it's a subtopic, find and update it
        var topicUpdated = false
        for i in 0..<updatedTopics.count {
            var topic = updatedTopics[i]
            if updateTopicInHierarchy(updatedTopic, in: &topic) {
                updatedTopics[i] = topic
                topicUpdated = true
                break
            }
        }
        
        // Only update the published property if something changed
        if topicUpdated {
            self.topics = updatedTopics
        }
    }
    
    func updateTopicInHierarchy(_ updatedTopic: Topic, in topic: inout Topic) -> Bool {
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
    
    func deleteTopic(id: UUID) {
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
        if topics.first != nil {
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
    func saveState() {
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
        // Mark that dragging is happening (for physics simulation)
        isDragging = true
        
        // Store a copy of the relationDragState to avoid direct modification
        var updatedRelationDragState: (fromId: UUID, toPosition: CGPoint)? = nil
        
        // Create a copy of the topics array
        var updatedTopics = topics
        
        // First check if it's a main topic
        for i in 0..<updatedTopics.count {
            if updatedTopics[i].id == topicId {
                // Calculate offset for all children
                let offset = CGPoint(
                    x: newPosition.x - updatedTopics[i].position.x,
                    y: newPosition.y - updatedTopics[i].position.y
                )
                
                // Update the main topic and all its subtopics with the same offset
                updatePositionsInTopic(topic: &updatedTopics[i], offset: offset)
                
                // Check if this topic is part of the current relation drag
                if let dragState = relationDragState, dragState.fromId == topicId {
                    updatedRelationDragState = (fromId: dragState.fromId, toPosition: newPosition)
                }
                break
            } else {
                // Check if it's a subtopic
                var mainTopic = updatedTopics[i]
                if updateSubtopicPositionRecursively(topicId: topicId, newPosition: newPosition, in: &mainTopic) {
                    updatedTopics[i] = mainTopic
                    
                    // Check if this topic is part of the current relation drag
                    if let dragState = relationDragState, dragState.fromId == topicId {
                        updatedRelationDragState = (fromId: dragState.fromId, toPosition: newPosition)
                    }
                    break
                }
            }
        }
        
        // Update published properties using async dispatch to avoid view update cycle issues
        DispatchQueue.main.async {
            // Update the topics
            self.topics = updatedTopics
            
            // Update the relation drag state if needed
            if let newDragState = updatedRelationDragState {
                self.relationDragState = newDragState
            }
            
            // Update all relations after position changes
            self.updateAllRelationsWithoutDispatch()
        }
    }
    
    // A version of updateAllRelations without the dispatch async, for internal use
    private func updateAllRelationsWithoutDispatch() {
        // Collect all topics including subtopics
        var allTopics: [Topic] = []
        for topic in topics {
            allTopics.append(topic)
            allTopics.append(contentsOf: getAllSubtopics(from: topic))
        }
        
        // Create a copy of the topics array for editing
        var updatedTopics = topics
        
        // Update relations in all main topics
        for i in 0..<updatedTopics.count {
            var topic = updatedTopics[i]
            updateRelationsInTopic(topic: &topic, allTopics: allTopics)
            updatedTopics[i] = topic
        }
        
        // Update relations in all subtopics
        for i in 0..<updatedTopics.count {
            var topic = updatedTopics[i]
            updateRelationsInSubtopics(topic: &topic, allTopics: allTopics)
            updatedTopics[i] = topic
        }
        
        // Update the published property directly (used only inside an async block)
        self.topics = updatedTopics
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
    
    // MARK: - AI Integration Functions
    
    /// Get all topic texts for AI generation
    func getAllTopicTexts() -> [String] {
        var allTexts = [String]()
        
        // Add main topics
        for topic in topics {
            allTexts.append(topic.name)
            // Recursively collect subtopics
            collectSubtopicTexts(from: topic.subtopics, into: &allTexts)
        }
        
        return allTexts
    }
    
    /// Recursively collect subtopic texts
    private func collectSubtopicTexts(from subtopics: [Topic], into texts: inout [String]) {
        for subtopic in subtopics {
            texts.append(subtopic.name)
            collectSubtopicTexts(from: subtopic.subtopics, into: &texts)
        }
    }
    
    /// Get descriptions of connections between topics
    func getConnectionDescriptions() -> [String] {
        var connections = [String]()
        
        // For each main topic, describe its relationship with subtopics
        for topic in topics {
            describeConnections(parentTopic: topic, parentName: topic.name, connections: &connections)
        }
        
        return connections
    }
    
    /// Recursively describe connections between a parent topic and its subtopics
    private func describeConnections(parentTopic: Topic, parentName: String, connections: inout [String]) {
        for subtopic in parentTopic.subtopics {
            connections.append("\(parentName) → \(subtopic.name)")
            describeConnections(parentTopic: subtopic, parentName: subtopic.name, connections: &connections)
        }
    }
    
    /// Get a description of the mind map structure for AI analysis
    func getMindMapStructureDescription() -> String {
        var description = "Mind Map Structure:\n"
        
        if topics.isEmpty {
            return description + "Empty mind map"
        }
        
        for (index, topic) in topics.enumerated() {
            description += "Main Topic \(index + 1): \(topic.name)\n"
            if !topic.subtopics.isEmpty {
                description += describeSubtopicStructure(topic.subtopics, level: 1)
            }
        }
        
        return description
    }
    
    /// Recursively describe the structure of subtopics
    private func describeSubtopicStructure(_ subtopics: [Topic], level: Int) -> String {
        var description = ""
        let indent = String(repeating: "  ", count: level)
        
        for (index, subtopic) in subtopics.enumerated() {
            description += "\(indent)- Subtopic \(index + 1): \(subtopic.name)\n"
            if !subtopic.subtopics.isEmpty {
                description += describeSubtopicStructure(subtopic.subtopics, level: level + 1)
            }
        }
        
        return description
    }
    
    /// Add a new topic from AI suggestions
    func addTopicFromAI(title: String) {
        // Create a position for the new topic
        let centerX = 400.0 // Default center X
        let centerY = 300.0 // Default center Y
        
        // If there's a selected topic, position the new one near it
        var position = CGPoint(x: centerX, y: centerY)
        if let selectedId = selectedTopicId, let selectedTopic = findTopicById(selectedId) {
            // Position to the right of the selected topic
            position = CGPoint(x: selectedTopic.position.x + 250, y: selectedTopic.position.y)
        } else if !topics.isEmpty {
            // If no selection but topics exist, position below the last one
            let lastTopic = topics.last!
            position = CGPoint(x: lastTopic.position.x, y: lastTopic.position.y + 150)
        }
        
        saveState()
        mainTopicCount += 1
        
        // Create new topic with the AI-generated title
        var topic = Topic.createMainTopic(at: position, count: mainTopicCount)
        topic.name = title
        
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
        
        // Select the new topic
        selectedTopicId = topic.id
        
        // Reset text input active flag to ensure keyboard shortcuts work
        isTextInputActive = false
        
        // Ensure the focus returns to the canvas by posting a notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ReturnFocusToCanvas"), object: nil)
        }
        
        // Apply auto-layout while maintaining the new topic's position
        performAutoLayout()
    }
    
    /// Find a topic by its ID (searches the entire topic tree)
    func findTopicById(_ id: UUID) -> Topic? {
        // First check main topics
        if let mainTopic = topics.first(where: { $0.id == id }) {
            return mainTopic
        }
        
        // Then search through subtopics
        for mainTopic in topics {
            if let foundTopic = findSubtopicById(id, in: mainTopic.subtopics) {
                return foundTopic
            }
        }
        
        return nil
    }
    
    /// Recursively search for a subtopic by ID
    private func findSubtopicById(_ id: UUID, in subtopics: [Topic]) -> Topic? {
        for subtopic in subtopics {
            if subtopic.id == id {
                return subtopic
            }
            
            if let foundInChildren = findSubtopicById(id, in: subtopic.subtopics) {
                return foundInChildren
            }
        }
        
        return nil
    }
    
    /// Adds a hierarchy of topics to the canvas based on the selected topics
    func addTopicHierarchy(parentTopics: [TopicWithReason]) {
        // Save current state for undo
        saveState()
        
        // Keep track of the last added parent topic
        var lastAddedParentPosition = CGPoint(x: 400, y: 300)
        var lastParentId: UUID? = nil
        
        // Process each parent topic
        for parentTopic in parentTopics {
            // Only add selected parent topics
            if !parentTopic.isSelected { continue }
            
            // Create position for the parent topic - horizontal layout
            let parentPosition: CGPoint
            if let lastId = lastParentId, let lastTopic = findTopicById(lastId) {
                // Position this parent to the right of the last one
                parentPosition = CGPoint(x: lastTopic.position.x + 300, y: lastTopic.position.y)
            } else if !topics.isEmpty {
                // If there are existing topics, position below the last one
                let lastTopic = topics.last!
                parentPosition = CGPoint(x: lastTopic.position.x, y: lastTopic.position.y + 200)
            } else {
                // Default position for first topic
                parentPosition = lastAddedParentPosition
            }
            
            // Create and add the parent topic
            mainTopicCount += 1
            var parentTopicObj = Topic.createMainTopic(at: parentPosition, count: mainTopicCount)
            parentTopicObj.name = parentTopic.name
            
            // Apply theme colors if available
            if let fillColor = currentThemeFillColor, 
               let borderColor = currentThemeBorderColor,
               let textColor = currentThemeTextColor {
                parentTopicObj.backgroundColor = fillColor
                parentTopicObj.borderColor = borderColor
                parentTopicObj.foregroundColor = textColor
            }
            
            // Apply branch style from existing topics if any
            if !topics.isEmpty {
                parentTopicObj.branchStyle = topics[0].branchStyle
            }
            
            // Add the parent topic
            topics.append(parentTopicObj)
            lastParentId = parentTopicObj.id
            lastAddedParentPosition = parentPosition
            
            // Process children for this parent
            var verticalOffset: CGFloat = 0
            for childTopic in parentTopic.children {
                // Only add selected children
                if !childTopic.isSelected { continue }
                
                // Calculate position for child
                let childPosition = calculateSubtopicPosition(
                    for: parentTopicObj, 
                    verticalOffset: verticalOffset
                )
                
                // Create the child topic
                var childTopicObj = parentTopicObj.createSubtopic(
                    at: childPosition, 
                    count: parentTopicObj.subtopics.count + 1
                )
                childTopicObj.name = childTopic.name
                
                // Add the child to the parent
                if let parentIndex = topics.firstIndex(where: { $0.id == parentTopicObj.id }) {
                    topics[parentIndex].subtopics.append(childTopicObj)
                }
                
                // Increase vertical offset for next child
                verticalOffset += 80
            }
        }
        
        // Reset text input active flag to ensure keyboard shortcuts work
        isTextInputActive = false
        
        // Ensure the focus returns to the canvas by posting a notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ReturnFocusToCanvas"), object: nil)
        }
        
        // Apply auto-layout for better organization
        performAutoLayout()
        
        // Select the first added parent topic if any were added
        if let firstParentId = lastParentId {
            selectedTopicId = firstParentId
        }
    }
    
    /// Calculate position for a subtopic with custom vertical offset
    private func calculateSubtopicPosition(for parentTopic: Topic, verticalOffset: CGFloat) -> CGPoint {
        // Position to the right of the parent with the given vertical offset
        return CGPoint(
            x: parentTopic.position.x + 200,
            y: parentTopic.position.y + verticalOffset - 100 // Center children vertically
        )
    }
    
    // MARK: - Parent-Child Relationship Management
    
    func removeParentChildRelation(parentId: UUID, childId: UUID) {
        // Save current state for undo
        saveState()
        
        // First get a complete copy of the child topic to preserve its structure
        guard let childTopic = getDeepCopyOfTopic(id: childId) else { return }
        
        // Now locate and remove the child from its parent
        var didRemoveChild = false
        
        // Check if the child is at the root level (safety check)
        if let index = topics.firstIndex(where: { $0.id == childId }) {
            // This shouldn't happen often but handle it for safety
            topics.remove(at: index)
            didRemoveChild = true
        }
        
        // Otherwise, search through all topics and remove the child from its parent
        if !didRemoveChild {
            for i in 0..<topics.count {
                var topic = topics[i]
                if removeChildFromTopic(parentId: parentId, childId: childId, in: &topic) {
                    topics[i] = topic
                    didRemoveChild = true
                    break
                }
            }
        }
        
        // Only add the child as a new root topic if we successfully removed it
        if didRemoveChild {
            // Add the child as a new root topic
            topics.append(childTopic)
        }
        
        // Notify observers
        objectWillChange.send()
    }
    
    // Helper function to get a complete deep copy of a topic
    private func getDeepCopyOfTopic(id: UUID) -> Topic? {
        // First try to find at root level
        if let topic = topics.first(where: { $0.id == id }) {
            return topic.deepCopy()
        }
        
        // Next try to find in subtopics
        for rootTopic in topics {
            if let foundTopic = findTopicInSubtopicsRecursively(id: id, in: rootTopic) {
                return foundTopic.deepCopy()
            }
        }
        
        return nil
    }
    
    // Helper function to find a topic in the hierarchy
    private func findTopicInSubtopicsRecursively(id: UUID, in topic: Topic) -> Topic? {
        if topic.id == id {
            return topic
        }
        
        for subtopic in topic.subtopics {
            if let found = findTopicInSubtopicsRecursively(id: id, in: subtopic) {
                return found
            }
        }
        
        return nil
    }
    
    // Helper function to remove a child from a topic hierarchy
    private func removeChildFromTopic(parentId: UUID, childId: UUID, in topic: inout Topic) -> Bool {
        // Check if this is the parent we're looking for
        if topic.id == parentId {
            // Remove the child from this parent's subtopics
            let initialCount = topic.subtopics.count
            topic.subtopics.removeAll(where: { $0.id == childId })
            return initialCount > topic.subtopics.count // Return true if we removed something
        }
        
        // Check in subtopics
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            if removeChildFromTopic(parentId: parentId, childId: childId, in: &subtopic) {
                topic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Orphan Topic Helper Methods
    
    // Add these methods to the CanvasViewModel class
    func isOrphanTopic(_ topic: Topic) -> Bool {
        for potentialParent in topics {
            if isChildOf(parentTopic: potentialParent, childId: topic.id) {
                return false
            }
        }
        return true
    }
    
    private func isChildOf(parentTopic: Topic, childId: UUID) -> Bool {
        // Check direct children
        if parentTopic.subtopics.contains(where: { $0.id == childId }) {
            return true
        }
        
        // Check nested children
        for subtopic in parentTopic.subtopics {
            if isChildOf(parentTopic: subtopic, childId: childId) {
                return true
            }
        }
        
        return false
    }
    
    func hasParentChildCycle(parentId: UUID, childId: UUID) -> Bool {
        // If the child is already an ancestor of the parent, it would create a cycle
        guard let childTopic = findTopic(id: childId) else { return false }
        return isChildOf(parentTopic: childTopic, childId: parentId)
    }
    
    func addSelectedTopicAsChild(parentId: UUID, childId: UUID) {
        // Save state before making changes
        saveState()
        
        // Find the parent and child topics
        guard let parentTopicData = findTopicAndPath(parentId, in: topics),
              let childTopic = findTopicById(childId) else {
            return
        }
        
        let parentTopic = parentTopicData.topic
        let parentIndexPath = parentTopicData.path
        
        // Make a copy of the child topic
        var childCopy = childTopic.deepCopy()
        
        // Remove the child from the root topics if it's there
        topics.removeAll(where: { $0.id == childId })
        
        // Add the child to the parent's subtopics
        var updatedParent = parentTopic
        updatedParent.subtopics.append(childCopy)
        
        // Update the parent in the hierarchy
        if parentIndexPath == nil || (parentIndexPath?.path.isEmpty ?? true) {
            // Parent is at root level
            if let index = parentIndexPath?.index ?? topics.firstIndex(where: { $0.id == parentId }) {
                topics[index] = updatedParent
            }
        } else if let indexPath = parentIndexPath {
            // Parent is a subtopic - need to update it using its path
            var mainTopic = topics[indexPath.index]
            updateSubtopicInPath(updatedParent, at: indexPath.path, in: &mainTopic)
            topics[indexPath.index] = mainTopic
        }
        
        // Position the child relative to the parent
        repositionChildRelativeToParent(parentId: parentId, childId: childId)
        
        // Select the newly added child
        selectTopic(id: childId)
    }
    
    private func repositionChildRelativeToParent(parentId: UUID, childId: UUID) {
        guard let parentTopic = findTopic(id: parentId) else {
            return
        }
        
        // Find the child topic and its index in the parent's subtopics
        let childIndex = parentTopic.subtopics.firstIndex(where: { $0.id == childId }) ?? 0
        
        // Calculate new position for child based on parent's position
        let parentBox = getTopicBox(topic: parentTopic)
        let parentRightEdge = parentBox.maxX
        
        // Horizontal spacing between parent and child
        let horizontalSpacing: CGFloat = 100
        
        // Vertical spacing between siblings
        let verticalSpacing: CGFloat = 80
        
        // Position the child to the right of the parent
        let childX = parentRightEdge + horizontalSpacing
        
        // Calculate Y position based on sibling index
        let childY = parentTopic.position.y + CGFloat(childIndex - (parentTopic.subtopics.count - 1) / 2) * verticalSpacing
        
        // Create the new position
        let newPosition = CGPoint(x: childX, y: childY)
        
        // Update the child's position - look it up in the hierarchy to make sure we have the latest version
        if let childTopic = findTopic(id: childId) {
            // Create updated child
            var updatedChild = childTopic
            updatedChild.position = newPosition
            
            // Update it in the hierarchy
            updateTopic(updatedChild)
        }
    }
    
    private func findTopicInHierarchy(id: UUID, in topics: [Topic]) -> Topic? {
        for topic in topics {
            if topic.id == id {
                return topic
            }
            
            if let found = findTopicInHierarchy(id: id, in: topic.subtopics) {
                return found
            }
        }
        
        return nil
    }
    
    private func updateTopicPositionInHierarchy(topicId: UUID, newPosition: CGPoint) {
        // Try to find and update in root topics
        if let index = topics.firstIndex(where: { $0.id == topicId }) {
            var updatedTopic = topics[index]
            updatedTopic.position = newPosition
            topics[index] = updatedTopic
            return
        }
        
        // Otherwise search through all topics recursively
        updateTopicPositionRecursively(topicId: topicId, newPosition: newPosition, in: &topics)
    }
    
    private func updateTopicPositionRecursively(topicId: UUID, newPosition: CGPoint, in topics: inout [Topic]) {
        for i in 0..<topics.count {
            if topics[i].id == topicId {
                topics[i].position = newPosition
                return
            }
            
            var subtopics = topics[i].subtopics
            updateTopicPositionRecursively(topicId: topicId, newPosition: newPosition, in: &subtopics)
            topics[i].subtopics = subtopics
        }
    }
    
    // Add this function if it doesn't exist
    private func saveHistoryState() {
        // Trim history if we're not at the end
        if currentHistoryIndex < history.count - 1 {
            history = Array(history[0...currentHistoryIndex])
        }
        
        // Add current state to history
        history.append(topics)
        currentHistoryIndex = history.count - 1
        
        // Keep history within size limit
        if history.count > maxHistorySize {
            history.removeFirst()
            currentHistoryIndex -= 1
        }
    }
    
    // Helper function to find a topic and its path in the hierarchy
    private func findTopicAndPath(_ id: UUID, in topics: [Topic]) -> (topic: Topic, path: (index: Int, path: [Int])?)? {
        for (index, topic) in topics.enumerated() {
            if topic.id == id {
                return (topic, (index, []))
            }
            if let (foundTopic, path) = findTopicAndPathInSubtopic(id, in: topic, currentPath: []) {
                return (foundTopic, (index, path))
            }
        }
        return nil
    }
    
    // Helper function to recursively search for a topic in subtopics
    private func findTopicAndPathInSubtopic(_ id: UUID, in topic: Topic, currentPath: [Int]) -> (topic: Topic, path: [Int])? {
        for (index, subtopic) in topic.subtopics.enumerated() {
            if subtopic.id == id {
                return (subtopic, currentPath + [index])
            }
            if let (foundTopic, path) = findTopicAndPathInSubtopic(id, in: subtopic, currentPath: currentPath + [index]) {
                return (foundTopic, path)
            }
        }
        return nil
    }
    
    // Helper function to update a subtopic in the hierarchy
    private func updateSubtopicInPath(_ updatedTopic: Topic, at path: [Int], in topic: inout Topic) {
        // Safety check - make sure path isn't empty
        guard !path.isEmpty else { return }
        
        // Safety check - make sure the first index is within bounds
        let firstIndex = path[0]
        guard firstIndex >= 0 && firstIndex < topic.subtopics.count else { return }
        
        if path.count == 1 {
            // We're at the direct subtopic level
            topic.subtopics[firstIndex] = updatedTopic
        } else {
            // Recurse deeper into the hierarchy
            var subtopic = topic.subtopics[firstIndex]
            updateSubtopicInPath(updatedTopic, at: Array(path.dropFirst()), in: &subtopic)
            topic.subtopics[firstIndex] = subtopic
        }
    }
    
    // MARK: - Notes Management
    
    // Add a note to the currently selected topic
    func addNoteToSelectedTopic() {
        guard let selectedId = selectedTopicId else { return }
        saveState()
        
        // Find and update the selected topic
        mutateTopicById(id: selectedId) { topic in
            // If note exists, prepare for editing
            if let existingNote = topic.note {
                self.currentNoteContent = existingNote.content
                self.isEditingNote = true
            } else {
                // Create a new note
                topic.note = Note()
                self.currentNoteContent = ""
                self.isEditingNote = true
            }
        }
    }
    
    // Save the current note content
    func saveNote() {
        let topicId = showingNoteEditorForTopicId ?? selectedTopicId
        guard let id = topicId, isEditingNote else { return }
        
        // Only save state to history occasionally to avoid filling undo history with every keystroke
        let now = Date()
        let shouldSaveState = now.timeIntervalSince(lastNoteSaveTime) >= noteSaveStateInterval
        
        if shouldSaveState {
            saveState()
            lastNoteSaveTime = now
        }
        
        let trimmedContent = currentNoteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        mutateTopicById(id: id) { topic in
            if trimmedContent.isEmpty {
                // If content is empty, remove the note entirely
                topic.note = nil
            } else if let existingNote = topic.note {
                var updatedNote = existingNote
                updatedNote.content = self.currentNoteContent
                updatedNote.updatedAt = Date()
                topic.note = updatedNote
            } else {
                topic.note = Note(content: self.currentNoteContent)
            }
        }
    }
    
    // Delete the note from the selected topic
    func deleteNoteFromSelectedTopic() {
        let topicId = showingNoteEditorForTopicId ?? selectedTopicId
        guard let id = topicId else { return }
        saveState()
        
        mutateTopicById(id: id) { topic in
            topic.note = nil
        }
        
        isEditingNote = false
        currentNoteContent = ""
    }
    
    // Toggle note visibility
    func toggleNoteVisibility() {
        guard let selectedId = selectedTopicId else { return }
        saveState()
        
        mutateTopicById(id: selectedId) { topic in
            if var note = topic.note {
                note.isVisible.toggle()
                topic.note = note
            }
        }
    }
    
    // Check if a topic has a note
    func topicHasNote(_ topic: Topic) -> Bool {
        guard let note = topic.note else { return false }
        return !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // Check if a topic's note is visible
    func isNoteVisible(_ topic: Topic) -> Bool {
        return topic.note?.isVisible ?? false
    }
    
    // Helper method to find and mutate a topic by ID
    private func mutateTopicById(id: UUID, mutation: (inout Topic) -> Void) {
        // Check main topics first
        if let index = topics.firstIndex(where: { $0.id == id }) {
            var topic = topics[index]
            mutation(&topic)
            topics[index] = topic
            return
        }
        
        // Check subtopics
        for i in 0..<topics.count {
            if mutateTopicInSubtopicsRecursively(id: id, in: &topics[i], mutation: mutation) {
                return
            }
        }
    }
    
    // Recursively find and mutate a topic in the subtopics hierarchy
    private func mutateTopicInSubtopicsRecursively(id: UUID, in parentTopic: inout Topic, mutation: (inout Topic) -> Void) -> Bool {
        // Check if this is the topic we're looking for
        if parentTopic.id == id {
            mutation(&parentTopic)
            return true
        }
        
        // Check in subtopics
        for i in 0..<parentTopic.subtopics.count {
            var subtopic = parentTopic.subtopics[i]
            if mutateTopicInSubtopicsRecursively(id: id, in: &subtopic, mutation: mutation) {
                parentTopic.subtopics[i] = subtopic
                return true
            }
        }
        
        return false
    }
}
