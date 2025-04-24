//
//  Color.swift
//  MindFlow
//
//  Created by Sharnabh on 08/04/25.
//

import SwiftUI

// Add these extensions for color handling
extension Color {
    // The init?(hex:) method has been moved to ColorExtensions.swift
    // Please use the implementation there instead
    
    func toHex() -> String? {
        // Use the hexString property from ColorExtensions.swift instead
        return self.hexString
    }
}


extension Font.Weight: @retroactive CaseIterable {
    public static var allCases: [Font.Weight] = [
        .thin,
        .ultraLight,
        .light,
        .regular,
        .medium,
        .semibold,
        .bold,
        .heavy
    ]
    
    var displayName: String {
        switch self {
        case .thin: return "Thin"
        case .ultraLight: return "Extra Light"
        case .light: return "Light"
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        case .heavy: return "Extra Bold"
        default: return "Regular"
        }
    }
}
