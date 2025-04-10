import Foundation

class GenrePredictionService {
    static let shared = GenrePredictionService()
    
    private init() {}
    
    struct BookPrediction {
        let genre: String
        let publicationYear: String
        let isbn: String
        let author: String
    }
    
    /// Predicts the most likely genre and other book details based on its metadata using Gemini API
    /// - Parameters:
    ///   - title: Book title
    ///   - description: Book description
    ///   - authors: Book authors
    ///   - availableGenres: List of available genres to choose from
    /// - Returns: The predicted book details including genre, publication year, ISBN, and author
    func predictGenre(title: String, description: String?, authors: [String], availableGenres: [String]) async throws -> BookPrediction {
        // Get the predictions from Gemini
        return try await predictBookDetailsWithGemini(
            title: title,
            description: description,
            authors: authors,
            availableGenres: availableGenres
        )
    }
    
    /// Predicts book details using Google's Gemini API
    private func predictBookDetailsWithGemini(title: String, description: String?, authors: [String], availableGenres: [String]) async throws -> BookPrediction {
        // Gemini API endpoint - updated to use the current supported version and model
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!
        
        // Get API key from config
        let apiKey = APIConfig.geminiAPIKey
        
        // Check if the API key is valid
        guard !apiKey.contains("YOUR_") else {
            throw NSError(domain: "GenrePredictionService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }
        
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
        request.timeoutInterval = 15 // Set a reasonable timeout
        
        // Format the available genres as a comma-separated list
        let genreOptions = availableGenres.joined(separator: ", ")
        
        // Prepare the author string
        let authorText = authors.isEmpty ? "[UNKNOWN]" : authors.joined(separator: ", ")
        
        // Prepare the description
        let descriptionText = description ?? "No description available"
        
        // Enhanced prompt to predict multiple book details
        let prompt = """
        You are a literary expert tasked with determining book details based on limited information.
        
        Book Information:
        - Title: "\(title)"
        - Author(s): \(authorText)
        - Description: \(descriptionText)
        
        Using your knowledge of books, authors, and publishing, please provide the following information in the exact format specified:
        
        1. GENRE: Select the most appropriate genre from this list: \(genreOptions)
        2. YEAR: Estimate the most likely publication year (4-digit year only)
        3. AUTHOR: If author is unknown, suggest the most likely author's full name
        
        Format your response EXACTLY like this example:
        GENRE: Fiction
        YEAR: 2019
        AUTHOR: Jane Smith
        
        Your response should contain ONLY these three lines with no additional text or explanations.
        """
        
        // Create the request body according to the current API format
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 100,
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
            sessionConfig.timeoutIntervalForRequest = 15
            sessionConfig.timeoutIntervalForResource = 30
            let session = URLSession(configuration: sessionConfig)
            
            // Send the request with explicit timeout handling
            let (data, response) = try await session.data(for: request)
            
            // Print the raw response for debugging
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
                    domain: "GenrePredictionService", 
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "API Error: \(message)"]
                )
            }
            
            // Parse the response using the current API structure
            let responseObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Extract the text response from the updated API format
            if let candidates = responseObject?["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                
                // Clean up the response
                let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Parse the response into structured data
                var genre = ""
                var year = ""
                var author = ""
                
                // Split by lines and extract each piece of information
                let lines = cleanedText.components(separatedBy: .newlines)
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if trimmedLine.hasPrefix("GENRE:") {
                        let extractedGenre = trimmedLine.replacingOccurrences(of: "GENRE:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        genre = extractedGenre
                    } else if trimmedLine.hasPrefix("YEAR:") {
                        let extractedYear = trimmedLine.replacingOccurrences(of: "YEAR:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        year = extractedYear
                    } else if trimmedLine.hasPrefix("AUTHOR:") {
                        let extractedAuthor = trimmedLine.replacingOccurrences(of: "AUTHOR:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        author = extractedAuthor
                    }
                }
                
                // Process the genre to match available genres
                var matchedGenre = genre
                let genreLowercase = genre.lowercased()
                
                // Check for exact match in available genres
                for availableGenre in availableGenres {
                    if genreLowercase == availableGenre.lowercased() {
                        matchedGenre = availableGenre // Use the correctly cased version
                        break
                    }
                }
                
                // If no exact match, try partial match
                if matchedGenre == genre {
                    for availableGenre in availableGenres {
                        if genreLowercase.contains(availableGenre.lowercased()) || 
                           availableGenre.lowercased().contains(genreLowercase) {
                            matchedGenre = availableGenre
                            break
                        }
                    }
                }
                
                // If still no match, use default genre
                if !availableGenres.contains(where: { $0.lowercased() == matchedGenre.lowercased() }) {
                    if availableGenres.contains("Fiction") {
                        matchedGenre = "Fiction"
                    } else if availableGenres.contains("Non-Fiction") {
                        matchedGenre = "Non-Fiction"
                    } else {
                        matchedGenre = availableGenres.first ?? "Uncategorized"
                    }
                }
                
                print("✅ Gemini predictions - Genre: \(matchedGenre), Year: \(year), Author: \(author)")
                
                return BookPrediction(
                    genre: matchedGenre,
                    publicationYear: year,
                    isbn: "", // Return empty string for ISBN since we're not predicting it
                    author: author
                )
            }
            
            // If we couldn't parse the response at all
            throw NSError(domain: "GenrePredictionService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini API response"])
            
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw NSError(domain: "GenrePredictionService", code: 408, 
                              userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please check your internet connection."])
            } else if urlError.code == .notConnectedToInternet {
                throw NSError(domain: "GenrePredictionService", code: 503, 
                              userInfo: [NSLocalizedDescriptionKey: "No internet connection available. Please check your connection."])
            }
            throw urlError
        } catch {
            throw error
        }
    }
} 
