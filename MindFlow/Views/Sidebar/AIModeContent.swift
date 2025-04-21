import SwiftUI

// AI Assistant Mode
fileprivate enum AIAssistantMode: String, CaseIterable {
    case generateIdeas = "Generate Ideas"
    case organizeTopics = "Organize Topics"
    case analyzeStructure = "Analyze Structure"
    case brainStorm = "Brainstorm"
    
    var description: String {
        switch self {
        case .generateIdeas:
            return "Generate new topic ideas and expand your mind map"
        case .organizeTopics:
            return "Get help organizing and structuring your topics"
        case .analyzeStructure:
            return "Analyze your mind map structure and get suggestions"
        case .brainStorm:
            return "Free-form brainstorming and topic exploration"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .generateIdeas:
            return "You are a creative idea generator. Help users generate new topics and ideas for their mind map."
        case .organizeTopics:
            return "You are an organization expert. Help users structure and organize their topics effectively."
        case .analyzeStructure:
            return "You are a mind map analyst. Help users analyze and improve their mind map structure."
        case .brainStorm:
            return "You are a brainstorming facilitator. Help users explore and expand their ideas freely."
        }
    }
}

// Chat Message Model
fileprivate struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
    var topicSuggestions: TopicHierarchyResult? = nil  // Add this field to store topic suggestions
}

