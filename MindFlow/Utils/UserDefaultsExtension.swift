import Foundation

// Keys for UserDefaults
enum UserDefaultsKeys {
    static let recentFiles = "recentFiles"
    static let trashedFiles = "trashedFiles"
}

// Extensions for handling recent files and trash in UserDefaults
extension UserDefaults {
    
    // Recent file structure for storage
    struct StoredRecentFile: Codable {
        let name: String
        let date: Date
        let urlString: String
    }
    
    // Save recent files
    func saveRecentFiles(_ files: [StartupScreenView.RecentFile]) {
        let storedFiles = files.map { file -> StoredRecentFile in
            return StoredRecentFile(
                name: file.name,
                date: file.date,
                urlString: file.url.absoluteString
            )
        }
        
        if let encoded = try? JSONEncoder().encode(storedFiles) {
            UserDefaults.standard.set(encoded, forKey: UserDefaultsKeys.recentFiles)
        }
    }
    
    // Load recent files
    func loadRecentFiles() -> [StartupScreenView.RecentFile] {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.recentFiles),
              let storedFiles = try? JSONDecoder().decode([StoredRecentFile].self, from: data) else {
            return []
        }
        
        return storedFiles.compactMap { storedFile -> StartupScreenView.RecentFile? in
            guard let url = URL(string: storedFile.urlString) else { return nil }
            return StartupScreenView.RecentFile(
                name: storedFile.name,
                date: storedFile.date,
                url: url
            )
        }
    }
    
    // Save trashed files
    func saveTrashedFiles(_ files: [StartupScreenView.RecentFile]) {
        let storedFiles = files.map { file -> StoredRecentFile in
            return StoredRecentFile(
                name: file.name,
                date: file.date,
                urlString: file.url.absoluteString
            )
        }
        
        if let encoded = try? JSONEncoder().encode(storedFiles) {
            UserDefaults.standard.set(encoded, forKey: UserDefaultsKeys.trashedFiles)
        }
    }
    
    // Load trashed files
    func loadTrashedFiles() -> [StartupScreenView.RecentFile] {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.trashedFiles),
              let storedFiles = try? JSONDecoder().decode([StoredRecentFile].self, from: data) else {
            return []
        }
        
        return storedFiles.compactMap { storedFile -> StartupScreenView.RecentFile? in
            guard let url = URL(string: storedFile.urlString) else { return nil }
            return StartupScreenView.RecentFile(
                name: storedFile.name,
                date: storedFile.date,
                url: url
            )
        }
    }
    
    // Add a file to recent files
    func addToRecentFiles(_ file: StartupScreenView.RecentFile) {
        var recentFiles = loadRecentFiles()
        
        // Remove the file if it already exists
        recentFiles.removeAll { $0.url.absoluteString == file.url.absoluteString }
        
        // Add the file to the beginning
        recentFiles.insert(file, at: 0)
        
        // Keep only the last 10 files
        if recentFiles.count > 10 {
            recentFiles = Array(recentFiles.prefix(10))
        }
        
        saveRecentFiles(recentFiles)
    }
    
    // Move a file to trash
    func moveFileToTrash(_ file: StartupScreenView.RecentFile) {
        var recentFiles = loadRecentFiles()
        var trashedFiles = loadTrashedFiles()
        
        // Remove from recent files
        recentFiles.removeAll { $0.url.absoluteString == file.url.absoluteString }
        
        // Add to trashed files
        trashedFiles.insert(file, at: 0)
        
        saveRecentFiles(recentFiles)
        saveTrashedFiles(trashedFiles)
    }
    
    // Restore a file from trash
    func restoreFileFromTrash(_ file: StartupScreenView.RecentFile) {
        var recentFiles = loadRecentFiles()
        var trashedFiles = loadTrashedFiles()
        
        // Remove from trashed files
        trashedFiles.removeAll { $0.url.absoluteString == file.url.absoluteString }
        
        // Add to recent files
        recentFiles.insert(file, at: 0)
        
        saveRecentFiles(recentFiles)
        saveTrashedFiles(trashedFiles)
    }
    
    // Delete a file from trash
    func deleteFileFromTrash(_ file: StartupScreenView.RecentFile) {
        var trashedFiles = loadTrashedFiles()
        
        // Remove from trashed files
        trashedFiles.removeAll { $0.url.absoluteString == file.url.absoluteString }
        
        saveTrashedFiles(trashedFiles)
    }
    
    // Empty trash
    func emptyTrash() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.trashedFiles)
    }
} 