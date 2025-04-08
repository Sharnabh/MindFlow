import SwiftUI

// Reusable components
struct SidebarSection: View {
    let title: String
    let content: AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .foregroundColor(.primary)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            AnyView(content)
        }
    }
}

struct ColorPickerButton: View {
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 50, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StyledMenuButton<Label: View>: View {
    let content: Label
    let width: CGFloat
    let action: () -> Void
    
    init(width: CGFloat, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.width = width
        self.action = action
        self.content = label()
    }
    
    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: width)
                .background(Color(.darkGray))
                .cornerRadius(6)
        }
    }
}

// Main SidebarView
struct SidebarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isSidebarOpen: Bool
    @Binding var sidebarMode: SidebarMode
    @Binding var backgroundStyle: BackgroundStyle
    @Binding var backgroundColor: Color
    @Binding var backgroundOpacity: Double
    @Binding var isShowingColorPicker: Bool
    @Binding var isShowingBorderColorPicker: Bool
    @Binding var isShowingForegroundColorPicker: Bool
    @Binding var isShowingBackgroundColorPicker: Bool
    
    private let topBarHeight: CGFloat = 40
    private let sidebarWidth: CGFloat = 300
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: topBarHeight)
            
            HStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(Color(.windowBackgroundColor))
                    .frame(width: sidebarWidth)
                    .overlay(
                        VStack(spacing: 16) {
                            // Mode selector
                            Picker("", selection: $sidebarMode) {
                                Text("Style").tag(SidebarMode.style)
                                Text("Map").tag(SidebarMode.map)
                                Text("AI").tag(SidebarMode.ai)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            .padding(.top, 12)
                            
                            Divider()
                                .padding(.horizontal)
                            
                            if sidebarMode == .style {
                                StyleModeContent(
                                    viewModel: viewModel,
                                    isShowingColorPicker: $isShowingColorPicker,
                                    isShowingBorderColorPicker: $isShowingBorderColorPicker,
                                    isShowingForegroundColorPicker: $isShowingForegroundColorPicker
                                )
                            } else if sidebarMode == .map {
                                MapModeContent(
                                    viewModel: viewModel,
                                    backgroundStyle: $backgroundStyle,
                                    backgroundColor: $backgroundColor,
                                    backgroundOpacity: $backgroundOpacity,
                                    isShowingBackgroundColorPicker: $isShowingBackgroundColorPicker
                                )
                            } else {
                                AIModeContent(viewModel: viewModel)
                            }
                            
                            Spacer(minLength: 20)
                        }
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: -1, y: 0)
            }
        }
    }
}

// Style mode content
private struct StyleModeContent: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isShowingColorPicker: Bool
    @Binding var isShowingBorderColorPicker: Bool
    @Binding var isShowingForegroundColorPicker: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if let selectedTopic = viewModel.getSelectedTopic() {
                TopicStyleSection(
                    viewModel: viewModel,
                    selectedTopic: selectedTopic,
                    isShowingColorPicker: $isShowingColorPicker,
                    isShowingBorderColorPicker: $isShowingBorderColorPicker
                )
                
                TextStyleSection(
                    viewModel: viewModel,
                    selectedTopic: selectedTopic,
                    isShowingForegroundColorPicker: $isShowingForegroundColorPicker
                )
                
                BranchStyleSection(viewModel: viewModel, selectedTopic: selectedTopic)
            } else {
                Text("Select a topic to edit its properties")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

// Map mode content
private struct MapModeContent: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var backgroundStyle: BackgroundStyle
    @Binding var backgroundColor: Color
    @Binding var backgroundOpacity: Double
    @Binding var isShowingBackgroundColorPicker: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                BackgroundSection(
                    backgroundStyle: $backgroundStyle,
                    backgroundColor: $backgroundColor,
                    backgroundOpacity: $backgroundOpacity,
                    isShowingBackgroundColorPicker: $isShowingBackgroundColorPicker
                )
                
                AutoLayoutSection()
                ThemeSection(viewModel: viewModel)
            }
        }
    }
}

// AI mode content
private struct AIModeContent: View {
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
    