// AI mode content
struct AIModeContent: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var isGeneratingIdeas = false
    @State private var isOrganizingTopics = false
    @State private var isAnalyzingStructure = false
    @State private var isGeneratingHierarchy = false
    @State private var aiResults: [String] = []
    @State private var aiError: String? = nil
    @State private var showResults = false
    @State private var showApiKeySheet = false
    @State private var apiKey = ""
    @State private var isKeyValid = false
    @FocusState private var isTextFieldFocused: Bool
    
    // Chat and topic generation
    @State private var userInput: String = ""
    @State private var chatMessages: [ChatMessage] = []
    @State private var selectedParentTopic: Topic? = nil
    @State private var hierarchyResults = TopicHierarchyResult()
    @State private var selectedMode: AIAssistantMode = .generateIdeas
    @State private var showModeSelector = false
    @State private var showTopicMenu = false
    
    // Scroll position management
    @State private var scrollToBottom = false
    @State private var scrollViewHeight: CGFloat = 0
    @State private var scrollViewContentHeight: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // API Key Status Section
            ApiKeyStatusView(showApiKeySheet: $showApiKeySheet, isKeyValid: isKeyValid)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            // Create the content separately instead of as a complex nested structure
            createMainContent()
                .frame(maxHeight: .infinity)
        }
        .onAppear {
            checkApiKey()
        }
        .sheet(isPresented: $showApiKeySheet) {
            ApiKeySetupView(apiKey: $apiKey, onSave: {
                APIConfig.saveGeminiAPIKey(apiKey)
                checkApiKey()
                showApiKeySheet = false
            })
        }
    }
    
    // Create the main sidebar content
    private func createMainContent() -> some View {
        SidebarSection(
            title: "AI Assistant", 
            content: AnyView(createChatInterface())
        )
    }
    
    // Create the chat interface
    private func createChatInterface() -> some View {
        VStack(spacing: 0) {
            // Chat messages and results area
            createChatScrollArea()
            
            Spacer()
            
            // Input area with dark background
            createInputArea()
        }
    }
    
    // Create the scrollable chat area
    private func createChatScrollArea() -> some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chatMessages) { message in
                            if let suggestions = message.topicSuggestions {
                                createSuggestionsView(message: message, suggestions: suggestions)
                                    .id(message.id) // Set id for scroll targeting
                            } else {
                                ChatBubbleView(message: message)
                                    .id(message.id) // Set id for scroll targeting
                            }
                        }
                        
                        // Show loading indicator when generating content
                        if isGeneratingHierarchy || isGeneratingIdeas || isOrganizingTopics || isAnalyzingStructure {
                            HStack {
                                // Position on the left side like an AI response
                                TypingIndicatorBubble()
                                
                                Spacer()
                            }
                            .id("loadingIndicator") // Special ID for the loading indicator
                        }
                        
                        // Invisible spacer view at the bottom for auto-scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottomSpacer")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        GeometryReader { contentGeometry in
                            Color.clear.preference(key: ViewHeightKey.self, value: contentGeometry.size.height)
                        }
                    )
                }
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear.preference(key: ScrollViewHeightKey.self, value: scrollGeometry.size.height)
                    }
                )
                .onPreferenceChange(ViewHeightKey.self) { contentHeight in
                    scrollViewContentHeight = contentHeight
                }
                .onPreferenceChange(ScrollViewHeightKey.self) { scrollHeight in
                    scrollViewHeight = scrollHeight
                }
                .onChange(of: chatMessages.count) { _, _ in
                    scrollToLatestMessage(proxy: scrollViewProxy)
                }
                .onChange(of: isGeneratingHierarchy || isGeneratingIdeas || isOrganizingTopics || isAnalyzingStructure) { _, isGenerating in
                    if isGenerating {
                        scrollToBottom(proxy: scrollViewProxy)
                    }
                }
            }
        }
    }
    
    // Helper method to scroll to the latest message
    private func scrollToLatestMessage(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if let lastMessage = chatMessages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            } else {
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    // Helper method to scroll to the bottom
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo("bottomSpacer", anchor: .bottom)
        }
    }
    
    // Create suggestion view for a message
    private func createSuggestionsView(message: ChatMessage, suggestions: TopicHierarchyResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ChatBubbleView(message: message)
            
            createTopicSuggestionsList(message: message, suggestions: suggestions)
        }
    }
    
    // Create the topic suggestions list view
    private func createTopicSuggestionsList(message: ChatMessage, suggestions: TopicHierarchyResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Topic hierarchies
            ForEach(suggestions.parentTopics.indices, id: \.self) { parentIndex in
                if let messageIndex = chatMessages.firstIndex(where: { $0.id == message.id }),
                   let topicSuggestions = chatMessages[messageIndex].topicSuggestions {
                    ChatHierarchyView(
                        parentTopic: Binding(
                            get: { topicSuggestions.parentTopics[parentIndex] },
                            set: { newValue in
                                chatMessages[messageIndex].topicSuggestions?.parentTopics[parentIndex] = newValue
                            }
                        )
                    )
                }
            }
            
            // Add button
            createAddSelectedButton(message: message)
        }
        .padding(12)
        .background(Color(.darkGray))
        .cornerRadius(16)
    }
    
    // Create the add selected button
    private func createAddSelectedButton(message: ChatMessage) -> some View {
        HStack {
            // Find the message index and suggestions first to determine the button state
            let messageIndex = chatMessages.firstIndex(where: { $0.id == message.id })
            let suggestions = messageIndex.flatMap { chatMessages[$0].topicSuggestions }
            
            // Check if all topics are already selected
            let allSelected = suggestions?.parentTopics.allSatisfy { parent in
                parent.isSelected && parent.children.allSatisfy { $0.isSelected }
            } ?? false
            
            // Select All/Deselect All button - left aligned
            Button(action: {
                if let messageIndex = messageIndex,
                   var suggestions = suggestions {
                    
                    // Toggle selection (select all or deselect all)
                    for i in 0..<suggestions.parentTopics.count {
                        suggestions.parentTopics[i].isSelected = !allSelected
                        
                        for j in 0..<suggestions.parentTopics[i].children.count {
                            suggestions.parentTopics[i].children[j].isSelected = !allSelected
                        }
                    }
                    
                    // Update suggestions in chat message
                    chatMessages[messageIndex].topicSuggestions = suggestions
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: allSelected ? "xmark.circle" : "checkmark.circle")
                        .font(.system(size: 12))
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.system(size: 13))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
//                .background(Color.blue.opacity(0.8))
                .cornerRadius(15)
            }
            
            Spacer()
            
            // Add Selected button - right aligned
            Button("Add Selected") {
                // Find the correct message and extract its topics
                if let _ = messageIndex,
                   let suggestions = suggestions {
                    applyHierarchy(suggestions)
                    addChatMessage("Topics added to mind map", isUser: false)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
//            .background(Color.blue)
            .cornerRadius(15)
        }
        .padding(.top, 8)
    }
    
    // Create the input area
    private func createInputArea() -> some View {
        VStack(spacing: 12) {
            // Text input field
            createTextField()
            
            // Mode buttons
            createButtonRow()
        }
        .padding(12)
        .background(Color(.black))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // Create the text field
    private func createTextField() -> some View {
        let placeholder = getPlaceholderForMode(selectedMode)
        
        return TextField(placeholder, text: $userInput)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(10)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .focused($isTextFieldFocused)
            .onChange(of: isTextFieldFocused) { _, isFocused in
                // Update canvas text input state
                viewModel.isTextInputActive = isFocused
            }
            .onSubmit {
                handleSubmit()
            }
            // Add a keyboard event handler when focused
            .background {
                if isTextFieldFocused {
                    KeyEventHandler { event in
                        // Check for specific key codes that should be intercepted
                        if event.type == .keyDown {
                            switch event.keyCode {
                            case KeyCode.returnKey, KeyCode.tabKey, KeyCode.spaceKey:
                                // Let the TextField handle these keys
                                // And prevent them from affecting the canvas
                                return true
                            default:
                                // Pass through other keystrokes
                                return false
                            }
                        }
                        return false
                    }
                }
            }
    }
    
    // Get placeholder text based on selected mode
    private func getPlaceholderForMode(_ mode: AIAssistantMode) -> String {
        switch mode {
        case .generateIdeas:
            return "Enter a topic to generate ideas..."
        case .organizeTopics:
            return "Ask about organizing your mind map..."
        case .analyzeStructure:
            return "Ask for analysis of your mind map structure..."
        case .brainStorm:
            return "Enter a topic to brainstorm..."
        }
    }
    
    // Handle submit when user presses enter
    private func handleSubmit() {
        // Only proceed if there's actual text and it's not just whitespace
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            userInput = ""
            return
        }
        addChatMessage(userInput, isUser: true)
        generateWithCurrentMode(topic: userInput)
        userInput = ""
        // Reset focus and text input active state
        isTextFieldFocused = false
        viewModel.isTextInputActive = false
    }
    
    // Create the button row with mode selector and topic selector
    private func createButtonRow() -> some View {
        HStack {
            // Brainstorm mode buttonf
            createModeButton()
            
            // Selected Topic button - any selected topic, whether main or subtopic
            if let selectedTopic = viewModel.getSelectedTopic() {
                createTopicButton(selectedTopic)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }
    
    // Create mode selector button
    private func createModeButton() -> some View {
        Button(action: {
            showModeSelector = true
        }) {
            HStack(spacing: 4) {
                Text(selectedMode.rawValue)
                    .font(.system(size: 12))
                    .minimumScaleFactor(0.8)
                Image(systemName: "chevron.up")
                    .font(.system(size: 8))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
//            .background(Color(.darkGray))
            .cornerRadius(4)
        }
        .popover(isPresented: $showModeSelector) {
            ModeSelectorView(
                selectedMode: $selectedMode,
                isPresented: $showModeSelector
            )
        }
    }
    
    // Create topic selector button
    private func createTopicButton(_ selectedTopic: Topic) -> some View {
        let isSubtopicSelected = selectedParentTopic != nil
        let buttonText = isSubtopicSelected 
            ? "Add Under '\(selectedParentTopic!.name)'"
            : "New Topic"
        _ = isSubtopicSelected ? Color.blue : Color(.darkGray)
        let iconName = isSubtopicSelected ? "arrow.down.to.line" : "plus"
            
        return Button(action: {
            showTopicMenu = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 10))
                
                Text(buttonText)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.8)
                
                Image(systemName: "chevron.up")
                    .font(.system(size: 8))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
//            .background(buttonColor)
            .cornerRadius(4)
        }
        .popover(isPresented: $showTopicMenu) {
            createTopicMenu(selectedTopic)
        }
    }
    
    // Create topic selection menu
    private func createTopicMenu(_ selectedTopic: Topic) -> some View {
        let isNewTopicSelected = selectedParentTopic == nil
        let isSubtopicSelected = selectedParentTopic != nil && selectedParentTopic!.id == selectedTopic.id
        
        return VStack(alignment: .leading, spacing: 8) {
            // Selected topic name
            Text(selectedTopic.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
            
            // New topic option
            Button(action: {
                selectedParentTopic = nil
                showTopicMenu = false
            }) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(isNewTopicSelected ? .blue : .primary)
                    
                    Text("New Topic")
                        .font(.system(size: 13))
                        .foregroundColor(isNewTopicSelected ? .blue : .primary)
                    
                    Spacer()
                    
                    if isNewTopicSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isNewTopicSelected ? Color.blue.opacity(0.1) : Color.clear)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Add as subtopic option
            Button(action: {
                selectedParentTopic = selectedTopic
                showTopicMenu = false
            }) {
                HStack {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 12))
                        .foregroundColor(isSubtopicSelected ? .blue : .primary)
                    
                    Text("Add as subtopic")
                        .font(.system(size: 13))
                        .foregroundColor(isSubtopicSelected ? .blue : .primary)
                    
                    Spacer()
                    
                    if isSubtopicSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSubtopicSelected ? Color.blue.opacity(0.1) : Color.clear)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .frame(width: 200)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private func checkApiKey() {
        let key = APIConfig.geminiAPIKey
        apiKey = key
        isKeyValid = !key.contains("YOUR_")
    }
    
    private func addChatMessage(_ text: String, isUser: Bool, topicSuggestions: TopicHierarchyResult? = nil) {
        var message = ChatMessage(text: text, isUser: isUser)
        message.topicSuggestions = topicSuggestions
        chatMessages.append(message)
        // Scroll position will be updated via the onChange handler
    }
    
    private func generateWithCurrentMode(topic: String) {
        // Update the system prompt based on the selected mode
        AIService.shared.updateSystemPrompt(selectedMode.systemPrompt)
        
        // Generate content based on the selected mode
        switch selectedMode {
        case .generateIdeas:
            generateHierarchy(topic: topic, asSubtopics: false)
        case .organizeTopics:
            generateOrganization(topic: topic)
        case .analyzeStructure:
            analyzeMapStructure(topic: topic)
        case .brainStorm:
            generateBrainstorm(topic: topic)
        }
    }
    
    // Generate a topic hierarchy (used by Generate Ideas mode)
    private func generateHierarchy(topic: String, asSubtopics: Bool = false) {
        guard !topic.isEmpty else { return }
        
        isGeneratingHierarchy = true
        aiError = nil
        
        // Get existing topics to avoid duplication
        let existingTopics = viewModel.getAllTopicTexts()
        
        Task {
            do {
                let result = try await AIService.shared.generateTopicHierarchy(
                    topic: topic,
                    existingTopics: existingTopics
                )
                
                DispatchQueue.main.async {
                    // Add AI response with suggestions
                    addChatMessage("Here are some suggested topics:", isUser: false, topicSuggestions: result)
                    isGeneratingHierarchy = false
                }
            } catch {
                DispatchQueue.main.async {
                    addChatMessage("Error generating topic hierarchy: \(error.localizedDescription)", isUser: false)
                    isGeneratingHierarchy = false
                }
            }
        }
    }
    
    // Generate organization suggestions (used by Organize Topics mode)
    private func generateOrganization(topic: String) {
        guard !topic.isEmpty else { return }
        
        isOrganizingTopics = true
        aiError = nil
        
        // Get existing topics and their connections
        let existingTopics = viewModel.getAllTopicTexts()
        let connections = viewModel.getConnectionDescriptions()
        
        Task {
            do {
                let results = try await AIService.shared.organizeTopics(
                    topics: existingTopics,
                    connections: connections
                )
                
                DispatchQueue.main.async {
                    // Format results as markdown
                    var markdownText = "## Organization Suggestions\n\n"
                    
                    for result in results {
                        if result.hasPrefix("STRUCTURE:") {
                            markdownText += "### Overall Structure\n"
                            markdownText += result.replacingOccurrences(of: "STRUCTURE:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            markdownText += "\n\n"
                        } else if result.hasPrefix("GROUP") {
                            let groupParts = result.components(separatedBy: ":")
                            if groupParts.count > 1 {
                                markdownText += "### " + groupParts[0].trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
                                markdownText += groupParts[1].trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ",").map { "- " + $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n")
                                markdownText += "\n\n"
                            }
                        } else if result.hasPrefix("CONNECTIONS:") {
                            markdownText += "### Suggested Connections\n"
                            markdownText += result.replacingOccurrences(of: "CONNECTIONS:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            markdownText += "\n\n"
                        } else {
                            markdownText += result + "\n\n"
                        }
                    }
                    
                    addChatMessage(markdownText, isUser: false)
                    isOrganizingTopics = false
                }
            } catch {
                DispatchQueue.main.async {
                    addChatMessage("Error organizing topics: \(error.localizedDescription)", isUser: false)
                    isOrganizingTopics = false
                }
            }
        }
    }
    
    // Analyze the structure of the mind map (used by Analyze Structure mode)
    private func analyzeMapStructure(topic: String) {
        isAnalyzingStructure = true
        aiError = nil
        
        // Get a structured description of the mind map
        let mindMapStructure = viewModel.getMindMapStructureDescription()
        
        Task {
            do {
                let results = try await AIService.shared.analyzeStructure(
                    topicStructure: mindMapStructure
                )
                
                DispatchQueue.main.async {
                    // Format results as markdown
                    var markdownText = "## Mind Map Analysis\n\n"
                    
                    for result in results {
                        if result.hasPrefix("STRENGTHS:") {
                            markdownText += "### Strengths\n"
                            let content = result.replacingOccurrences(of: "STRENGTHS:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            markdownText += content.components(separatedBy: ",").map { "- " + $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n")
                            markdownText += "\n\n"
                        } else if result.hasPrefix("IMPROVEMENTS:") {
                            markdownText += "### Potential Improvements\n"
                            let content = result.replacingOccurrences(of: "IMPROVEMENTS:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            markdownText += content.components(separatedBy: ",").map { "- " + $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n")
                            markdownText += "\n\n"
                        } else if result.hasPrefix("BALANCE:") {
                            markdownText += "### Balance\n"
                            markdownText += result.replacingOccurrences(of: "BALANCE:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            markdownText += "\n\n"
                        } else if result.hasPrefix("FOCUS:") {
                            markdownText += "### Central Focus\n"
                            markdownText += result.replacingOccurrences(of: "FOCUS:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            markdownText += "\n\n"
                        } else {
                            markdownText += result + "\n\n"
                        }
                    }
                    
                    addChatMessage(markdownText, isUser: false)
                    isAnalyzingStructure = false
                }
            } catch {
                DispatchQueue.main.async {
                    addChatMessage("Error analyzing structure: \(error.localizedDescription)", isUser: false)
                    isAnalyzingStructure = false
                }
            }
        }
    }
    
    // Generate brainstorm ideas (used by Brainstorm mode)
    private func generateBrainstorm(topic: String) {
        guard !topic.isEmpty else { return }
        
        isGeneratingIdeas = true
        aiError = nil
        
        // Get existing topics to use as context
        let existingTopics = viewModel.getAllTopicTexts()
        
        Task {
            do {
                let results = try await AIService.shared.generateIdeas(
                    from: existingTopics.isEmpty ? [topic] : existingTopics
                )
                
                DispatchQueue.main.async {
                    // Format results as markdown
                    var markdownText = "## Brainstorming Results: _\(topic)_\n\n"
                    
                    for result in results {
                        if result.contains("IDEA:") && result.contains("DESCRIPTION:") {
                            let components = result.components(separatedBy: "DESCRIPTION:")
                            if components.count > 1 {
                                let ideaPart = components[0].replacingOccurrences(of: "IDEA:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                                let descriptionPart = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                markdownText += "### \(ideaPart)\n"
                                markdownText += descriptionPart + "\n\n"
                            }
                        } else {
                            markdownText += result + "\n\n"
                        }
                    }
                    
                    addChatMessage(markdownText, isUser: false)
                    isGeneratingIdeas = false
                }
            } catch {
                DispatchQueue.main.async {
                    addChatMessage("Error generating ideas: \(error.localizedDescription)", isUser: false)
                    isGeneratingIdeas = false
                }
            }
        }
    }
    
    private func applyHierarchy(_ suggestions: TopicHierarchyResult) {
        if let parentTopic = selectedParentTopic {
            // Add the selected topics as subtopics of the selected parent topic
            viewModel.addTopicHierarchyAsSubtopics(parentTopic: parentTopic, parentTopics: suggestions.parentTopics)
        } else {
            // Add the selected topics to the canvas as separate topics
            viewModel.addTopicHierarchy(parentTopics: suggestions.parentTopics)
        }
        selectedParentTopic = nil
    }
}

// MARK: - Helper Views
fileprivate struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if message.isUser {
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                } else {
                    MarkdownTextView(text: message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                }
            }
            .background(message.isUser ? Color.blue : Color(.darkGray))
            .cornerRadius(16)
            .frame(maxWidth: message.isUser ? nil : 280)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// Typing indicator bubble with bouncing circles
fileprivate struct TypingIndicatorBubble: View {
    // Animation states
    @State private var firstCircleOffset: CGFloat = 0
    @State private var secondCircleOffset: CGFloat = 0
    @State private var thirdCircleOffset: CGFloat = 0
    
    // Timer for the animation
    let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .offset(y: getOffsetForCircle(index))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.darkGray))
        .cornerRadius(16)
        .onReceive(timer) { _ in
            animateCircles()
        }
        .onAppear {
            // Start the animation immediately
            animateCircles()
        }
    }
    
    // Get the current offset for a specific circle
    private func getOffsetForCircle(_ index: Int) -> CGFloat {
        switch index {
        case 0: return firstCircleOffset
        case 1: return secondCircleOffset
        case 2: return thirdCircleOffset
        default: return 0
        }
    }
    
    // Animate the circles with a staggered effect
    private func animateCircles() {
        // First circle
        withAnimation(Animation.easeInOut(duration: 0.3)) {
            firstCircleOffset = firstCircleOffset == 0 ? -6 : 0
        }
        
        // Second circle with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(Animation.easeInOut(duration: 0.3)) {
                secondCircleOffset = secondCircleOffset == 0 ? -6 : 0
            }
        }
        
        // Third circle with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(Animation.easeInOut(duration: 0.3)) {
                thirdCircleOffset = thirdCircleOffset == 0 ? -6 : 0
            }
        }
    }
}

// Simple Markdown renderer component
fileprivate struct MarkdownTextView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(processedParagraphs.indices, id: \.self) { index in
                let paragraph = processedParagraphs[index]
                
                if paragraph.isCodeBlock {
                    codeBlockView(paragraph.text)
                } else if paragraph.isList {
                    listItemView(paragraph.text)
                } else if paragraph.isHeading {
                    headingView(paragraph.text, level: paragraph.headingLevel)
                } else {
                    richTextView(paragraph.text)
                }
            }
        }
    }
    
    // Process paragraphs to identify code blocks, lists, etc.
    private var processedParagraphs: [ProcessedParagraph] {
        let paragraphs = text.components(separatedBy: "\n\n")
        return paragraphs.map { paragraph in
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if this is a code block (starts with ```and ends with ```)
            let isCodeBlock = trimmed.hasPrefix("```") && trimmed.hasSuffix("```")
            
            // Check if this is a list (lines start with - or * or 1.)
            let isList = trimmed.contains("\n") && (
                trimmed.contains("\n- ") || 
                trimmed.contains("\n* ") || 
                trimmed.contains("\n1. ")
            ) || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("1. ")
            
            // Check if this is a heading (starts with # through ######)
            var isHeading = false
            var headingLevel = 0
            if trimmed.hasPrefix("#") {
                let hashCount = trimmed.prefix(while: { $0 == "#" }).count
                if hashCount >= 1 && hashCount <= 6 && (trimmed.count > hashCount && trimmed[trimmed.index(trimmed.startIndex, offsetBy: hashCount)] == " ") {
                    isHeading = true
                    headingLevel = hashCount
                }
            }
            
            return ProcessedParagraph(
                text: trimmed,
                isCodeBlock: isCodeBlock,
                isList: isList,
                isHeading: isHeading,
                headingLevel: headingLevel
            )
        }
    }
    
    // Render a heading
    private func headingView(_ text: String, level: Int) -> some View {
        let content = text.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        
        switch level {
        case 1:
            return Text(content)
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, 2)
                .eraseToAnyView()
        case 2:
            return Text(content)
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 3)
                .padding(.bottom, 1)
                .eraseToAnyView()
        case 3:
            return Text(content)
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
                .eraseToAnyView()
        default:
            return Text(content)
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .eraseToAnyView()
        }
    }
    
    // Render a code block
    private func codeBlockView(_ text: String) -> some View {
        // Remove the ```marks at beginning and end
        let codeContent = text
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Text(codeContent)
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
    }
    
    // Render a list
    private func listItemView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(text.components(separatedBy: "\n"), id: \.self) { line in
                if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                        richTextView(String(line.dropFirst(2)))
                    }
                } else if line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil,
                          let dotIndex = line.firstIndex(of: ".") {
                    HStack(alignment: .top, spacing: 4) {
                        Text("\(line[..<dotIndex]).")
                            .frame(width: 16, alignment: .trailing)
                        richTextView(String(line[line.index(dotIndex, offsetBy: 2)...]))
                    }
                } else {
                    richTextView(line)
                }
            }
        }
    }
    
    // Render text with basic formatting (bold, italic)
    private func richTextView(_ text: String) -> some View {
        // Parse markdown and create attributed string
        let attributedString = parseMarkdown(text)
        return Text(attributedString)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Basic markdown parsing for bold and italic
    private func parseMarkdown(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Find bold text (**text** or __text__)
        do {
            let boldPattern = try NSRegularExpression(pattern: "(\\*\\*|__)(.+?)(\\*\\*|__)")
            let nsText = text as NSString
            let matches = boldPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 4 {
                    let contentRange = match.range(at: 2)
                    if let range = Range(contentRange, in: text) {
                        let boldText = String(text[range])
                        if let matchRange = Range(match.range, in: text),
                           let rangeInAttributed = Range(matchRange, in: attributedString) {
                            attributedString.replaceSubrange(rangeInAttributed, with: AttributedString(boldText, attributes: .init([.font: Font.bold])))
                        }
                    }
                }
            }
        } catch {
            print("Error parsing markdown bold: \(error)")
        }
        
        // Find italic text (*text* or _text_)
        do {
            let italicPattern = try NSRegularExpression(pattern: "(?<!\\*|_)(\\*|_)(?!\\*|_)(.+?)(?<!\\*|_)(\\*|_)(?!\\*|_)")
            let nsText = text as NSString
            let matches = italicPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 4 {
                    let contentRange = match.range(at: 2)
                    if let range = Range(contentRange, in: text) {
                        let italicText = String(text[range])
                        if let matchRange = Range(match.range, in: text),
                           let rangeInAttributed = Range(matchRange, in: attributedString) {
                            attributedString.replaceSubrange(rangeInAttributed, with: AttributedString(italicText, attributes: .init([.font: Font.italic])))
                        }
                    }
                }
            }
        } catch {
            print("Error parsing markdown italic: \(error)")
        }
        
        return attributedString
    }
}

