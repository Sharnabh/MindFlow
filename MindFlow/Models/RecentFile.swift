import Foundation

/// Represents a recently opened MindFlow document file
/// Used for tracking recent files, trash management, and file restoration
struct RecentFile: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let date: Date
    let url: URL
    
    // MARK: - Computed Properties
    
    /// File extension (e.g., "mindflow", "json")
    var fileExtension: String {
        return url.pathExtension.lowercased()
    }
    
    /// File name without extension
    var displayName: String {
        return url.deletingPathExtension().lastPathComponent
    }
    
    /// File size in bytes (if accessible)
    var fileSize: Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    /// Whether the file still exists at the URL
    var fileExists: Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Relative date string (e.g., "2 hours ago", "Yesterday")
    var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Initializers
    
    init(name: String, date: Date, url: URL) {
        self.name = name
        self.date = date
        self.url = url
    }
    
    /// Convenience initializer from URL
    init(url: URL) {
        self.name = url.lastPathComponent
        self.date = Date()
        self.url = url
    }
    
    /// Convenience initializer with current date
    init(name: String, url: URL) {
        self.name = name
        self.date = Date()
        self.url = url
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case name, date, url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        url = try container.decode(URL.self, forKey: .url)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(date, forKey: .date)
        try container.encode(url, forKey: .url)
    }
    
    // MARK: - Equatable & Hashable Implementation
    
    static func == (lhs: RecentFile, rhs: RecentFile) -> Bool {
        return lhs.url.absoluteString == rhs.url.absoluteString
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.absoluteString)
    }
    
    // MARK: - File Operations
    
    /// Updates the access date to the current time
    func updatedAccess() -> RecentFile {
        return RecentFile(name: name, date: Date(), url: url)
    }
    
    /// Creates a copy with a new name
    func renamed(to newName: String) -> RecentFile {
        return RecentFile(name: newName, date: date, url: url)
    }
    
    /// Validates that the file exists and is accessible
    func validate() -> Bool {
        return fileExists && FileManager.default.isReadableFile(atPath: url.path)
    }
}
