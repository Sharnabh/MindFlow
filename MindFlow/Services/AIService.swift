import SwiftUI
import GoogleGenerativeAI
import Combine
import Network

/// Service for AI-related functionalities
class AIService: ObservableObject {
    // Add shared singleton instance
    static let shared = AIService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var apiStatus: APIStatus = .unknown
    
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = true
    
    init() {
        // Setup network monitoring
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
            self?.isNetworkAvailable = path.status == .satisfied
                if !self!.isNetworkAvailable && self!.isLoading {
                    self?.errorMessage = "Network connection lost. Please check your internet connection and try again."
                    self?.isLoading = false
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Updates the system prompt for subsequent AI interactions
    /// - Parameter systemPrompt: The new system prompt to use
    func updateSystemPrompt(_ systemPrompt: String) {
        // Store the system prompt for future API calls
        self.systemPrompt = systemPrompt
    }
    
    /// Tests connection to the Gemini API and returns a result
    /// - Returns: A result indicating success or failure
    func testAPIConnection() async -> Result<String, Error> {
        // Fetch the current API key
        let currentApiKey = APIConfig.geminiAPIKey

        guard !currentApiKey.isEmpty && currentApiKey != "YOUR_GEMINI_API_KEY" else {
            self.apiStatus = .missingAPIKey
            return .failure(APIError.missingAPIKey)
        }
        
        guard isNetworkAvailable else {
            self.apiStatus = .noInternet
            return .failure(APIError.noInternetConnection)
        }
        
        let testPrompt = "Respond with 'OK' if you can receive this message."
        
        do {
            let result = try await callGeminiAPIAsync(with: testPrompt)
            self.apiStatus = .connected
            return .success("Connection successful!")
        } catch {
            self.apiStatus = .failed
            return .failure(error)
        }
    }
    
    /// Generates ideas related to a central topic
    /// - Parameters:
    ///   - centralTopic: The central topic to generate ideas for
    ///   - existingTopics: Optional existing topics to consider
    ///   - count: Number of ideas to generate (default: 5)
    ///   - completion: Callback with generated topics or error
    func generateIdeas(
        for centralTopic: String,
        existingTopics: [String] = [],
        count: Int = 5,
        completion: @escaping (Result<[TopicWithReason], Error>) -> Void
    ) {
        isLoading = true
        errorMessage = nil
        
        let prompt = createIdeaGenerationPrompt(
            centralTopic: centralTopic,
            existingTopics: existingTopics,
            count: count
        )
        
        callGeminiAPI(with: prompt) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    do {
                        let topics = try self?.parseTopicsResponse(response) ?? []
                        completion(.success(topics))
                    } catch {
                        self?.errorMessage = "Failed to parse AI response: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                    
                case .failure(let error):
                    self?.errorMessage = "AI request failed: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Generate ideas asynchronously 
    /// - Parameter topics: Existing topics to base ideas on
    /// - Returns: Array of idea strings
    func generateIdeas(from topics: [String]) async throws -> [String] {
        isLoading = true
        errorMessage = nil
        
        let prompt = """
        Based on these existing topics, generate 5-7 creative and insightful ideas:
        \(topics.map { "- \($0)" }.joined(separator: "\n"))
        
        Format each idea as:
        IDEA: [Short, catchy title]
        DESCRIPTION: [1-2 sentence explanation]
        """
        
        do {
            let response = try await callGeminiAPIAsync(with: prompt)
            
            // Parse the response into separate ideas (each paragraph is an idea)
            let ideas = response.components(separatedBy: "\n\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            return ideas
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Organizes a list of topics into meaningful groups with suggested connections
    /// - Parameters:
    ///   - topics: Array of topic names to organize
    ///   - connections: Existing connections between topics
    /// - Returns: Array of organization suggestions
    func organizeTopics(topics: [String], connections: [String]) async throws -> [String] {
        isLoading = true
        errorMessage = nil
        
        let prompt = """
        Organize these topics into meaningful groups and suggest connections:
        
        TOPICS:
        \(topics.map { "- \($0)" }.joined(separator: "\n"))
        
        EXISTING CONNECTIONS:
        \(connections.isEmpty ? "None" : connections.map { "- \($0)" }.joined(separator: "\n"))
        
        Provide your response in this format:
        
        STRUCTURE: [Brief overview of the structure]
        
        GROUP 1: [Topic1, Topic2, Topic3]
        GROUP 2: [Topic4, Topic5]
        
        CONNECTIONS: [Suggested connections between topics]
        """
        
        do {
            let response = try await callGeminiAPIAsync(with: prompt)
            
            // Parse the response into sections
            let sections = response.components(separatedBy: "\n\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            return sections
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Analyzes a mind map structure and suggests improvements
    /// - Parameter topicStructure: Description of the mind map structure
    /// - Returns: Array of analysis sections
    func analyzeStructure(topicStructure: String) async throws -> [String] {
        isLoading = true
        errorMessage = nil
        
        let prompt = """
        Analyze this mind map structure and provide feedback:
        
        \(topicStructure)
        
        Provide your analysis in this format:
        
        STRENGTHS: [Comma-separated list of strengths]
        
        IMPROVEMENTS: [Comma-separated list of potential improvements]
        
        BALANCE: [Assessment of balance and distribution]
        
        FOCUS: [Assessment of central focus and coherence]
        """
        
        do {
            let response = try await callGeminiAPIAsync(with: prompt)
            
            // Parse the response into sections
            let sections = response.components(separatedBy: "\n\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            return sections
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Generates a hierarchical topic structure asynchronously
    /// - Parameters:
    ///   - topic: The central topic
    ///   - existingTopics: Existing topics to consider
    /// - Returns: The resulting topic hierarchy
    func generateTopicHierarchy(topic: String, existingTopics: [String]) async throws -> TopicHierarchyResult {
        isLoading = true
        errorMessage = nil
        
        let prompt = createHierarchyGenerationPrompt(
            centralTopic: topic,
            topics: existingTopics.isEmpty ? [] : existingTopics
        )
        
        do {
            let response = try await callGeminiAPIAsync(with: prompt)
            let result = try parseHierarchyResponse(response)
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
        return result
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func createIdeaGenerationPrompt(
        centralTopic: String,
        existingTopics: [String],
        count: Int
    ) -> String {
        var prompt = """
        Generate \(count) creative and relevant subtopics or ideas related to the central topic: "\(centralTopic)".
        
        For each idea:
        1. Provide a concise, clear name (3-5 words maximum)
        2. Include a brief explanation of why this subtopic is relevant or important (1-2 sentences)
        
        """
        
        if !existingTopics.isEmpty {
            prompt += "\nExisting subtopics (avoid duplicating these):\n"
            existingTopics.forEach { prompt += "- \($0)\n" }
        }
        
        prompt += """
        
        Format your response as a JSON array with objects containing "name" and "reason" fields.
        Example:
        [
          {
            "name": "Subtopic Name",
            "reason": "Brief explanation of relevance"
          }
        ]
        """
        
        return prompt
    }
    
    private func createOrganizeTopicsPrompt(
        topics: [String],
        groupCount: Int
    ) -> String {
        """
        Organize the following \(topics.count) topics into \(groupCount) meaningful groups or categories:
        
        \(topics.map { "- \($0)" }.joined(separator: "\n"))
        
        For each group:
        1. Create a descriptive name that captures the common theme (3-5 words maximum)
        2. Include a brief explanation of the grouping rationale (1-2 sentences)
        3. List which original topics belong in this group
        
        Format your response as a JSON array where each group is an object with "name", "reason", and "children" fields.
        Example:
        [
          {
            "name": "Group Name",
            "reason": "Why these topics are related",
            "children": ["Topic 1", "Topic 2"]
          }
        ]
        
        Ensure every original topic is assigned to exactly one group.
        """
    }
    
    private func createStructureAnalysisPrompt(
        centralTopic: String,
        topics: [String]
    ) -> String {
        """
        Analyze the structure of this mind map with central topic: "\(centralTopic)"
        
        Current subtopics:
        \(topics.map { "- \($0)" }.joined(separator: "\n"))
        
        Please provide:
        1. A brief analysis of the current structure
        2. Suggestions for improvement
        3. Any missing important areas or topics
        4. Tips for better organization
        
        Format your response in clear paragraphs. Be specific and practical in your advice.
        """
    }
    
    private func createHierarchyGenerationPrompt(
        centralTopic: String,
        topics: [String]
    ) -> String {
        """
        Organize the following topics into a hierarchical structure for a mind map with central topic: "\(centralTopic)"
        
        Topics to organize:
        \(topics.map { "- \($0)" }.joined(separator: "\n"))
        
        Create a meaningful hierarchy by:
        1. Identifying main categories as first-level topics
        2. Organizing remaining topics as subtopics under these categories
        3. Providing a brief explanation of why each grouping makes sense
        
        Format your response as a JSON array of objects with "name", "reason", and "children" fields.
        Children should contain nested objects with the same structure.
        
        Example:
        [
          {
            "name": "Main Category 1",
            "reason": "Why this is a main category",
            "children": [
              {
                "name": "Subtopic 1",
                "reason": "Why this belongs here",
                "children": []
              }
            ]
          }
        ]
        
        Ensure all original topics are included somewhere in the hierarchy.
        """
    }
    
    private func callGeminiAPI(
        with prompt: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Fetch the current API key
        let currentApiKey = APIConfig.geminiAPIKey

        guard !currentApiKey.isEmpty && currentApiKey != "YOUR_GEMINI_API_KEY" else {
            completion(.failure(APIError.missingAPIKey))
            return
        }
        
        guard isNetworkAvailable else {
            completion(.failure(APIError.noInternetConnection))
            return
        }
        
        let model = GenerativeModel(
            name: "gemini-1.5-pro-latest",
            apiKey: currentApiKey,
            generationConfig: GenerationConfig(
                temperature: 0.7,
                topP: 0.95,
                topK: 40,
                maxOutputTokens: 2048
            )
        )
        
        Task {
            do {
                let response = try await model.generateContent(prompt)
                
                if let text = response.text {
                    completion(.success(text))
                } else {
                    completion(.failure(APIError.emptyResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func parseTopicsResponse(_ response: String) throws -> [TopicWithReason] {
        // Try to extract JSON if it's wrapped in markdown code blocks
        let jsonString: String
        if response.contains("```json") && response.contains("```") {
            let components = response.components(separatedBy: "```")
            if components.count >= 3 {
                // Find the component that starts with "json" and trim it
                for component in components {
                    if component.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "json") {
                        jsonString = component.replacingOccurrences(of: "json", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        return try parseJSONTopics(jsonString)
                    }
                }
                // If we didn't find a component starting with "json", use the second component
                jsonString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw APIError.invalidResponseFormat
            }
        } else {
            // Assume the entire response is JSON
            jsonString = response
        }
        
        return try parseJSONTopics(jsonString)
    }
    
    private func parseJSONTopics(_ jsonString: String) throws -> [TopicWithReason] {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw APIError.invalidResponseFormat
        }
        
        let decoder = JSONDecoder()
        
        // Try to parse as array of TopicWithReason directly
        do {
            return try decoder.decode([TopicWithReason].self, from: jsonData)
        } catch {
            // If that fails, try to parse the JSON for debugging
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) {
                print("Failed to parse JSON into TopicWithReason. Raw JSON: \(jsonObject)")
            }
            throw APIError.invalidResponseFormat
        }
    }
    
    private func parseHierarchyResponse(_ response: String) throws -> TopicHierarchyResult {
        let topics = try parseTopicsResponse(response)
        
        // Filter out parent topics with generic names and clean children
        var filteredTopics: [TopicWithReason] = []
        
        for var parentTopic in topics {
            // Skip entire parent topic if it has a generic name
            if isGenericTopicName(parentTopic.name) {
                continue
            }
            
            // Filter out children with generic names
            parentTopic.children = parentTopic.children.filter { !isGenericTopicName($0.name) }
            
            // Add parent topic with filtered children
            filteredTopics.append(parentTopic)
        }
        
        // Use the proper initializer with default empty string for mainIdea
        return TopicHierarchyResult(parentTopics: filteredTopics, mainIdea: "")
    }
    
    // Helper function to detect generic topic names
    private func isGenericTopicName(_ name: String) -> Bool {
        // Check if the name matches "Main Topic" followed by a number
        let nameLower = name.lowercased()
        let pattern = "main topic"
        
        // If it's only 11 characters or fewer, it's too short to be "Main Topic X"
        if nameLower.count <= 11 {
            return false
        }
        
        // Must start with "main topic"
        if !nameLower.hasPrefix(pattern) {
            return false
        }
        
        // Extract the part after "main topic"
        let index = name.index(name.startIndex, offsetBy: 10)
        let remainder = name[index...].trimmingCharacters(in: .whitespaces)
        
        // Check if the remainder is a number
        return Int(remainder) != nil
    }
    
    /// Async wrapper for calling the Gemini API
    private func callGeminiAPIAsync(with prompt: String) async throws -> String {
        // Fetch the current API key
        let currentApiKey = APIConfig.geminiAPIKey

        guard !currentApiKey.isEmpty && currentApiKey != "YOUR_GEMINI_API_KEY" else {
            throw APIError.missingAPIKey
        }
        
        guard isNetworkAvailable else {
            throw APIError.noInternetConnection
        }
        
        let model = GenerativeModel(
            name: "gemini-1.5-pro-latest",
            apiKey: currentApiKey,
            generationConfig: GenerationConfig(
                temperature: 0.7,
                topP: 0.95,
                topK: 40,
                maxOutputTokens: 2048
            )
        )
        
        let response = try await model.generateContent(prompt)
        
        if let text = response.text {
            return text
        } else {
            throw APIError.emptyResponse
        }
    }
    
    // Private property to store the system prompt
    private var systemPrompt: String = "You are an AI assistant helping with mind mapping."
}

// MARK: - Supporting Types

enum APIError: Error, LocalizedError {
    case missingAPIKey
    case noInternetConnection
    case emptyResponse
    case invalidResponseFormat
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not found. Please set a valid GEMINI_API_KEY in the environment."
        case .noInternetConnection:
            return "No internet connection available. Please check your network settings and try again."
        case .emptyResponse:
            return "Empty response received from the API."
        case .invalidResponseFormat:
            return "The API response format was invalid or couldn't be processed."
        }
    }
}

enum APIStatus {
    case unknown
    case connected
    case failed
    case noInternet
    case missingAPIKey
} 