// Helper struct for paragraph processing
fileprivate struct ProcessedParagraph {
    let text: String
    let isCodeBlock: Bool
    let isList: Bool
    let isHeading: Bool
    let headingLevel: Int
    
    init(text: String, isCodeBlock: Bool, isList: Bool, isHeading: Bool = false, headingLevel: Int = 0) {
        self.text = text
        self.isCodeBlock = isCodeBlock
        self.isList = isList
        self.isHeading = isHeading
        self.headingLevel = headingLevel
    }
}

// Helper extension to make type erasure cleaner
extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

// API Key related views
struct ApiKeyStatusView: View {
    @Binding var showApiKeySheet: Bool
    let isKeyValid: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isKeyValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isKeyValid ? .green : .red)
                .font(.system(size: 14))
            
            Text(isKeyValid ? "Gemini API configured" : "Gemini API key required")
                .font(.subheadline)
                .foregroundColor(isKeyValid ? .secondary : .red)
            
            Spacer()
            
            Button(action: {
                showApiKeySheet = true
            }) {
                Text(isKeyValid ? "Change" : "Set Key")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(8)
        .background(Color(NSColor.darkGray).opacity(0.3))
        .cornerRadius(6)
    }
}

struct ApiKeySetupView: View {
    @Binding var apiKey: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var isTestingConnection = false
    @State private var testResult: String? = nil
    @State private var testError: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set Gemini API Key")
                .font(.headline)
            
