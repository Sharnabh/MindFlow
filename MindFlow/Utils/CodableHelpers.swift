import SwiftUI

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

// MARK: - Enum Codable Extensions

extension TextStyle: Codable {
    enum CodingKeys: CodingKey {
        case intValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        guard let style = TextStyle.fromIntValue(rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid text style raw value")
        }
        self = style
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(intValue)
    }
}

extension TextCase: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = TextCase.fromIntValue(rawValue)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(intValue)
    }
}

extension TextAlignment: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = TextAlignment.fromIntValue(rawValue)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(intValue)
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
