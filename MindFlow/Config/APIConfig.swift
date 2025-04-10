import Foundation

/// Configuration class for API keys and other API-related settings
class APIConfig {
    /// The API key for Google's Gemini AI service
    /// Get a key from: https://ai.google.dev/ (sign in and create an API key)
    static var geminiAPIKey: String {
        // First try to get from environment variables or user defaults for development
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            return envKey
        }
        
        if let savedKey = UserDefaults.standard.string(forKey: "GeminiAPIKey"), !savedKey.isEmpty {
            return savedKey
        }
        
        // Return placeholder - this will need to be replaced with a real key
        return "YOUR_GEMINI_API_KEY"
    }
    
    /// Save a Gemini API key to user defaults
    static func saveGeminiAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "GeminiAPIKey")
    }
} 