    // Topic hierarchy generation
    @State private var showHierarchySheet = false
    @State private var showTopicSelectionDialog = false
    @State private var hierarchyTopic = ""
    @State private var hierarchyResults = TopicHierarchyResult()
    @State private var showHierarchyResults = false
    @State private var selectedParentTopic: Topic? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // API Key Status Section
                ApiKeyStatusView(showApiKeySheet: $showApiKeySheet, isKeyValid: isKeyValid)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                SidebarSection(title: "AI Assistant", content: AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ask AI to help you with:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            generateIdeas()
                        }) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("Generate Ideas")
                                    .foregroundColor(.white)
                                Spacer()
                                if isGeneratingIdeas {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.darkGray))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isGeneratingIdeas || isOrganizingTopics || isAnalyzingStructure || !isKeyValid || isGeneratingHierarchy)
                        
                        Button(action: {
                            organizeTopics()
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundColor(.blue)
                                Text("Organize Topics")
                                    .foregroundColor(.white)
                                Spacer()
                                if isOrganizingTopics {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.darkGray))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isGeneratingIdeas || isOrganizingTopics || isAnalyzingStructure || !isKeyValid || isGeneratingHierarchy)
                        
                        Button(action: {
                            analyzeStructure()
                        }) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.green)
                                Text("Analyze Structure")
                                    .foregroundColor(.white)
                                Spacer()
                                if isAnalyzingStructure {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.darkGray))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isGeneratingIdeas || isOrganizingTopics || isAnalyzingStructure || !isKeyValid || isGeneratingHierarchy)
                        
                        // Updated Hierarchy Generator Button
                        Button(action: {
                            if let selectedTopic = viewModel.getSelectedTopic() {
                                showTopicSelectionDialog = true
                                hierarchyTopic = selectedTopic.name
                                selectedParentTopic = selectedTopic
                            } else {
                                showHierarchySheet = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.grid.3x3.fill")
                                    .foregroundColor(.purple)
                                Text("Generate Topic Hierarchy")
                                    .foregroundColor(.white)
                                Spacer()
                                if isGeneratingHierarchy {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.darkGray))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isGeneratingIdeas || isOrganizingTopics || isAnalyzingStructure || !isKeyValid || isGeneratingHierarchy)
                        .confirmationDialog(
                            "Generate from selected topic?",
                            isPresented: $showTopicSelectionDialog,
                            titleVisibility: .visible
                        ) {
                            Button("Use as parent topic") {
                                generateHierarchy(topic: hierarchyTopic, asSubtopics: true)
                            }
                            Button("Use as separate topic") {
                                generateHierarchy(topic: hierarchyTopic, asSubtopics: false)
                            }
                            Button("Enter different topic") {
                                selectedParentTopic = nil
                                showHierarchySheet = true
                            }
                            Button("Cancel", role: .cancel) {
                                selectedParentTopic = nil
                            }
                        } message: {
                            Text("Would you like to generate topics as subtopics of \"\(hierarchyTopic)\" or as separate topics?")
                        }
                        
                        if showResults {
                            Divider()
                                .padding(.vertical, 8)
                            
                            Text("AI Results")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            if let error = aiError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(4)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(aiResults, id: \.self) { result in
                                        Text(result)
                                            .padding(8)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                            .contextMenu {
                                                Button("Add to Mind Map") {
                                                    addToMindMap(result)
                                                }
                                                Button("Copy") {
                                                    NSPasteboard.general.clearContents()
                                                    NSPasteboard.general.setString(result, forType: .string)
                                                }
                                            }
                                    }
                                }
                            }
                            
                            Button("Clear Results") {
                                showResults = false
                                aiResults = []
                                aiError = nil
                            }
                            .padding(.top, 8)
                        }
                        
                        // Hierarchy Results
                        if showHierarchyResults && !hierarchyResults.parentTopics.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                            
                            HierarchyResultsView(
                                hierarchyResults: $hierarchyResults,
                                onApply: {
                                    applyHierarchy()
                                    showHierarchyResults = false
                                },
                                onCancel: {
                                    showHierarchyResults = false
                                    hierarchyResults = TopicHierarchyResult()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                ))
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
            .sheet(isPresented: $showHierarchySheet) {
                HierarchyGeneratorView(
                    topic: $hierarchyTopic,
                    onGenerate: { topic in
                        generateHierarchy(topic: topic)
                        showHierarchySheet = false
                    },
                    onCancel: {
                        showHierarchySheet = false
                    }
                )
            }
        }
    }
    
    private func checkApiKey() {
        let key = APIConfig.geminiAPIKey
        apiKey = key
        isKeyValid = !key.contains("YOUR_")
    }
    
    private func generateIdeas() {
        isGeneratingIdeas = true
        showResults = false
        aiError = nil
        
        // Get current topics from the canvas
        let topics = viewModel.getAllTopicTexts()
        
        Task {
            do {
                let ideas = try await AIService.shared.generateIdeas(from: topics)
                
                DispatchQueue.main.async {
                    aiResults = ideas
                    showResults = true
                    isGeneratingIdeas = false
                }
            } catch {
                DispatchQueue.main.async {
                    aiError = "Error generating ideas: \(error.localizedDescription)"
                    showResults = true
                    isGeneratingIdeas = false
                }
            }
        }
    }
    
    private func organizeTopics() {
        isOrganizingTopics = true
        showResults = false
        aiError = nil
        
        // Get current topics and connections
        let topics = viewModel.getAllTopicTexts()
        let connections = viewModel.getConnectionDescriptions()
        
        Task {
            do {
                let organizationSuggestions = try await AIService.shared.organizeTopics(topics: topics, connections: connections)
                
                DispatchQueue.main.async {
                    aiResults = organizationSuggestions
                    showResults = true
                    isOrganizingTopics = false
                }
            } catch {
                DispatchQueue.main.async {
                    aiError = "Error organizing topics: \(error.localizedDescription)"
                    showResults = true
                    isOrganizingTopics = false
                }
            }
        }
    }
    
    private func analyzeStructure() {
        isAnalyzingStructure = true
        showResults = false
        aiError = nil
        
        // Get structure description of the mind map
        let structureDescription = viewModel.getMindMapStructureDescription()
        
        Task {
            do {
                let analysisResults = try await AIService.shared.analyzeStructure(topicStructure: structureDescription)
                
                DispatchQueue.main.async {
                    aiResults = analysisResults
                    showResults = true
                    isAnalyzingStructure = false
                }
            } catch {
                DispatchQueue.main.async {
                    aiError = "Error analyzing structure: \(error.localizedDescription)"
                    showResults = true
                    isAnalyzingStructure = false
                }
            }
        }
    }
    
    private func addToMindMap(_ suggestion: String) {
        // Extract just the title if it contains a description
        let title = suggestion.components(separatedBy: "\n").first ?? suggestion
        viewModel.addTopicFromAI(title: title)
    }
    
    private func generateHierarchy(topic: String, asSubtopics: Bool = false) {
        guard !topic.isEmpty else { return }
        
        isGeneratingHierarchy = true
        aiError = nil
        // Clear previous results
        hierarchyResults = TopicHierarchyResult()
        
        // Get existing topics to avoid duplication
        let existingTopics = viewModel.getAllTopicTexts()
        
        Task {
            do {
                let result = try await AIService.shared.generateTopicHierarchy(
                    topic: topic,
                    existingTopics: existingTopics
                )
                
                DispatchQueue.main.async {
                    // Mark all topics as selected by default
                    var updatedResult = result
                    for i in 0..<updatedResult.parentTopics.count {
                        updatedResult.parentTopics[i].isSelected = true
                        
                        for j in 0..<updatedResult.parentTopics[i].children.count {
                            updatedResult.parentTopics[i].children[j].isSelected = true
                        }
                    }
                    
                    hierarchyResults = updatedResult
                    showHierarchyResults = true
                    isGeneratingHierarchy = false
                }
            } catch {
                DispatchQueue.main.async {
                    aiError = "Error generating topic hierarchy: \(error.localizedDescription)"
                    showResults = true
                    isGeneratingHierarchy = false
                }
            }
        }
    }
    
    private func applyHierarchy() {
        if let parentTopic = selectedParentTopic {
            // Add the selected topics as subtopics of the selected parent topic
            viewModel.addTopicHierarchyAsSubtopics(parentTopic: parentTopic, parentTopics: hierarchyResults.parentTopics)
        } else {
            // Add the selected topics to the canvas as separate topics
            viewModel.addTopicHierarchy(parentTopics: hierarchyResults.parentTopics)
        }
        selectedParentTopic = nil
    }
}

