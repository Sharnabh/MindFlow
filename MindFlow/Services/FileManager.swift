import Foundation
import SwiftUI
import UniformTypeIdentifiers

class MindFlowFileManager {
    static let shared = MindFlowFileManager()
    
    private var currentURL: URL?
    
    private init() {}
    
    func saveCurrentFile(topics: [Topic], completion: @escaping (Bool, String?) -> Void) {
        // If we have a current file URL, save to it
        if let fileURL = currentURL {
            saveFile(topics: topics, to: fileURL, completion: completion)
        } else {
            // Otherwise, prompt for a save location
            saveFileAs(topics: topics, completion: completion)
        }
    }
    
    func saveFileAs(topics: [Topic], completion: @escaping (Bool, String?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = true
        savePanel.title = "Save Mind Map"
        savePanel.nameFieldStringValue = "Untitled"
        savePanel.allowedContentTypes = [UTType.mindFlowType]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                self.currentURL = url
                self.saveFile(topics: topics, to: url, completion: completion)
            } else {
                completion(false, "Save operation cancelled")
            }
        }
    }
    
    private func saveFile(topics: [Topic], to url: URL, completion: @escaping (Bool, String?) -> Void) {
        do {
            // Create the file content with our custom format
            print("Attempting to encode \(topics.count) topics")
            
            // Try each topic individually to find the problematic one
            for (index, topic) in topics.enumerated() {
                do {
                    let encoder = JSONEncoder()
                    _ = try encoder.encode(topic)
                } catch {
                    print("Error encoding topic at index \(index): \(error.localizedDescription)")
                    completion(false, "Error encoding topic at index \(index): \(error.localizedDescription)")
                    return
                }
            }
            
            let fileData = try encodeTopics(topics)
            
            // Write the data to the file
            try fileData.write(to: url)
            
            // Update the current URL
            self.currentURL = url
            
            // Call the completion handler
            completion(true, nil)
        } catch {
            print("Failed to save file: \(error)")
            completion(false, "Failed to save file: \(error.localizedDescription)")
        }
    }
    
    func loadFile(completion: @escaping ([Topic]?, String?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Open Mind Map"
        openPanel.allowedContentTypes = [UTType.mindFlowType]
        
        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                self.loadFile(from: url, completion: completion)
            } else {
                completion(nil, "Open operation cancelled")
            }
        }
    }
    
    func loadFile(from url: URL, completion: @escaping ([Topic]?, String?) -> Void) {
        do {
            // Read the file data
            let fileData = try Data(contentsOf: url)
            
            // Decode the topics
            let topics = try decodeTopics(from: fileData)
            
            // Update the current URL
            self.currentURL = url
            
            // Call the completion handler
            completion(topics, nil)
        } catch {
            completion(nil, "Failed to load file: \(error.localizedDescription)")
        }
    }
    
    func newFile() {
        // Clear the current URL so the next save will prompt for location
        currentURL = nil
    }
    
    // MARK: - Data Encoding/Decoding
    
    private func encodeTopics(_ topics: [Topic]) throws -> Data {
        // Create a deep copy without relations to prevent circular references
        let topicsForEncoding = topics.map { topic -> Topic in
            var topicCopy = topic.deepCopy()
            topicCopy.relations = [] // Clear relations to prevent circular references
            return topicCopy
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let topicData = try encoder.encode(topicsForEncoding)
        return topicData
    }
    
    private func decodeTopics(from data: Data) throws -> [Topic] {
        let decoder = JSONDecoder()
        let topics = try decoder.decode([Topic].self, from: data)
        return topics
    }
}

// Extension to define the UTType for MindFlow files
extension UTType {
    static var mindFlowType: UTType {
        // Use a direct file extension approach for better compatibility
        UTType(filenameExtension: "mindflow", conformingTo: .data)!
    }
}

// MARK: - Codable Helpers

// Helper struct to encode/decode Color
struct ColorComponents: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
}

// Helper extension to convert Color to ColorComponents
extension Color {
    func toComponents() -> ColorComponents {
        let nsColor = NSColor(self)
        
        // Convert to RGB colorspace first to handle catalog colors
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            // Fallback to default values if conversion fails
            return ColorComponents(red: 0, green: 0, blue: 0, opacity: 1)
        }
        
        return ColorComponents(
            red: Double(rgbColor.redComponent),
            green: Double(rgbColor.greenComponent),
            blue: Double(rgbColor.blueComponent),
            opacity: Double(rgbColor.alphaComponent)
        )
    }
}