            Text("To use AI features, you need a Google Gemini API key.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Visit Google AI Studio to get your API key:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Link("https://ai.google.dev/", destination: URL(string: "https://ai.google.dev/")!)
                    .font(.subheadline)
                
                Text("2. Enter your Gemini API key below:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            SecureField("Enter your Gemini API key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 400)
            
            // Test connection section
            HStack {
                Button("Test Connection") {
                    testConnection()
                }
                .disabled(apiKey.isEmpty || isTestingConnection)
                
                if isTestingConnection {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.leading, 5)
                }
            }
            
            // Show test results if available
            if let result = testResult {
                Text(result)
                    .foregroundColor(.green)
                    .font(.subheadline)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            } else if let error = testError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection failed")
                        .foregroundColor(.red)
                        .font(.subheadline.bold())
                    
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(4)
            }
                        
            Divider()
                .padding(.vertical, 5)
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKey.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 450)
    }
    
    private func testConnection() {
        guard !apiKey.isEmpty else { return }
        
        // Clear previous results
        testResult = nil
        testError = nil
        isTestingConnection = true
        
        // Store the key temporarily for testing
        let currentKey = APIConfig.geminiAPIKey
        APIConfig.saveGeminiAPIKey(apiKey)
        
        // Test connection
        Task {
            let connectionTest = await AIService.shared.testAPIConnection()
            
            // Restore the original key if we're just testing
            if testResult == nil && testError == nil {
                APIConfig.saveGeminiAPIKey(currentKey)
            }
            
            DispatchQueue.main.async {
                switch connectionTest {
                case .success(let message):
                    testResult = message
                case .failure(let error):
                    testError = error.localizedDescription
                }
                isTestingConnection = false
            }
        }
    }
}

