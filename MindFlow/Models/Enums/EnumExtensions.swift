import Foundation
import SwiftUI

// This file contains extensions for the TextStyle, TextCase, and TextAlignment enums
// defined in InfiniteCanvas.swift to make them Codable and provide helper methods

extension TextStyle {
    var rawValue: Int {
        switch self {
        case .bold: return 0
        case .italic: return 1
        case .strikethrough: return 2
        case .underline: return 3
        }
    }
    
    static func fromRawValue(_ rawValue: Int) -> TextStyle? {
        switch rawValue {
        case 0: return .bold
        case 1: return .italic
        case 2: return .strikethrough
        case 3: return .underline
        default: return nil
        }
    }
}

extension TextCase {
    var rawValue: Int {
        switch self {
        case .none: return 0
        case .uppercase: return 1
        case .lowercase: return 2
        case .capitalize: return 3
        }
    }
    
    static func fromRawValue(_ rawValue: Int) -> TextCase {
        switch rawValue {
        case 1: return .uppercase
        case 2: return .lowercase
        case 3: return .capitalize
        default: return .none
        }
    }
}

extension TextAlignment {
    var rawValue: Int {
        switch self {
        case .left: return 0
        case .center: return 1
        case .right: return 2
        }
    }
    
    static func fromRawValue(_ rawValue: Int) -> TextAlignment {
        switch rawValue {
        case 0: return .left
        case 2: return .right
        default: return .center
        }
    }
}
