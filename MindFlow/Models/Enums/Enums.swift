import Foundation
import SwiftUI

// MARK: - Topic Shape
enum TopicShape: String, CaseIterable, Identifiable {
    case rectangle = "Rectangle"
    case roundedRectangle = "Rounded Rectangle"
    case ellipse = "Ellipse"
    case diamond = "Diamond"
    case hexagon = "Hexagon"
    case octagon = "Octagon"
    case star = "Star"
    case cloud = "Cloud"
    case parallelogram = "Parallelogram"
    case triangle = "Triangle"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .rectangle: return "rectangle"
        case .roundedRectangle: return "rectangle.roundedtop"
        case .ellipse: return "oval"
        case .diamond: return "diamond"
        case .hexagon: return "hexagon"
        case .octagon: return "octagon"
        case .star: return "star"
        case .cloud: return "cloud"
        case .parallelogram: return "parallelogram"
        case .triangle: return "triangle"
        }
    }
}

// MARK: - Topic Border Width
enum TopicBorderWidth: CGFloat, CaseIterable, Identifiable {
    case thin = 1.0
    case medium = 2.0
    case thick = 3.0
    case extraThick = 4.0
    
    var id: String { self.rawValue.description }
    
    var displayName: String {
        switch self {
        case .thin: return "Thin"
        case .medium: return "Medium"
        case .thick: return "Thick"
        case .extraThick: return "Extra Thick"
        }
    }
}

// MARK: - Topic Branch Style
enum TopicBranchStyle: String, CaseIterable, Identifiable {
    case straight = "Straight"
    case curved = "Curved"
    case angled = "Angled"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .straight: return "Straight"
        case .curved: return "Curved"
        case .angled: return "Angled"
        }
    }
}

// MARK: - Text Style
enum TextStyle: String, CaseIterable, Identifiable {
    case bold = "Bold"
    case italic = "Italic"
    case underline = "Underline"
    case strikethrough = "Strikethrough"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .bold: return "bold"
        case .italic: return "italic"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        }
    }
    
    var intValue: Int {
        switch self {
        case .bold: return 0
        case .italic: return 1
        case .underline: return 2
        case .strikethrough: return 3
        }
    }
    
    static func fromIntValue(_ intValue: Int) -> TextStyle? {
        switch intValue {
        case 0: return .bold
        case 1: return .italic
        case 2: return .underline
        case 3: return .strikethrough
        default: return nil
        }
    }
}

// MARK: - Text Case
enum TextCase: String, CaseIterable, Identifiable {
    case none = "None"
    case uppercase = "Uppercase"
    case lowercase = "Lowercase"
    case capitalize = "Capitalize"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "Normal"
        case .uppercase: return "UPPERCASE"
        case .lowercase: return "lowercase"
        case .capitalize: return "Capitalize"
        }
    }
    
    var intValue: Int {
        switch self {
        case .none: return 0
        case .uppercase: return 1
        case .lowercase: return 2
        case .capitalize: return 3
        }
    }
    
    static func fromIntValue(_ intValue: Int) -> TextCase {
        switch intValue {
        case 1: return .uppercase
        case 2: return .lowercase
        case 3: return .capitalize
        default: return .none
        }
    }
}

// MARK: - Text Alignment
enum TextAlignment: String, CaseIterable, Identifiable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }
    
    var intValue: Int {
        switch self {
        case .left: return 0
        case .center: return 1
        case .right: return 2
        }
    }
    
    static func fromIntValue(_ intValue: Int) -> TextAlignment {
        switch intValue {
        case 0: return .left
        case 2: return .right
        default: return .center
        }
    }
}

// MARK: - Sidebar Mode
enum SidebarMode: String, CaseIterable, Identifiable {
    case style = "Style"
    case map = "Map"
    case ai = "AI"
    
    var id: String { self.rawValue }
}

// MARK: - Background Style
enum BackgroundStyle: String, CaseIterable, Identifiable {
    case none = "None"
    case grid = "Grid"
    case dots = "Dots"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .none: return "square"
        case .grid: return "grid"
        case .dots: return "circle.grid.3x3"
        }
    }
}