// MARK: - Codable Extensions for Topic
extension Topic: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, positionX, positionY, parentId, subtopics, shape, backgroundColor, backgroundOpacity, 
             borderColor, borderOpacity, borderWidth, branchStyle, font, fontSize, fontWeight, 
             foregroundColor, foregroundOpacity, textStyles, textCase, textAlignment, isCollapsed
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        let x = try container.decode(CGFloat.self, forKey: .positionX)
        let y = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: x, y: y)
        
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        subtopics = try container.decode([Topic].self, forKey: .subtopics)
        
        // Not encoding these transient properties
        isSelected = false
        isEditing = false
        relations = []
        
        shape = try container.decode(Shape.self, forKey: .shape)
        
        // Decode colors using their components
        let bgColor = try container.decode(ColorComponents.self, forKey: .backgroundColor)
        backgroundColor = Color(red: bgColor.red, green: bgColor.green, blue: bgColor.blue, opacity: bgColor.opacity)
        
        backgroundOpacity = try container.decode(Double.self, forKey: .backgroundOpacity)
        
        let bColor = try container.decode(ColorComponents.self, forKey: .borderColor)
        borderColor = Color(red: bColor.red, green: bColor.green, blue: bColor.blue, opacity: bColor.opacity)
        
        borderOpacity = try container.decode(Double.self, forKey: .borderOpacity)
        
        // Decode BorderWidth using its raw Double value
        let borderWidthValue = try container.decode(Double.self, forKey: .borderWidth)
        if let borderWidth = BorderWidth(rawValue: borderWidthValue) {
            self.borderWidth = borderWidth
        } else {
            self.borderWidth = .medium // Default value if not found
        }
        
        // Decode BranchStyle using its raw String value
        let branchStyleValue = try container.decode(String.self, forKey: .branchStyle)
        if let branchStyle = BranchStyle(rawValue: branchStyleValue) {
            self.branchStyle = branchStyle
        } else {
            self.branchStyle = .default // Default value if not found
        }
        
        font = try container.decode(String.self, forKey: .font)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        
        // Decode font weight as integer and convert
        let weightRawValue = try container.decode(Int.self, forKey: .fontWeight)
        fontWeight = Font.Weight.fromRawValue(weightRawValue)
        
        let fgColor = try container.decode(ColorComponents.self, forKey: .foregroundColor)
        foregroundColor = Color(red: fgColor.red, green: fgColor.green, blue: fgColor.blue, opacity: fgColor.opacity)
        
        foregroundOpacity = try container.decode(Double.self, forKey: .foregroundOpacity)
        
        let textStyleIndices = try container.decode([Int].self, forKey: .textStyles)
        textStyles = Set(textStyleIndices.compactMap { TextStyle.fromRawValue($0) })
        
        let textCaseValue = try container.decode(Int.self, forKey: .textCase)
        textCase = TextCase.fromRawValue(textCaseValue)
        
        let textAlignmentValue = try container.decode(Int.self, forKey: .textAlignment)
        textAlignment = TextAlignment.fromRawValue(textAlignmentValue)
        
        isCollapsed = try container.decode(Bool.self, forKey: .isCollapsed)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        
        // Encode CGPoint as separate components with unique keys
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(subtopics, forKey: .subtopics)
        
        // We don't encode relations since they're a potential source of circular references
        
        try container.encode(shape, forKey: .shape)
        
        // Encode Color as components
        let bgColor = backgroundColor.toComponents()
        try container.encode(bgColor, forKey: .backgroundColor)
        
        try container.encode(backgroundOpacity, forKey: .backgroundOpacity)
        
        let bColor = borderColor.toComponents()
        try container.encode(bColor, forKey: .borderColor)
        
        try container.encode(borderOpacity, forKey: .borderOpacity)
        
        // Encode BorderWidth using its raw Double value
        try container.encode(borderWidth.rawValue, forKey: .borderWidth)
        
        // Encode BranchStyle using its raw String value
        try container.encode(branchStyle.rawValue, forKey: .branchStyle)
        
        try container.encode(font, forKey: .font)
        try container.encode(fontSize, forKey: .fontSize)
        
        // Encode font weight as integer
        try container.encode(fontWeight.rawValue, forKey: .fontWeight)
        
        let fgColor = foregroundColor.toComponents()
        try container.encode(fgColor, forKey: .foregroundColor)
        
        try container.encode(foregroundOpacity, forKey: .foregroundOpacity)
        
        // Encode text styles as array of integers
        let textStyleIndices = textStyles.map { $0.rawValue }
        try container.encode(textStyleIndices, forKey: .textStyles)
        
        try container.encode(textCase.rawValue, forKey: .textCase)
        try container.encode(textAlignment.rawValue, forKey: .textAlignment)
        
        try container.encode(isCollapsed, forKey: .isCollapsed)
    }
}

// MARK: - Enum Codable Extensions

// BorderWidth and BranchStyle should already be Codable
// because they have RawRepresentable conformance

// MARK: - Other Extensions

extension TextStyle: Codable {
    enum CodingKeys: CodingKey {
        case rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        guard let style = TextStyle.fromRawValue(rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid text style raw value")
        }
        self = style
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension TextCase: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = TextCase.fromRawValue(rawValue)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension TextAlignment: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = TextAlignment.fromRawValue(rawValue)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension Font.Weight {
    var rawValue: Int {
        switch self {
        case .thin: return 0
        case .ultraLight: return 1
        case .light: return 2
        case .regular: return 3
        case .medium: return 4
        case .semibold: return 5
        case .bold: return 6
        case .heavy: return 7
        default: return 3 // Default to regular
        }
    }
    
    static func fromRawValue(_ rawValue: Int) -> Font.Weight {
        switch rawValue {
        case 0: return .thin
        case 1: return .ultraLight
        case 2: return .light
        case 3: return .regular
        case 4: return .medium
        case 5: return .semibold
        case 6: return .bold
        case 7: return .heavy
        default: return .regular
        }
    }
} 