// MARK: - API Key Views

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

// MARK: - Theme Management
private func applyTheme(
    backgroundColor: Color,
    backgroundStyle: BackgroundStyle,
    topicFillColor: Color,
    topicBorderColor: Color,
    topicTextColor: Color,
    themeName: String = ""
) {
    // ... existing implementation ...
}

// MARK: - Hierarchy Generator Views

struct HierarchyGeneratorView: View {
    @Binding var topic: String
    let onGenerate: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Generate Topic Hierarchy")
                .font(.headline)
            
            Text("Enter a main topic or theme to generate a structured hierarchy of parent and child topics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("Enter main topic (e.g., Artificial Intelligence, Climate Change)", text: $topic)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 400)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    onCancel()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Generate") {
                    onGenerate(topic)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(topic.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 500, height: 200)
    }
}

struct HierarchyResultsView: View {
    @Binding var hierarchyResults: TopicHierarchyResult
    let onApply: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Topic Hierarchy Suggestions")
                .font(.headline)
            
            Text("Select the topics you want to add to your mind map:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(hierarchyResults.parentTopics.indices, id: \.self) { parentIndex in
                        ParentTopicView(
                            parentTopic: $hierarchyResults.parentTopics[parentIndex]
                        )
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 300)
            .background(Color(NSColor.textBackgroundColor).opacity(0.1))
            .cornerRadius(8)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                
                Spacer()
                
