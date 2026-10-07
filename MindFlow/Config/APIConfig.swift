import Foundation
import Security

/// Configuration class for API keys and other API-related settings using macOS Keychain
class APIConfig {
    private static let keychainService = "com.sharnabhB.MindFlow"
    private static let keychainAccount = "GeminiAPIKey"
    
    /// The API key for Google's Gemini AI service
    /// Get a key from: https://ai.google.dev/ (sign in and create an API key)
    static var geminiAPIKey: String {
        // 1. Check environment variables first (useful for development & testing)
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // 2. Read securely from macOS Keychain
        if let keychainKey = loadFromKeychain(), !keychainKey.isEmpty {
            return keychainKey
        }
        
        // 3. One-time migration: check legacy UserDefaults, migrate to Keychain, and clean up
        if let legacyKey = UserDefaults.standard.string(forKey: "GeminiAPIKey"), !legacyKey.isEmpty {
            saveGeminiAPIKey(legacyKey)
            UserDefaults.standard.removeObject(forKey: "GeminiAPIKey")
            return legacyKey
        }
        
        // Return placeholder if not yet configured
        return "YOUR_GEMINI_API_KEY"
    }
    
    /// Save a Gemini API key securely to macOS Keychain
    static func saveGeminiAPIKey(_ key: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            deleteGeminiAPIKey()
            return
        }
        
        guard let data = trimmedKey.data(using: .utf8) else { return }
        
        // Delete any existing keychain entry first
        deleteFromKeychain()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(query as CFDictionary, nil)
        
        // Clean up legacy plaintext storage in UserDefaults
        UserDefaults.standard.removeObject(forKey: "GeminiAPIKey")
    }
    
    /// Delete the API key from Keychain and UserDefaults
    static func deleteGeminiAPIKey() {
        deleteFromKeychain()
        UserDefaults.standard.removeObject(forKey: "GeminiAPIKey")
    }
    
    // MARK: - Private Keychain Helpers
    
    private static func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private static func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}