fileprivate struct ChatHierarchyView: View {
    @Binding var parentTopic: TopicWithReason
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Toggle("", isOn: $parentTopic.isSelected)
                    .toggleStyle(CheckboxToggleStyle())
                    .labelsHidden()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(parentTopic.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .onTapGesture {
                            parentTopic.isSelected.toggle()
                        }
                    
                    if !parentTopic.reason.isEmpty {
                        Text(parentTopic.reason)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                parentTopic.isSelected.toggle()
            }
            
            if !parentTopic.children.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(parentTopic.children.indices, id: \.self) { childIndex in
                        ChatChildTopicView(
                            childTopic: $parentTopic.children[childIndex]
                        )
                        .padding(.leading, 24)
                    }
                }
            }
        }
    }
}

fileprivate struct ChatChildTopicView: View {
    @Binding var childTopic: TopicWithReason
    
    var body: some View {
        HStack(alignment: .top) {
            Toggle("", isOn: $childTopic.isSelected)
                .toggleStyle(CheckboxToggleStyle())
                .labelsHidden()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(childTopic.name)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .onTapGesture {
                        childTopic.isSelected.toggle()
                    }
                
                if !childTopic.reason.isEmpty {
                    Text(childTopic.reason)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            childTopic.isSelected.toggle()
        }
    }
}

// Mode selector view
private struct ModeSelectorView: View {
    @Binding var selectedMode: AIAssistantMode
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(AIAssistantMode.allCases, id: \.self) { mode in
                Button(action: {
                    selectedMode = mode
                    isPresented = false
                }) {
                    HStack(spacing: 12) {
                        // Mode indicator
                        Circle()
                            .fill(selectedMode == mode ? Color.blue : Color.clear)
                            .frame(width: 6, height: 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            
                            Text(mode.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(selectedMode == mode ? Color.blue.opacity(0.1) : Color.clear)
                }
                .buttonStyle(PlainButtonStyle())
                
                if mode != AIAssistantMode.allCases.last {
                    Divider()
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 300)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Preference Keys for Scroll View
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - KeyEventHandler

/// Helper view to capture keyboard events
struct KeyEventHandler: NSViewRepresentable {
    class Coordinator: NSObject {
        var handler: (NSEvent) -> Bool
        
        init(handler: @escaping (NSEvent) -> Bool) {
            self.handler = handler
        }
        
        @objc func handleEvent(_ event: NSEvent) -> Bool {
            return handler(event)
        }
    }
    
    var handler: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyInterceptorView()
        view.eventHandler = context.coordinator.handleEvent
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyInterceptorView)?.eventHandler = context.coordinator.handleEvent
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(handler: handler)
    }
}

/// Custom NSView that intercepts key events
class KeyInterceptorView: NSView {
    var eventHandler: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if let handler = eventHandler, handler(event) {
            // Event was handled by our handler, don't propagate
            return
        }
        // Not handled by our handler, propagate to next responder
        super.keyDown(with: event)
    }
}