                Button("Select All") {
                    selectAll(true)
                }
                
                Button("Deselect All") {
                    selectAll(false)
                }
                
                Button("Add Selected to Mind Map") {
                    onApply()
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
    }
    
    private func selectAll(_ isSelected: Bool) {
        for i in 0..<hierarchyResults.parentTopics.count {
            hierarchyResults.parentTopics[i].isSelected = isSelected
            
            for j in 0..<hierarchyResults.parentTopics[i].children.count {
                hierarchyResults.parentTopics[i].children[j].isSelected = isSelected
            }
        }
    }
}

struct ParentTopicView: View {
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
                    
                    if !parentTopic.reason.isEmpty {
                        Text(parentTopic.reason)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !parentTopic.children.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(parentTopic.children.indices, id: \.self) { childIndex in
                        ChildTopicView(
                            childTopic: $parentTopic.children[childIndex]
                        )
                        .padding(.leading, 24)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ChildTopicView: View {
    @Binding var childTopic: TopicWithReason
    
    var body: some View {
        HStack(alignment: .top) {
            Toggle("", isOn: $childTopic.isSelected)
                .toggleStyle(CheckboxToggleStyle())
                .labelsHidden()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(childTopic.name)
                    .font(.system(size: 14))
                
                if !childTopic.reason.isEmpty {
                    Text(childTopic.reason)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(4)
    }
}

// MARK: - CanvasViewModel Extension
extension CanvasViewModel {
    func addTopicHierarchyAsSubtopics(parentTopic: Topic, parentTopics: [TopicWithReason]) {
        // First, add all selected parent topics as immediate children of the selected topic
        for parentTopicWithReason in parentTopics {
            if parentTopicWithReason.isSelected {
                // Calculate position for the new subtopic
                let subtopicCount = parentTopic.subtopics.count
                let subtopicPosition = calculateNewSubtopicPosition(for: parentTopic, subtopicCount: subtopicCount)
                
                // Create the parent topic as a subtopic
                var newParentTopic = parentTopic.createSubtopic(at: subtopicPosition, count: subtopicCount + 1)
                newParentTopic.name = parentTopicWithReason.name
                
                // Add all selected children under this new parent topic
                for childTopic in parentTopicWithReason.children {
                    if childTopic.isSelected {
                        let childCount = newParentTopic.subtopics.count
                        let childPosition = calculateNewSubtopicPosition(for: newParentTopic, subtopicCount: childCount)
                        
                        var newChildTopic = newParentTopic.createSubtopic(at: childPosition, count: childCount + 1)
                        newChildTopic.name = childTopic.name
                        newParentTopic.subtopics.append(newChildTopic)
                    }
                }
                
                // Update the parent topic in the main topics array
                if let index = topics.firstIndex(where: { $0.id == parentTopic.id }) {
                    topics[index].subtopics.append(newParentTopic)
                } else {
                    // If it's a subtopic, find and update it in the hierarchy
                    var updatedTopics = topics
                    for i in 0..<updatedTopics.count {
                        var topic = updatedTopics[i]
                        if updateTopicInHierarchy(parentTopic, in: &topic) {
                            updatedTopics[i] = topic
                            break
                        }
                    }
                    topics = updatedTopics
                }
            }
        }
        
        // Update the layout to reflect the new structure
        performAutoLayout()
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
        
        return CGPoint(x: x, y: y)
    }
}

