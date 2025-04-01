import SwiftUI

// Define the enum within the Theme file scope to avoid ambiguity
enum ModelBackgroundStyle {
    case none
    case grid
    case dots
}

enum ModelTheme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case nature = "Nature"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case lavender = "Lavender"
    case minimal = "Minimal"
    case corporate = "Corporate"
    case tech = "Tech"
    case energy = "Energy"
    case finance = "Finance"
    case innovation = "Innovation"
    case creative = "Creative"
    case sepia = "Sepia"
    case highContrast = "High Contrast"
}

struct ModelThemeAttributes {
    let backgroundColor: Color
    let backgroundStyle: ModelBackgroundStyle
    let topicFillColor: Color
    let topicBorderColor: Color
    let topicTextColor: Color
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    let isDark: Bool
    
    init(
        backgroundColor: Color,
        backgroundStyle: ModelBackgroundStyle,
        topicFillColor: Color,
        topicBorderColor: Color,
        topicTextColor: Color,
        primaryColor: Color,
        secondaryColor: Color,
        accentColor: Color,
        isDark: Bool
    ) {
        self.backgroundColor = backgroundColor
        self.backgroundStyle = backgroundStyle
        self.topicFillColor = topicFillColor
        self.topicBorderColor = topicBorderColor
        self.topicTextColor = topicTextColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.isDark = isDark
    }
    
    // Convenience initializer for simpler themes
    init(
        primaryColor: Color,
        secondaryColor: Color,
        accentColor: Color,
        backgroundColor: Color,
        textColor: Color,
        isDark: Bool
    ) {
        self.backgroundColor = backgroundColor
        self.backgroundStyle = .grid
        self.topicFillColor = backgroundColor
        self.topicBorderColor = primaryColor
        self.topicTextColor = textColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.isDark = isDark
    }
} 