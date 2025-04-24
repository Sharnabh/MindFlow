import Foundation

/// Types of messages that can be sent over WebSocket
enum MessageType: String, Codable {
    case connectionEstablished
    case topicChange
    case userJoined
    case userLeft
    case error
}

/// Represents a collaborator in a collaborative document session
struct Collaborator: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let photoURL: URL?
    let color: String // Color for cursor/selection
    let lastActive: Date
    
    static func == (lhs: Collaborator, rhs: Collaborator) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Represents a collaborative document session
struct CollaborativeSession: Codable {
    let documentId: String
    let creatorId: String
    let title: String
    let createdAt: Date
    let lastModified: Date
    let collaborators: [String] // User IDs of collaborators
    let activeUsers: [String] // Currently active users
    let accessLevel: DocumentAccessLevel
    let shareLink: String?
}

/// Document access permissions
enum DocumentAccessLevel: String, Codable {
    case viewOnly
    case comment
    case edit
    case owner
}

/// Represents a change to a topic
struct TopicChange: Codable, Identifiable {
    let id: String
    let topicId: String
    let userId: String
    let timestamp: Date
    let changeType: ChangeType
    let properties: [String: AnyCodable]
    let version: Int
    
    init(topicId: String, userId: String, changeType: ChangeType, properties: [String: Any], version: Int) {
        self.id = UUID().uuidString
        self.topicId = topicId
        self.userId = userId
        self.timestamp = Date()
        self.changeType = changeType
        self.properties = properties.mapValues { AnyCodable($0) }
        self.version = version
    }
    
    enum ChangeType: String, Codable {
        case create
        case update
        case delete
        case move
        case connect
        case disconnect
    }
}

/// Manages change sets for batched operations
struct ChangeSet: Codable, Identifiable {
    let id: String
    let documentId: String
    let userId: String
    let timestamp: Date
    let baseVersion: Int
    let changes: [TopicChange]
    
    init(documentId: String, userId: String, baseVersion: Int, changes: [TopicChange]) {
        self.id = UUID().uuidString
        self.documentId = documentId
        self.userId = userId
        self.timestamp = Date()
        self.baseVersion = baseVersion
        self.changes = changes
    }
}

/// WebSocket message structure with proper Codable implementation
struct CollaborationMessage: Codable {
    let type: MessageType
    let senderId: String
    let timestamp: Date
    let payload: AnyCodable
    
    init(type: MessageType, senderId: String, timestamp: Date, payload: Any) {
        self.type = type
        self.senderId = senderId
        self.timestamp = timestamp
        self.payload = AnyCodable(payload)
    }
}

/// A type-erasing wrapper for Codable that can handle Any values
struct AnyCodable: Codable {
    private let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable cannot decode value"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let date as Date:
            try container.encode(ISO8601DateFormatter().string(from: date))
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable cannot encode value of type \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
    
    var unwrapped: Any {
        return value
    }
} 