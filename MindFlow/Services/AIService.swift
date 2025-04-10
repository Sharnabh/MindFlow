import Foundation
import SwiftUI
import Network

class AIService {
    static let shared = AIService()
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    private var currentSystemPrompt: String = ""
    
    private init() {
        // Set up network monitoring
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - AI Functions
    
    /// Generates creative ideas for mind mapping based on the current topics
    /// - Parameter topics: List of current topics in the mind map
    /// - Returns: A list of suggested new topics or connections
    func generateIdeas(from topics: [String]) async throws -> [String] {
        return try await callGeminiAPI(
            prompt: createIdeaGenerationPrompt(topics: topics),
            parseResponse: parseIdeaResponse
        )
    }
    
    /// Suggests ways to organize existing topics into a more coherent structure
    /// - Parameter topics: List of current topics and their relationships
    /// - Returns: A suggested organization structure
    func organizeTopics(topics: [String], connections: [String]) async throws -> [String] {
        return try await callGeminiAPI(
            prompt: createTopicOrganizationPrompt(topics: topics, connections: connections),
            parseResponse: parseOrganizationResponse
        )
    }
    
    /// Analyzes the current mind map structure and provides insights
    /// - Parameter topicStructure: Description of the current mind map structure
    /// - Returns: Analysis insights about the mind map
    func analyzeStructure(topicStructure: String) async throws -> [String] {
        return try await callGeminiAPI(
            prompt: createStructureAnalysisPrompt(topicStructure: topicStructure),
            parseResponse: parseAnalysisResponse
        )
    }
    
    /// Generates hierarchical topic suggestions with parent-child relationships
    /// - Parameters:
    ///   - topic: Main topic or focus area for generating the hierarchy
    ///   - existingTopics: List of existing topics to avoid duplication
    /// - Returns: A structured list of parent and child topic suggestions with rationale
    func generateTopicHierarchy(topic: String, existingTopics: [String]) async throws -> TopicHierarchyResult {
        let result = try await callGeminiAPI(
            prompt: createHierarchyGenerationPrompt(topic: topic, existingTopics: existingTopics),
            parseResponse: parseHierarchyResponse
        )
        return result
    }
    
    // MARK: - Prompt Creation
    
    private func createIdeaGenerationPrompt(topics: [String]) -> String {
        let topicsText = topics.joined(separator: "\n- ")
        
        return """
        You are a creative assistant helping a user with mind mapping. Based on the following topics already in their mind map, suggest 5 new creative and relevant topics or connections that could be added.

        CURRENT TOPICS:
        - \(topicsText)

        Please provide exactly 5 new ideas formatted as follows:
        IDEA: [Idea name]
        DESCRIPTION: [Brief 1-2 sentence description]

        Make each idea concise, creative, and directly relevant to the existing topics. Focus on connections and themes that might not be immediately obvious.
        """
    }
    
    private func createTopicOrganizationPrompt(topics: [String], connections: [String]) -> String {
        let topicsText = topics.joined(separator: "\n- ")
        let connectionsText = connections.joined(separator: "\n- ")
        
        return """
        You are an organizational expert helping structure a mind map. Analyze these topics and their connections, then suggest a more coherent, logical organization.

        CURRENT TOPICS:
        - \(topicsText)

        CURRENT CONNECTIONS:
        - \(connectionsText)

        Please provide suggestions for how to better organize these topics using the following format:
        STRUCTURE: [Main organization principle]
        GROUP 1: [Topic 1], [Topic 2], etc.
        GROUP 2: [Topic 3], [Topic 4], etc.
        CONNECTIONS: [Suggested new connections]
        
        Focus on creating logical groupings and a hierarchical structure that enhances understanding.
        """
    }
    
    private func createStructureAnalysisPrompt(topicStructure: String) -> String {
        return """
        You are a mind map analysis expert. Analyze the following mind map structure and provide meaningful insights about its organization, balance, and effectiveness.

        MIND MAP STRUCTURE:
        \(topicStructure)

        Please provide analysis in the following format:
        STRENGTHS: [List 2-3 strengths of the current structure]
        IMPROVEMENTS: [List 2-3 potential improvements]
        BALANCE: [Assessment of how balanced the mind map is]
        FOCUS: [Identified central focus or theme]
        
        Provide practical, actionable feedback that will help improve the mind map's clarity and effectiveness.
        """
    }
    
    private func createHierarchyGenerationPrompt(topic: String, existingTopics: [String]) -> String {
        let existingTopicsText = existingTopics.isEmpty ? 
            "No existing topics yet." : 
            existingTopics.joined(separator: "\n- ")
        
        return """
        You are an expert in creating structured mind maps. I need you to generate a logical hierarchy of topics on "\(topic)" with clear parent-child relationships.

        EXISTING TOPICS IN THE MIND MAP:
        - \(existingTopicsText)

        Please create 3-5 parent topics (main branches) with 2-4 child topics each. For each parent and child topic, provide a brief rationale explaining why it's important.

        Format your response EXACTLY like this:
        
        PARENT: [Parent Topic 1]
        REASON: [Brief explanation why this is an important main topic]
        CHILD: [Child Topic 1.1]
        REASON: [Why this subtopic matters]
        CHILD: [Child Topic 1.2]
        REASON: [Why this subtopic matters]
        
        PARENT: [Parent Topic 2]
        REASON: [Brief explanation why this is an important main topic]
        CHILD: [Child Topic 2.1]
        REASON: [Why this subtopic matters]
        CHILD: [Child Topic 2.2]
        REASON: [Why this subtopic matters]
        
        Focus on creating meaningful, insightful topics that together provide comprehensive coverage of "\(topic)". Ensure all suggestions are factually accurate and provide valuable structure.
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseIdeaResponse(_ response: String) -> [String] {
        // Split response by IDEA: markers and process
        var ideas = [String]()
        let components = response.components(separatedBy: "IDEA:")
        
        for component in components.dropFirst() { // Skip the first element which is before any IDEA: marker
            let lines = component.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            
            if let firstLine = lines.first {
                var ideaText = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Look for the description if available
                if let descIndex = lines.firstIndex(where: { $0.contains("DESCRIPTION:") }) {
                    let description = lines[descIndex].replacingOccurrences(of: "DESCRIPTION:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    ideaText += "\n- " + description
                }
                
                ideas.append(ideaText)
            }
        }
        
        return ideas
    }
    
    private func parseOrganizationResponse(_ response: String) -> [String] {
        // Extract the organization suggestions
        var results = [String]()
        let lines = response.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty {
                results.append(trimmedLine)
            }
        }
        
        return results
    }
    
    private func parseAnalysisResponse(_ response: String) -> [String] {
        // Extract analysis insights
        var insights = [String]()
        let sections = ["STRENGTHS:", "IMPROVEMENTS:", "BALANCE:", "FOCUS:"]
        
        for section in sections {
            if let range = response.range(of: section) {
                let startIndex = range.upperBound
                let endIndex: String.Index
                
                // Find the end of this section (start of next section or end of string)
                if let nextSection = sections.first(where: { section != $0 && response[range.upperBound...].contains($0) }) {
                    endIndex = response[startIndex...].range(of: nextSection)?.lowerBound ?? response.endIndex
                } else {
                    endIndex = response.endIndex
                }
                
                let sectionContent = response[startIndex..<endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                insights.append("\(section) \(sectionContent)")
            }
        }
        
        return insights
    }
    
    private func parseHierarchyResponse(_ response: String) -> TopicHierarchyResult {
        var result = TopicHierarchyResult()
        var currentParent: TopicWithReason? = nil
        
        let lines = response.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            if trimmedLine.hasPrefix("PARENT:") {
                // Start a new parent
                if let parent = currentParent {
                    result.parentTopics.append(parent)
                }
                
                let content = trimmedLine.replacingOccurrences(of: "PARENT:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                currentParent = TopicWithReason(name: content, reason: "")
            } else if trimmedLine.hasPrefix("REASON:") && currentParent != nil {
                let reason = trimmedLine.replacingOccurrences(of: "REASON:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if currentParent!.reason.isEmpty {
                    // This is for the parent
                    currentParent!.reason = reason
                } else {
                    // This is for the most recent child
                    if var lastChild = currentParent?.children.popLast() {
                        lastChild.reason = reason
                        currentParent?.children.append(lastChild)
                    }
                }
            } else if trimmedLine.hasPrefix("CHILD:") && currentParent != nil {
                let childContent = trimmedLine.replacingOccurrences(of: "CHILD:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                currentParent!.children.append(TopicWithReason(name: childContent, reason: ""))
            }
        }
        
        // Add the last parent if it exists
        if let parent = currentParent, !parent.name.isEmpty {
            result.parentTopics.append(parent)
        }
        
        return result
    }
    
    // MARK: - Gemini API Integration
    
    /// Generic function to call Gemini API with a prompt and parse response
    private func callGeminiAPI<T>(prompt: String, parseResponse: @escaping (String) -> T) async throws -> T {
        // Check network connectivity first
        guard isNetworkAvailable else {
            throw NSError(
                domain: "AIService",
                code: -1009, // NSURLErrorNotConnectedToInternet
                userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your network settings and try again."]
            )
        }
        
        // Get API key from config - reusing the same API key setup
        let apiKey = APIConfig.geminiAPIKey
        
        // Check if the API key is valid
        guard !apiKey.contains("YOUR_") else {
            throw NSError(domain: "AIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not configured. Please add your Gemini API key in settings."])
        }
        
        // Gemini API endpoint - using the same model as in GenrePredictionService
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!
        
        // Construct a URL with the API key as a query parameter
        var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        // Create the request with timeout
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20 // Increase timeout slightly
        
        // Create the request body according to the current API format
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": currentSystemPrompt.isEmpty ? prompt : "\(currentSystemPrompt)\n\n\(prompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 800,
                "topP": 0.95,
                "topK": 40
            ],
            "safetySettings": [
                [
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_HATE_SPEECH",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                    "threshold": "BLOCK_NONE"
                ]
            ]
        ]
        
        // Convert the request body to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        do {
            // Use a custom URLSession with better timeout handling
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 20
            sessionConfig.timeoutIntervalForResource = 40
            sessionConfig.waitsForConnectivity = true
            sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: sessionConfig)
            
            // Print full URL for debugging
            print("Making request to: \(url.absoluteString)")
            
            // Send the request with explicit timeout handling
            let (data, response) = try await session.data(for: request)
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Gemini API response: \(responseString)")
            }
            
            // Check for valid HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            // Check for successful response code
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message if available
                let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = errorResponse?["error"] as? [String: Any]
                let message = errorMessage?["message"] as? String ?? "Status code: \(httpResponse.statusCode)"
                
                throw NSError(
                    domain: "AIService", 
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "API Error: \(message)"]
                )
            }
            
            // Parse the response using the current API structure
            let responseObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Extract the text response from the API format
            if let candidates = responseObject?["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                
                // Clean up the response
                let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Parse the response using the provided parser
                return parseResponse(cleanedText)
            }
            
            // If we couldn't parse the response at all
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini API response"])
            
        } catch let urlError as URLError {
            var localizedError = "Unknown network error occurred"
            var errorCode = urlError.code.rawValue
            
            switch urlError.code {
            case .timedOut:
                localizedError = "Request timed out. Please check your internet connection and try again."
                errorCode = -1001
            case .notConnectedToInternet:
                localizedError = "No internet connection. Please check your network settings and try again."
                errorCode = -1009
            case .cannotFindHost, .dnsLookupFailed:
                localizedError = "Unable to connect to Google's servers. Please check your internet connection and try again."
                errorCode = -1003
            case .cannotConnectToHost:
                localizedError = "Cannot connect to Google's servers. Please try again later."
                errorCode = -1004
            case .secureConnectionFailed:
                localizedError = "Secure connection to API failed. Please try again later."
                errorCode = -1200
            default:
                localizedError = "Network error: \(urlError.localizedDescription)"
            }
            
            print("Network error details: \(urlError)")
            
            throw NSError(
                domain: "AIService",
                code: errorCode,
                userInfo: [NSLocalizedDescriptionKey: localizedError]
            )
        } catch let error as NSError {
            print("Gemini API error: \(error)")
            throw error
        } catch {
            print("Unexpected error: \(error)")
            throw NSError(
                domain: "AIService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "An unexpected error occurred: \(error.localizedDescription)"]
            )
        }
    }
    
    // MARK: - Test API Connection
    
    /// Tests the API connection with the current key
    func testAPIConnection() async -> Result<String, Error> {
        // Simple test prompt
        let testPrompt = "Respond with 'Connection successful' if you can read this message."
        
        do {
            // Make a simple request
            let response = try await callGeminiAPI(prompt: testPrompt) { response in
                return response
            }
            return .success("Connection successful: \(response.prefix(30))...")
        } catch {
            return .failure(error)
        }
    }
    
    // Add updateSystemPrompt method
    func updateSystemPrompt(_ prompt: String) {
        currentSystemPrompt = prompt
    }
}

// MARK: - Topic Hierarchy Models

/// Model for topic suggestions with reasoning
struct TopicWithReason: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var reason: String
    var children: [TopicWithReason] = []
    var isSelected: Bool = false
    
    // Conformance to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TopicWithReason, rhs: TopicWithReason) -> Bool {
        lhs.id == rhs.id
    }
}

/// Result structure for topic hierarchy generation
struct TopicHierarchyResult {
    var parentTopics: [TopicWithReason] = []
} 