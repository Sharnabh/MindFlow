import SwiftUI

// Models for AI-related functionality

// Represents a topic with reason in AI-generated hierarchies
struct TopicWithReason: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var reason: String
    var children: [TopicWithReason]
    var isSelected: Bool = true
    
    // Algorithm flowchart specific fields
    var shape: String? = nil
    var connectionType: String? = nil
    
    // Add CodingKeys for encoding/decoding
    enum CodingKeys: String, CodingKey {
        case name, reason, children, shape, connectionType
        // Note: 'id' and 'isSelected' are not included in CodingKeys
        // because they're not part of the JSON from the API
    }
    
    // Custom decoder implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Generate a new UUID for each decoded object
        self.id = UUID()
        
        // Decode the required fields with null handling
        let rawName = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.name = rawName == "<null>" ? "" : rawName
        
        let rawReason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        self.reason = rawReason == "<null>" ? "" : rawReason
        
        // Children is optional in the API response
        if container.contains(.children) {
            let allChildren = try container.decode([TopicWithReason].self, forKey: .children)
            // Filter out children with empty names (from <null> values)
            self.children = allChildren.filter { !$0.name.isEmpty }
        } else {
            self.children = []
        }
        
        // Algorithm flowchart fields are optional with null handling
        let rawShape = try container.decodeIfPresent(String.self, forKey: .shape)
        self.shape = (rawShape == nil || rawShape == "<null>") ? nil : rawShape
        
        let rawConnectionType = try container.decodeIfPresent(String.self, forKey: .connectionType)
        self.connectionType = (rawConnectionType == nil || rawConnectionType == "<null>") ? nil : rawConnectionType
        
        // Set default value for isSelected
        self.isSelected = true
    }
    
    // Regular initializer for creating instances in code
    init(id: UUID = UUID(), name: String, reason: String, children: [TopicWithReason] = [], isSelected: Bool = true, shape: String? = nil, connectionType: String? = nil) {
        self.id = id
        self.name = name
        self.reason = reason
        self.children = children
        self.isSelected = isSelected
        self.shape = shape
        self.connectionType = connectionType
    }
    
    // Add equality function for Hashable compliance
    static func == (lhs: TopicWithReason, rhs: TopicWithReason) -> Bool {
        lhs.id == rhs.id
    }
    
    // Add hash method for Hashable compliance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func placeholder() -> TopicWithReason {
        return TopicWithReason(
            name: "Sample Topic",
            reason: "This is an example topic",
            children: [
                TopicWithReason(
                    name: "Subtopic 1",
                    reason: "A sample subtopic",
                    children: []
                ),
                TopicWithReason(
                    name: "Subtopic 2",
                    reason: "Another sample subtopic",
                    children: []
                )
            ]
        )
    }
}

// Result from AI-generated topic hierarchy
struct TopicHierarchyResult {
    var parentTopics: [TopicWithReason]
    var mainIdea: String
    
    // Add initializer with default values
    init(parentTopics: [TopicWithReason] = [], mainIdea: String = "") {
        self.parentTopics = parentTopics
        self.mainIdea = mainIdea
    }
} 