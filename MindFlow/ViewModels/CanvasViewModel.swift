import SwiftUI
import Combine
import AppKit

class CanvasViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var relationDragState: (fromId: UUID, toPosition: CGPoint)?
    @Published var isTextInputActive: Bool = false
    @Published var isEditingNote: Bool = false
    @Published var currentNoteContent: String = ""
    @Published var showingNoteEditorForTopicId: UUID? = nil
    
    // State tracking
    private var isDragging: Bool = false
    
    // Service dependencies
    private let topicService: TopicService
    private let layoutService: LayoutServiceProtocol
    private let historyService: HistoryServiceProtocol
    private var fileService: FileServiceProtocol
    private let keyboardService: KeyboardServiceProtocol
    
    // Relay published properties from services
    @Published var topics: [Topic] = []
    @Published var selectedTopicId: UUID? = nil
    
    // Private subscribers to keep track of changes
    private var cancellables = Set<AnyCancellable>()
    
    // Computed property to check if keyboard shortcuts should be blocked
    var shouldBlockKeyboardShortcuts: Bool {
        // Block shortcuts if we're editing text or a note, 
        // or if the AI sidebar text field is active
        return isTextInputActive || isEditingNote || showingNoteEditorForTopicId != nil
    }
    
    // MARK: - Initialization
    
    init(topicService: TopicService, layoutService: LayoutServiceProtocol, historyService: HistoryServiceProtocol, fileService: FileServiceProtocol, keyboardService: KeyboardServiceProtocol) {
        self.topicService = topicService
        self.layoutService = layoutService
        self.historyService = historyService
        self.fileService = fileService
        self.keyboardService = keyboardService
        
        // Set up publishers/subscribers
        setupSubscriptions()
        
        // Register for notifications
        registerForNotifications()
    }
    
    deinit {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Publisher Setup
    
    private func setupSubscriptions() {
        // Subscribe to topic changes
        topicService.$topics
            .sink { [weak self] topics in
                self?.topics = topics
            }
            .store(in: &cancellables)
        
        // Subscribe to selection changes
        topicService.$selectedTopicId
            .sink { [weak self] selectedId in
                self?.selectedTopicId = selectedId
            }
            .store(in: &cancellables)
            
        // Mark file as having unsaved changes when topics change
        topicService.$topics
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.fileService.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Notification Registration
    
    private func registerForNotifications() {
        // File operations
        NotificationCenter.default.addObserver(self, selector: #selector(handleSaveRequest), name: NSNotification.Name("RequestTopicsForSave"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSaveAsRequest), name: NSNotification.Name("RequestTopicsForSaveAs"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleClearCanvas), name: NSNotification.Name("ClearCanvas"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLoadRequest), name: NSNotification.Name("LoadMindMap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleExportRequest), name: NSNotification.Name("RequestTopicsForExport"), object: nil)
    
        // Undo/Redo
        NotificationCenter.default.addObserver(self, selector: #selector(handleUndoRequest), name: NSNotification.Name("UndoRequested"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRedoRequest), name: NSNotification.Name("RedoRequested"), object: nil)
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleSaveRequest() {
        fileService.saveCurrentFile(topics: topicService.getAllTopics()) { success, errorMessage in
                if let error = errorMessage {
                    print("Failed to save: \(error)")
            }
        }
    }
    
    @objc private func handleSaveAsRequest() {
        fileService.saveFileAs(topics: topicService.getAllTopics()) { success, errorMessage in
                if let error = errorMessage {
                    print("Failed to save: \(error)")
            }
        }
    }
    
    @objc private func handleLoadRequest() {
        // First prompt to save if there are unsaved changes
        if fileService.hasUnsavedChanges {
            // In a real app, you would show a dialog asking to save first
            // For now, we'll just proceed with loading
        }
        
        fileService.loadFile { [weak self] loadedTopics, errorMessage in
                if let topics = loadedTopics {
                self?.loadTopics(topics)
                } else if let error = errorMessage {
                    print("Failed to load: \(error)")
            }
        }
    }
    
    @objc private func handleClearCanvas() {
        // Save current state for undo
        historyService.saveState(topicService.topics)
        
        // Clear all topics
        for topic in topicService.topics {
            topicService.deleteTopic(withId: topic.id)
        }
    }
    
    @objc private func handleUndoRequest() {
        if let previousState = historyService.undo() {
            // Replace current topics with the previous state
            loadTopics(previousState, preserveSelection: true)
        }
    }
    
    @objc private func handleRedoRequest() {
        if let nextState = historyService.redo() {
            // Replace current topics with the next state
            loadTopics(nextState, preserveSelection: true)
        }
    }
    
    @objc private func handleExportRequest() {
        // For now, just export as PNG
        fileService.exportAsPNG(
            topics: topicService.getAllTopics(),
            scale: 1.0,
            offset: CGPoint.zero,
            backgroundColor: .white,
            backgroundStyle: .grid,
            selectedTopicId: selectedTopicId
        )
    }
    
    // MARK: - Topic Management
    
    // Load a set of topics into the canvas
    func loadTopics(_ loadedTopics: [Topic], preserveSelection: Bool = false) {
        // Save current state for undo
        historyService.saveState(topicService.topics)
        
        // Remember currently selected topic ID if needed
        let currentSelectedId = preserveSelection ? selectedTopicId : nil
        
        // Clear existing topics
        for topic in topicService.topics {
            topicService.deleteTopic(withId: topic.id)
        }
        
        // Add loaded topics
        for topic in loadedTopics {
            // Need to add each topic individually due to the recursive nature
            // This is a simplified approach - in a real implementation you'd need
            // to handle the hierarchy properly
            var topicCopy = topic
            topicCopy.isSelected = false
            topicCopy.isEditing = false
            
            // Remove subtopics as we'll add them separately
            let subtopics = topicCopy.subtopics
            topicCopy.subtopics = []
            
            // Add the main topic
            topicService.addTopic(topicCopy)
            
            // TODO: Add subtopics recursively - this is simplified
        }
        
        // Restore selection if needed
        if let selectedId = currentSelectedId {
            topicService.selectTopic(withId: selectedId)
        }
    }
    
    func addMainTopic(at position: CGPoint) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Add the topic
        _ = topicService.addMainTopic(at: position)
    }
    
    func addSubtopic(to parentId: UUID) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Add the subtopic
        _ = topicService.addSubtopic(to: parentId)
        
        // Auto-layout after adding subtopic
        performAutoLayout()
    }
    
    func updateTopic(_ topic: Topic) {
        topicService.updateTopic(topic)
    }
    
    func deleteTopic(withId id: UUID) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Delete the topic
        topicService.deleteTopic(withId: id)
    }
    
    func selectTopic(withId id: UUID?) {
        topicService.selectTopic(withId: id)
    }

    // For TopicView compatibility
    func selectTopic(id: UUID?) {
        selectTopic(withId: id)
    }
    
    func beginEditingTopic(withId id: UUID) {
        topicService.beginEditingTopic(withId: id)
    }
    
    func endEditingTopic(withId id: UUID) {
        topicService.endEditingTopic(withId: id)
    }
    
    func collapseExpandTopic(withId id: UUID) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Toggle collapsed state
        topicService.collapseExpandTopic(withId: id)
    }
    
    func moveTopic(withId id: UUID, to position: CGPoint) {
        guard let topic = topicService.getTopic(withId: id) else { return }
        
        // Calculate the position delta (how much the topic has moved)
        let deltaX = position.x - topic.position.x
        let deltaY = position.y - topic.position.y
        
        // First, move the parent topic
        var updatedTopic = topic
        updatedTopic.position = position
        topicService.updateTopic(updatedTopic)
        
        // Then recursively move all its descendants by the same delta
        moveDescendantTopics(of: updatedTopic, deltaX: deltaX, deltaY: deltaY)
        
        // Update any topics that have a relation to this topic
        // This ensures relationship lines stay connected
        updateRelationshipsToTopic(withId: id)
    }
    
    // Helper method to recursively move all descendants of a topic
    private func moveDescendantTopics(of parentTopic: Topic, deltaX: CGFloat, deltaY: CGFloat) {
        for subtopic in parentTopic.subtopics {
            // Calculate new position for this subtopic
            let newPosition = CGPoint(
                x: subtopic.position.x + deltaX,
                y: subtopic.position.y + deltaY
            )
            
            // Update the subtopic's position
            var updatedSubtopic = subtopic
            updatedSubtopic.position = newPosition
            topicService.updateTopic(updatedSubtopic)
            
            // Recursively move this subtopic's children
            moveDescendantTopics(of: updatedSubtopic, deltaX: deltaX, deltaY: deltaY)
        }
    }
    
    // Helper method to update any topics that have relationships to the moved topic
    private func updateRelationshipsToTopic(withId id: UUID) {
        // Get the moved topic
        guard let movedTopic = topicService.getTopic(withId: id) else { return }
        
        // Check all topics for relationships to the moved topic
        for topic in topics {
            // Update topics that have a relation TO the moved topic
            if topic.relations.contains(id) {
                // This topic has a relation to the moved topic
                // Update it to refresh the relationship line
                topicService.updateTopic(topic)
            }
            
            // Also update topics that the moved topic has a relation TO
            if movedTopic.relations.contains(topic.id) {
                // The moved topic has a relation to this topic
                // Update the moved topic to refresh the relationship line
                topicService.updateTopic(movedTopic)
            }
        }
    }
    
    // MARK: - Relations
    
    func addRelation(from sourceId: UUID, to targetId: UUID) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Add the relation
        topicService.addRelation(from: sourceId, to: targetId)
    }
    
    func removeRelation(from sourceId: UUID, to targetId: UUID) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Remove the relation
        topicService.removeRelation(from: sourceId, to: targetId)
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
    
    // MARK: - Layout
    
    func performAutoLayout() {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Perform layout
        let updatedTopics = layoutService.performAutoLayout(for: topicService.topics)
        
        // Update topics while preserving selection
        let currentSelectedId = selectedTopicId
        
        // Update each topic individually to preserve hierarchy
                for i in 0..<updatedTopics.count {
            topicService.updateTopic(updatedTopics[i])
        }
        
        // Restore selection
        if let selectedId = currentSelectedId {
            topicService.selectTopic(withId: selectedId)
        }
    }
    
    func performFullAutoLayout() {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Perform layout
        let updatedTopics = layoutService.performFullAutoLayout(for: topicService.topics)
        
        // Update topics while preserving selection
        let currentSelectedId = selectedTopicId
        
        // Update each topic individually to preserve hierarchy
                for i in 0..<updatedTopics.count {
            topicService.updateTopic(updatedTopics[i])
        }
        
        // Restore selection
        if let selectedId = currentSelectedId {
            topicService.selectTopic(withId: selectedId)
        }
    }
    
    // MARK: - Theme
    
    func applyThemeToSelectedTopic(fillColor: Color?, borderColor: Color?, textColor: Color?) {
        guard let id = selectedTopicId else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Apply theme
        topicService.applyThemeToTopic(withId: id, fillColor: fillColor, borderColor: borderColor, textColor: textColor)
    }
    
    func applyThemeToAllTopics(fillColor: Color?, borderColor: Color?, textColor: Color?) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Apply theme
        topicService.applyThemeToAllTopics(fillColor: fillColor, borderColor: borderColor, textColor: textColor)
    }
    
    // Additional theme methods for ThemeManager
    
    func getAllTopicIds() -> [UUID] {
        return topicService.getAllTopics().map { $0.id }
    }
    
    func updateTopicBackgroundColor(_ topicId: UUID, color: Color) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Apply theme color recursively to topic and all its descendants
        updateBackgroundColorRecursively(topic: topic, color: color)
    }
    
    private func updateBackgroundColorRecursively(topic: Topic, color: Color) {
        // Apply color to current topic
        topicService.applyThemeToTopic(withId: topic.id, fillColor: color, borderColor: nil, textColor: nil)
        
        // Recursively apply to all subtopics
            for subtopic in topic.subtopics {
            updateBackgroundColorRecursively(topic: subtopic, color: color)
        }
    }
    
    func updateTopicBorderColor(_ topicId: UUID, color: Color) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Apply theme color recursively to topic and all its descendants
        updateBorderColorRecursively(topic: topic, color: color)
    }
    
    private func updateBorderColorRecursively(topic: Topic, color: Color) {
        // Apply color to current topic
        topicService.applyThemeToTopic(withId: topic.id, fillColor: nil, borderColor: color, textColor: nil)
        
        // Recursively apply to all subtopics
        for subtopic in topic.subtopics {
            updateBorderColorRecursively(topic: subtopic, color: color)
        }
    }
    
    func updateTopicForegroundColor(_ topicId: UUID, color: Color) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Apply theme color
        topicService.applyThemeToTopic(withId: topicId, fillColor: nil, borderColor: nil, textColor: color)
    }
    
    func setCurrentTheme(topicFillColor: Color, topicBorderColor: Color, topicTextColor: Color) {
        // Apply theme to all topics
        applyThemeToAllTopics(fillColor: topicFillColor, borderColor: topicBorderColor, textColor: topicTextColor)
        
        // Save this as the default theme for new topics
        Topic.themeColors = (topicFillColor, topicBorderColor, topicTextColor)
    }
    
    // MARK: - Topic Style Methods
    
    func updateTopicShape(_ topicId: UUID, shape: Topic.Shape) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Update the topic shape
        var updatedTopic = topic
        updatedTopic.shape = shape
        topicService.updateTopic(updatedTopic)
    }
    
    func updateTopicBackgroundOpacity(_ topicId: UUID, opacity: Double) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Update the topic background opacity
        var updatedTopic = topic
        updatedTopic.backgroundOpacity = opacity
        topicService.updateTopic(updatedTopic)
    }
    
    func updateTopicBorderOpacity(_ topicId: UUID, opacity: Double) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Update the topic border opacity
        var updatedTopic = topic
        updatedTopic.borderOpacity = opacity
        topicService.updateTopic(updatedTopic)
    }
    
    func updateTopicBorderWidth(_ topicId: UUID, width: Topic.BorderWidth) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Update the topic border width
        var updatedTopic = topic
        updatedTopic.borderWidth = width
        topicService.updateTopic(updatedTopic)
    }
    
    // MARK: - Notes
    
    func topicHasNote(_ topic: Topic) -> Bool {
        return topic.note != nil && !(topic.note?.content.isEmpty ?? true)
    }
    
    // Add a note to the currently selected topic
    func addNoteToSelectedTopic() {
        guard let selectedId = selectedTopicId,
              let topic = topicService.getTopic(withId: selectedId) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // If note exists, prepare for editing
        if let existingNote = topic.note {
            currentNoteContent = existingNote.content
            isEditingNote = true
            showingNoteEditorForTopicId = selectedId
        } else {
            // Create a new note
            var updatedTopic = topic
            updatedTopic.note = Note()
            topicService.updateTopic(updatedTopic)
            
            // Update state for editing
            currentNoteContent = ""
            isEditingNote = true
            showingNoteEditorForTopicId = selectedId
        }
    }
    
    func beginEditingNote(for topicId: UUID) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Update state
        isEditingNote = true
        showingNoteEditorForTopicId = topicId
        currentNoteContent = topic.note?.content ?? ""
    }
    
    func saveNote(for topicId: UUID, content: String) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Update the note
        var updatedTopic = topic
        updatedTopic.note = Note(content: content)
        topicService.updateTopic(updatedTopic)
        
        // Update state
        isEditingNote = false
        showingNoteEditorForTopicId = nil
        currentNoteContent = ""
    }
    
    // New method for auto-saving without closing the editor
    func autoSaveNote(for topicId: UUID, content: String) {
        guard let topic = topicService.getTopic(withId: topicId) else { return }
        
        // Update the note without closing the editor
        var updatedTopic = topic
        updatedTopic.note = Note(content: content)
        topicService.updateTopic(updatedTopic)
    }
    
    func cancelNoteEditing() {
        isEditingNote = false
        showingNoteEditorForTopicId = nil
        currentNoteContent = ""
    }
    
    func saveNote() {
        if let topicId = showingNoteEditorForTopicId {
            saveNote(for: topicId, content: currentNoteContent)
        }
    }
    
    // New method for auto-saving the current note without closing the editor
    func autoSaveCurrentNote() {
        if let topicId = showingNoteEditorForTopicId {
            autoSaveNote(for: topicId, content: currentNoteContent)
        }
    }
    
    func deleteNoteFromSelectedTopic() {
        if let topicId = showingNoteEditorForTopicId,
           let topic = topicService.getTopic(withId: topicId) {
            // Save state for undo
            historyService.saveState(topicService.topics)
            
            // Remove the note
            var updatedTopic = topic
            updatedTopic.note = nil
            topicService.updateTopic(updatedTopic)
            
            // Update state
            isEditingNote = false
            showingNoteEditorForTopicId = nil
            currentNoteContent = ""
        }
    }
    
    // MARK: - Clipboard Operations
    
    func copyTopic(withId id: UUID) {
        topicService.copyTopic(withId: id)
    }
    
    func pasteTopic(at position: CGPoint) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Paste the topic
        _ = topicService.pasteTopic(at: position)
    }
    
    // MARK: - Convenience Properties
    
    var canUndo: Bool {
        return historyService.canUndo
    }
    
    var canRedo: Bool {
        return historyService.canRedo
    }
    
    // MARK: - Topic Operations (Required by TopicView)
    
    func findTopic(id: UUID) -> Topic? {
        return topicService.getTopic(withId: id)
    }
    
    func getSelectedTopic() -> Topic? {
        guard let selectedId = selectedTopicId else { return nil }
        return topicService.getTopic(withId: selectedId)
    }
    
    func isOrphanTopic(_ topic: Topic) -> Bool {
        return topicService.isOrphanTopic(topic)
    }
    
    func hasParentChildCycle(parentId: UUID, childId: UUID) -> Bool {
        return topicService.hasParentChildCycle(parentId: parentId, childId: childId)
    }
    
    func addSelectedTopicAsChild(parentId: UUID, childId: UUID) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Add the selected topic as a child
        topicService.addTopicAsChild(parentId: parentId, childId: childId)
        
        // Update layout
        performAutoLayout()
    }
    
    func updateDraggedTopicPosition(_ id: UUID, _ position: CGPoint) {
        // Save state on first drag if we haven't already
        if !isDragging {
            historyService.saveState(topicService.topics)
            isDragging = true
        }
        
        // Update topic position
        moveTopic(withId: id, to: position)
    }
    
    func handleDragEnd(_ id: UUID) {
        // Save state after dragging for undo capability
        historyService.saveState(topicService.topics)
        
        // Reset drag state
        isDragging = false
    }
    
    func updateTopicName(_ id: UUID, _ name: String) {
        guard let topic = topicService.getTopic(withId: id) else { return }
        
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Update the topic name
        var updatedTopic = topic
        updatedTopic.name = name
        topicService.updateTopic(updatedTopic)
    }
    
    func setTopicEditing(_ id: UUID, _ isEditing: Bool) {
        if isEditing {
            beginEditingTopic(withId: id)
            } else {
            endEditingTopic(withId: id)
        }
    }
    
    func handleRelationDragChanged(_ fromId: UUID, _ toPosition: CGPoint) {
        startRelationDrag(from: fromId, to: toPosition)
    }
    
    func handleRelationDragEnded(_ fromId: UUID) {
        // If we have a relation drag state
        if let (sourceId, toPosition) = relationDragState {
            // Find the target topic at the end position
            if let targetTopic = findTopicAt(position: toPosition, in: topics) {
                // Don't create relation to self
                if sourceId != targetTopic.id {
                    // Add the relationship
                    addRelation(from: sourceId, to: targetTopic.id)
                }
            }
        }
        
        // Clear the drag state
        endRelationDrag()
    }
    
    func removeParentChildRelation(childId: UUID) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Remove parent-child relationship
        topicService.removeParentChildRelation(childId: childId)
    }
    
    // MARK: - Keyboard Event Handling
    
    func handleKeyPress(_ event: NSEvent, at position: CGPoint) {
        keyboardService.handleKeyPress(event, at: position, canvasViewModel: self)
    }
    
    // MARK: - History Management
    
    func saveState() {
        historyService.saveState(topicService.topics)
    }
    
    func undo() {
        if let previousState = historyService.undo() {
            loadTopics(previousState, preserveSelection: true)
        }
    }
    
    func redo() {
        if let nextState = historyService.redo() {
            loadTopics(nextState, preserveSelection: true)
        }
    }
    
    // MARK: - TouchBar Support
    
    func getTopicById(_ id: UUID) -> Topic? {
        return findTopic(id: id)
    }
    
    func isTopicCollapsed(id: UUID) -> Bool {
        guard let topic = findTopic(id: id) else { return false }
            return topic.isCollapsed
        }
        
    func countAllDescendants(for topic: Topic) -> Int {
        return topic.subtopics.count + topic.subtopics.reduce(0) { count, subtopic in
            count + countAllDescendants(for: subtopic)
        }
    }
    
    func toggleCollapseState(topicId: UUID) {
        collapseExpandTopic(withId: topicId)
    }
    
    // MARK: - AI Support Methods
    
    func getAllTopicTexts() -> [String] {
        return topicService.getAllTopics().map { $0.name }
    }
    
    func getConnectionDescriptions() -> [String] {
        var connections: [String] = []
        
        // Get all topics
        let allTopics = topicService.getAllTopics()
        
        // Create a map of IDs to names for quick lookup
        let idToNameMap = Dictionary(uniqueKeysWithValues: allTopics.map { ($0.id, $0.name) })
        
        // Process parent-child relationships
        for topic in allTopics {
        for subtopic in topic.subtopics {
                connections.append("\(topic.name) -> \(subtopic.name) (parent/child)")
            }
            
            // Process custom relationships
            for relatedTopicId in topic.relations {
                if let relatedName = idToNameMap[relatedTopicId] {
                    connections.append("\(topic.name) -> \(relatedName) (relation)")
                }
            }
        }
        
        return connections
    }
    
    func getMindMapStructureDescription() -> String {
        // Generate a textual description of the mind map structure
        var description = "Mind Map Structure:\n"
        
        // Root level topics
        let rootTopics = topicService.getAllTopics().filter { $0.parentId == nil }
        description += "Main Topics (\(rootTopics.count)):\n"
        
        for (index, topic) in rootTopics.enumerated() {
            description += "- Main Topic \(index + 1): \(topic.name)\n"
            description += describeSubtopics(topic, level: 1)
            description += "\n"
        }
        
        // Describe relationships
        description += "\nRelationships:\n"
        let relationships = getConnectionDescriptions().filter { $0.contains("(relation)") }
        for relationship in relationships {
            description += "- \(relationship)\n"
        }
        
        return description
    }
    
    private func describeSubtopics(_ topic: Topic, level: Int) -> String {
        var description = ""
        let indent = String(repeating: "  ", count: level)
        
        for (index, subtopic) in topic.subtopics.enumerated() {
            description += "\(indent)- Subtopic \(index + 1): \(subtopic.name)\n"
            
            if !subtopic.subtopics.isEmpty {
                description += describeSubtopics(subtopic, level: level + 1)
            }
        }
        
        return description
    }
    
    func addTopicHierarchy(parentTopics: [TopicWithReason]) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Add each parent topic as a main topic
        var xOffset: CGFloat = 0
        
        for parentTopic in parentTopics.filter({ $0.isSelected }) {
            // Create position with offset
            let position = CGPoint(x: 100 + xOffset, y: 100)
            xOffset += 200 // Space them out horizontally
            
            // Add as main topic
            var newTopic = Topic.createMainTopic(at: position, count: topicService.getAllTopics().count + 1)
            newTopic.name = parentTopic.name
            
            // Apply current theme colors if they exist
            if let backgroundColor = Topic.themeColors.backgroundColor,
               let borderColor = Topic.themeColors.borderColor,
               let textColor = Topic.themeColors.foregroundColor {
                newTopic.backgroundColor = backgroundColor
                newTopic.borderColor = borderColor
                newTopic.foregroundColor = textColor
            }
            
            // Add the topic to the canvas
            var addedTopicId = newTopic.id
            topicService.addTopic(newTopic)
            
            // Add children
            var yOffset: CGFloat = 0
            for childTopic in parentTopic.children.filter({ $0.isSelected }) {
                // Create child position
                let childPosition = CGPoint(x: position.x + 150, y: position.y + yOffset)
                yOffset += 60 // Space them out vertically
                
                // Add as subtopic
                if let topic = topicService.getTopic(withId: addedTopicId) {
                    let childCount = topic.subtopics.count + 1
                    var newSubtopic = topic.createSubtopic(at: childPosition, count: childCount)
                    newSubtopic.name = childTopic.name
                    
                    // Apply current theme colors if they exist
                    if let backgroundColor = Topic.themeColors.backgroundColor,
                       let borderColor = Topic.themeColors.borderColor,
                       let textColor = Topic.themeColors.foregroundColor {
                        newSubtopic.backgroundColor = backgroundColor
                        newSubtopic.borderColor = borderColor
                        newSubtopic.foregroundColor = textColor
                    }
                    
                    // Add the subtopic
                    if let parentPath = topicService.findTopicPath(id: addedTopicId) {
                        var parent = parentPath.topic
                        parent.subtopics.append(newSubtopic)
                        topicService.updateTopic(parent)
                    }
                }
            }
        }
        
        // Auto layout after adding all topics
        performAutoLayout()
    }
    
    // MARK: - Text Formatting
    
    func updateTopicFont(_ id: UUID, font: String) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        if let topicPath = topicService.findTopicPath(id: id) {
            var topic = topicPath.topic
            topic.font = font
            topicService.updateTopic(topic)
        }
    }
    
    func updateTopicFontSize(_ id: UUID, size: CGFloat) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        if let topicPath = topicService.findTopicPath(id: id) {
            var topic = topicPath.topic
            topic.fontSize = size
            topicService.updateTopic(topic)
        }
    }
    
    func updateTopicFontWeight(_ id: UUID, weight: Font.Weight) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        if let topicPath = topicService.findTopicPath(id: id) {
            var topic = topicPath.topic
            topic.fontWeight = weight
            topicService.updateTopic(topic)
        }
    }
    
    func updateTopicForegroundOpacity(_ id: UUID, opacity: Double) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        if let topicPath = topicService.findTopicPath(id: id) {
            var topic = topicPath.topic
            topic.foregroundOpacity = opacity
            topicService.updateTopic(topic)
        }
    }
    
    func updateTopicTextStyle(_ id: UUID, style: TextStyle, isEnabled: Bool) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        if let topicPath = topicService.findTopicPath(id: id) {
            var topic = topicPath.topic
            if isEnabled {
                topic.textStyles.insert(style)
            } else {
                topic.textStyles.remove(style)
            }
            topicService.updateTopic(topic)
        }
    }
    
    func updateTopicTextCase(_ id: UUID, textCase: TextCase) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        if let topicPath = topicService.findTopicPath(id: id) {
            var topic = topicPath.topic
            topic.textCase = textCase
            topicService.updateTopic(topic)
        }
    }
    
    func updateTopicTextAlignment(_ id: UUID, alignment: TextAlignment) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        if let topicPath = topicService.findTopicPath(id: id) {
            var topic = topicPath.topic
            topic.textAlignment = alignment
            topicService.updateTopic(topic)
        }
    }
    
    func updateTopicBranchStyle(_ id: UUID?, style: Topic.BranchStyle) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        if let id = id, let topicPath = topicService.findTopicPath(id: id) {
            // Apply to specific topic and its descendants
            var topic = topicPath.topic
            updateBranchStyleRecursively(topic: &topic, style: style)
            topicService.updateTopic(topic)
        } else {
            // Apply to all topics when id is nil
            var allTopics = topicService.topics
            for i in 0..<allTopics.count {
                var topic = allTopics[i]
                updateBranchStyleRecursively(topic: &topic, style: style)
                allTopics[i] = topic
            }
            topicService.updateAllTopics(allTopics)
        }
    }
    
    private func updateBranchStyleRecursively(topic: inout Topic, style: Topic.BranchStyle) {
        // Update the current topic
        topic.branchStyle = style
        
        // Update all subtopics recursively
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            updateBranchStyleRecursively(topic: &subtopic, style: style)
                topic.subtopics[i] = subtopic
        }
    }
    
    // MARK: - Add Topic Hierarchy as Subtopics
    
    func addTopicHierarchyAsSubtopics(parentTopic: Topic, parentTopics: [TopicWithReason]) {
        // Save state for undo
        historyService.saveState(topicService.topics)
        
        // Process all selected parent topics
        let selectedParentTopics = parentTopics.filter { $0.isSelected }
        
        // If no topics are selected, there's nothing to do
        if selectedParentTopics.isEmpty {
            return
        }
        
        // If parent is a main topic, handle it directly
        if parentTopic.parentId == nil {
            // Add all selected topics as subtopics
            for parentTopicWithReason in selectedParentTopics {
                // Create new subtopic
                let subtopicCount = parentTopic.subtopics.count
                let subtopicPosition = calculatePositionForNewSubtopic(parentTopic, subtopicCount)
                
                var newSubtopic = parentTopic.createSubtopic(at: subtopicPosition, count: subtopicCount + 1)
                newSubtopic.name = parentTopicWithReason.name
                
                // Inherit parent's colors directly
                newSubtopic.backgroundColor = parentTopic.backgroundColor
                newSubtopic.borderColor = parentTopic.borderColor
                newSubtopic.foregroundColor = parentTopic.foregroundColor
                newSubtopic.backgroundOpacity = parentTopic.backgroundOpacity
                newSubtopic.borderOpacity = parentTopic.borderOpacity
                
                // Add children to the new subtopic
                var childSubtopics: [Topic] = []
                for childTopic in parentTopicWithReason.children where childTopic.isSelected {
                    let childCount = childSubtopics.count
                    let childPosition = CGPoint(x: subtopicPosition.x + 150, y: subtopicPosition.y + CGFloat(childCount) * 60)
                    
                    var newChildTopic = newSubtopic.createSubtopic(at: childPosition, count: childCount + 1)
                    newChildTopic.name = childTopic.name
                    
                    // Child topics also inherit the parent's colors
                    newChildTopic.backgroundColor = parentTopic.backgroundColor
                    newChildTopic.borderColor = parentTopic.borderColor
                    newChildTopic.foregroundColor = parentTopic.foregroundColor
                    newChildTopic.backgroundOpacity = parentTopic.backgroundOpacity
                    newChildTopic.borderOpacity = parentTopic.borderOpacity
                    
                    childSubtopics.append(newChildTopic)
                }
                
                // Add the subtopic with its children to the parent
                if let parentPath = topicService.findTopicPath(id: parentTopic.id) {
                    var updatedParent = parentPath.topic
                    newSubtopic.subtopics = childSubtopics
                    updatedParent.subtopics.append(newSubtopic)
                    topicService.updateTopic(updatedParent)
                }
            }
        } else {
            // For nested subtopics, find the parent and add to it
            if let parentPath = topicService.findTopicPath(id: parentTopic.id) {
                var updatedParent = parentPath.topic
                
                // Add all selected topics as subtopics
                for parentTopicWithReason in selectedParentTopics {
                    // Create new subtopic
                    let subtopicCount = updatedParent.subtopics.count
                    let subtopicPosition = calculatePositionForNewSubtopic(updatedParent, subtopicCount)
                    
                    var newSubtopic = updatedParent.createSubtopic(at: subtopicPosition, count: subtopicCount + 1)
                    newSubtopic.name = parentTopicWithReason.name
                    
                    // Inherit parent's colors directly
                    newSubtopic.backgroundColor = updatedParent.backgroundColor
                    newSubtopic.borderColor = updatedParent.borderColor
                    newSubtopic.foregroundColor = updatedParent.foregroundColor
                    newSubtopic.backgroundOpacity = updatedParent.backgroundOpacity
                    newSubtopic.borderOpacity = updatedParent.borderOpacity
                    
                    // Add children to the new subtopic
                    var childSubtopics: [Topic] = []
                    for childTopic in parentTopicWithReason.children where childTopic.isSelected {
                        let childCount = childSubtopics.count
                        let childPosition = CGPoint(x: subtopicPosition.x + 150, y: subtopicPosition.y + CGFloat(childCount) * 60)
                        
                        var newChildTopic = newSubtopic.createSubtopic(at: childPosition, count: childCount + 1)
                        newChildTopic.name = childTopic.name
                        
                        // Child topics also inherit the parent's colors
                        newChildTopic.backgroundColor = updatedParent.backgroundColor
                        newChildTopic.borderColor = updatedParent.borderColor
                        newChildTopic.foregroundColor = updatedParent.foregroundColor
                        newChildTopic.backgroundOpacity = updatedParent.backgroundOpacity
                        newChildTopic.borderOpacity = updatedParent.borderOpacity
                        
                        childSubtopics.append(newChildTopic)
                    }
                    
                    newSubtopic.subtopics = childSubtopics
                    updatedParent.subtopics.append(newSubtopic)
                }
                
                topicService.updateTopic(updatedParent)
            }
        }
        
        // Auto layout after adding all topics
        performAutoLayout()
    }
    
    private func calculatePositionForNewSubtopic(_ parentTopic: Topic, _ subtopicCount: Int) -> CGPoint {
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
        
        return CGPoint(x: x, y: y)
    }
}
