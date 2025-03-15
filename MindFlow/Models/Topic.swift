import Foundation

struct Topic: Identifiable, Equatable {
    enum Shape {
        case rectangle
        case roundedRectangle
        case circle
        case roundedSquare
        case line
        case diamond
        case hexagon
        case octagon
        case parallelogram
        case cloud
        case heart
        case shield
        case star
        case document
        case doubleRectangle
        case flag
        case leftArrow
        case rightArrow
    }
    
    let id: UUID
    var name: String
    var position: CGPoint
    var parentId: UUID?
    var subtopics: [Topic]
    var isSelected: Bool
    var isEditing: Bool
    var relations: [Topic]
    var shape: Shape
    
    init(
        id: UUID = UUID(),
        name: String,
        position: CGPoint,
        parentId: UUID? = nil,
        subtopics: [Topic] = [],
        isSelected: Bool = false,
        isEditing: Bool = false,
        relations: [Topic] = [],
        shape: Shape = .roundedRectangle
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.parentId = parentId
        self.subtopics = subtopics
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.relations = relations
        self.shape = shape
    }
    
    // Implement Equatable
    static func == (lhs: Topic, rhs: Topic) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.position == rhs.position &&
        lhs.parentId == rhs.parentId &&
        lhs.subtopics == rhs.subtopics &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isEditing == rhs.isEditing &&
        lhs.relations == rhs.relations &&
        lhs.shape == rhs.shape
    }
}

extension Topic {
    static func createMainTopic(at position: CGPoint, count: Int) -> Topic {
        Topic(
            name: "Main Topic \(count)",
            position: position
        )
    }
    
    func createSubtopic(at position: CGPoint, count: Int) -> Topic {
        Topic(
            name: "Subtopic \(count)",
            position: position,
            parentId: self.id
        )
    }
    
    mutating func addRelation(_ topic: Topic) {
        // Don't add if it's already a relation or if it's self
        if !relations.contains(where: { $0.id == topic.id }) && topic.id != self.id {
            relations.append(topic)
        }
    }
    
    mutating func removeRelation(_ topicId: UUID) {
        relations.removeAll(where: { $0.id == topicId })
    }
} 