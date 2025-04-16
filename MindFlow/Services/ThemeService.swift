import Foundation
import SwiftUI

// Protocol defining theme operations
protocol ThemeServiceProtocol {
    // Theme management
    var currentTheme: ThemeSettings? { get }
    func applyTheme(name: String, backgroundColor: Color, backgroundStyle: BackgroundStyle, topicFillColor: Color, topicBorderColor: Color, topicTextColor: Color)
    func getAvailableThemes() -> [ThemeSettings]
    
    // Background settings
    func setBackgroundStyle(_ style: BackgroundStyle)
    func setBackgroundColor(_ color: Color)
    func setBackgroundOpacity(_ opacity: Double)
}

// Theme settings
struct ThemeSettings: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let backgroundColor: Color
    let backgroundStyle: BackgroundStyle
    let topicFillColor: Color
    let topicBorderColor: Color
    let topicTextColor: Color
    
    static func == (lhs: ThemeSettings, rhs: ThemeSettings) -> Bool {
        return lhs.name == rhs.name &&
               lhs.backgroundColor == rhs.backgroundColor &&
               lhs.backgroundStyle == rhs.backgroundStyle &&
               lhs.topicFillColor == rhs.topicFillColor &&
               lhs.topicBorderColor == rhs.topicBorderColor &&
               lhs.topicTextColor == rhs.topicTextColor
    }
}

// Main implementation of the ThemeService
class ThemeService: ThemeServiceProtocol, ObservableObject {
    // Current theme and settings
    @Published private(set) var currentTheme: ThemeSettings?
    @Published private(set) var backgroundStyle: BackgroundStyle = .grid
    @Published private(set) var backgroundColor: Color = Color(.windowBackgroundColor)
    @Published private(set) var backgroundOpacity: Double = 1.0
    
    // Predefined themes
    private let themes: [ThemeSettings] = [
        ThemeSettings(
            name: "Classic",
            backgroundColor: Color(.windowBackgroundColor),
            backgroundStyle: .grid,
            topicFillColor: .blue,
            topicBorderColor: .blue,
            topicTextColor: .white
        ),
        ThemeSettings(
            name: "Dark",
            backgroundColor: Color(.darkGray),
            backgroundStyle: .dots,
            topicFillColor: Color(.darkGray),
            topicBorderColor: .white,
            topicTextColor: .white
        ),
        ThemeSettings(
            name: "Nature",
            backgroundColor: Color(red: 0.8, green: 0.95, blue: 0.8),
            backgroundStyle: .grid,
            topicFillColor: Color(red: 0.2, green: 0.6, blue: 0.2),
            topicBorderColor: Color(red: 0.1, green: 0.4, blue: 0.1),
            topicTextColor: .white
        ),
        ThemeSettings(
            name: "Ocean",
            backgroundColor: Color(red: 0.8, green: 0.9, blue: 1.0),
            backgroundStyle: .dots,
            topicFillColor: Color(red: 0.0, green: 0.4, blue: 0.8),
            topicBorderColor: Color(red: 0.0, green: 0.2, blue: 0.6),
            topicTextColor: .white
        ),
        ThemeSettings(
            name: "Sunset",
            backgroundColor: Color(red: 1.0, green: 0.95, blue: 0.9),
            backgroundStyle: .none,
            topicFillColor: Color(red: 0.9, green: 0.5, blue: 0.2),
            topicBorderColor: Color(red: 0.7, green: 0.3, blue: 0.1),
            topicTextColor: .white
        )
    ]
    
    // MARK: - Theme Management
    
    func applyTheme(name: String, backgroundColor: Color, backgroundStyle: BackgroundStyle, topicFillColor: Color, topicBorderColor: Color, topicTextColor: Color) {
        // Create new theme settings
        let theme = ThemeSettings(
            name: name,
            backgroundColor: backgroundColor,
            backgroundStyle: backgroundStyle,
            topicFillColor: topicFillColor,
            topicBorderColor: topicBorderColor,
            topicTextColor: topicTextColor
        )
        
        // Apply theme
        self.currentTheme = theme
        self.backgroundColor = backgroundColor
        self.backgroundStyle = backgroundStyle
        
        // Update published properties
        objectWillChange.send()
    }
    
    func getAvailableThemes() -> [ThemeSettings] {
        return themes
    }
    
    // MARK: - Background Settings
    
    func setBackgroundStyle(_ style: BackgroundStyle) {
        backgroundStyle = style
        objectWillChange.send()
    }
    
    func setBackgroundColor(_ color: Color) {
        backgroundColor = color
        objectWillChange.send()
    }
    
    func setBackgroundOpacity(_ opacity: Double) {
        backgroundOpacity = opacity
        objectWillChange.send()
    }
} 