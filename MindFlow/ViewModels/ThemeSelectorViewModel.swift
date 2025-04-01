import SwiftUI
import AppKit

// Local background style definition
enum UIBackgroundStyle: String, CaseIterable, Identifiable {
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

// Local theme definition
enum UITheme: String, CaseIterable {
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

// Local theme attributes definition
struct UIThemeAttributes {
    let backgroundColor: Color
    let backgroundStyle: UIBackgroundStyle
    let topicFillColor: Color
    let topicBorderColor: Color
    let topicTextColor: Color
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    let isDark: Bool
    
    init(
        backgroundColor: Color,
        backgroundStyle: UIBackgroundStyle,
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
}

class ThemeSelectorViewModel: ObservableObject {
    @Published var isDarkMode: Bool = false
    @Published var selectedTheme: UITheme = .light
    @Published var themeError: String?
    
    private var themeAttributes: [UITheme: UIThemeAttributes] = [
        .light: UIThemeAttributes(
            backgroundColor: Color(red: 0.95, green: 0.95, blue: 0.97),
            backgroundStyle: .grid,
            topicFillColor: Color(red: 0.11, green: 0.23, blue: 0.39),
            topicBorderColor: Color(red: 0.15, green: 0.31, blue: 0.55),
            topicTextColor: Color.white,
            primaryColor: Color(red: 0.11, green: 0.23, blue: 0.39),
            secondaryColor: Color(red: 0.95, green: 0.95, blue: 0.97),
            accentColor: Color(red: 0.15, green: 0.31, blue: 0.55),
            isDark: false
        ),
        .dark: UIThemeAttributes(
            backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.14),
            backgroundStyle: .grid,
            topicFillColor: Color(red: 0.18, green: 0.18, blue: 0.2),
            topicBorderColor: Color(red: 0.2, green: 0.7, blue: 0.9),
            topicTextColor: Color.white,
            primaryColor: Color(red: 0.2, green: 0.7, blue: 0.9),
            secondaryColor: Color(red: 0.12, green: 0.12, blue: 0.14),
            accentColor: Color(red: 0.1, green: 0.6, blue: 0.8),
            isDark: true
        ),
        .nature: UIThemeAttributes(
            backgroundColor: Color(red: 0.9, green: 0.95, blue: 0.9),
            backgroundStyle: .grid,
            topicFillColor: Color(red: 0.75, green: 0.85, blue: 0.75),
            topicBorderColor: Color(red: 0.4, green: 0.65, blue: 0.4),
            topicTextColor: Color(red: 0.15, green: 0.3, blue: 0.15),
            primaryColor: Color(red: 0.4, green: 0.65, blue: 0.4),
            secondaryColor: Color(red: 0.9, green: 0.95, blue: 0.9),
            accentColor: Color(red: 0.35, green: 0.55, blue: 0.35),
            isDark: false
        ),
        .ocean: UIThemeAttributes(
            backgroundColor: Color(red: 0.9, green: 0.95, blue: 1.0),
            backgroundStyle: .dots,
            topicFillColor: Color(red: 0.8, green: 0.9, blue: 0.95),
            topicBorderColor: Color(red: 0.15, green: 0.5, blue: 0.7),
            topicTextColor: Color(red: 0.1, green: 0.3, blue: 0.5),
            primaryColor: Color(red: 0.15, green: 0.5, blue: 0.7),
            secondaryColor: Color(red: 0.9, green: 0.95, blue: 1.0),
            accentColor: Color(red: 0.1, green: 0.4, blue: 0.6),
            isDark: false
        ),
        .sunset: UIThemeAttributes(
            backgroundColor: Color(red: 0.98, green: 0.95, blue: 0.9),
            backgroundStyle: .grid,
            topicFillColor: Color(red: 1.0, green: 0.9, blue: 0.85),
            topicBorderColor: Color(red: 0.9, green: 0.5, blue: 0.3),
            topicTextColor: Color(red: 0.6, green: 0.3, blue: 0.1),
            primaryColor: Color(red: 0.9, green: 0.5, blue: 0.3),
            secondaryColor: Color(red: 0.98, green: 0.95, blue: 0.9),
            accentColor: Color(red: 0.8, green: 0.4, blue: 0.2),
            isDark: false
        ),
        .lavender: UIThemeAttributes(
            backgroundColor: Color(red: 0.96, green: 0.94, blue: 0.98),
            backgroundStyle: .dots,
            topicFillColor: Color(red: 0.9, green: 0.85, blue: 0.95),
            topicBorderColor: Color(red: 0.55, green: 0.45, blue: 0.7),
            topicTextColor: Color(red: 0.4, green: 0.3, blue: 0.5),
            primaryColor: Color(red: 0.55, green: 0.45, blue: 0.7),
            secondaryColor: Color(red: 0.96, green: 0.94, blue: 0.98),
            accentColor: Color(red: 0.45, green: 0.35, blue: 0.6),
            isDark: false
        ),
        .minimal: UIThemeAttributes(
            backgroundColor: Color(red: 0.97, green: 0.97, blue: 0.97),
            backgroundStyle: .grid,
            topicFillColor: Color.white,
            topicBorderColor: Color(red: 0.3, green: 0.3, blue: 0.3),
            topicTextColor: Color(red: 0.2, green: 0.2, blue: 0.2),
            primaryColor: Color(red: 0.3, green: 0.3, blue: 0.3),
            secondaryColor: Color(red: 0.97, green: 0.97, blue: 0.97),
            accentColor: Color(red: 0.2, green: 0.2, blue: 0.2),
            isDark: false
        ),
        .corporate: UIThemeAttributes(
            backgroundColor: Color(red: 0.95, green: 0.96, blue: 0.98),
            backgroundStyle: .grid,
            topicFillColor: Color(red: 0.11, green: 0.23, blue: 0.39),
            topicBorderColor: Color(red: 0.15, green: 0.31, blue: 0.55),
            topicTextColor: Color.white,
            primaryColor: Color(red: 0.11, green: 0.23, blue: 0.39),
            secondaryColor: Color(red: 0.95, green: 0.96, blue: 0.98),
            accentColor: Color(red: 0.15, green: 0.31, blue: 0.55),
            isDark: false
        ),
        .tech: UIThemeAttributes(
            backgroundColor: Color(red: 0.96, green: 0.96, blue: 0.96),
            backgroundStyle: .dots,
            topicFillColor: Color(red: 0.0, green: 0.45, blue: 0.78),
            topicBorderColor: Color(red: 0.0, green: 0.33, blue: 0.57),
            topicTextColor: Color.white,
            primaryColor: Color(red: 0.0, green: 0.45, blue: 0.78),
            secondaryColor: Color(red: 0.96, green: 0.96, blue: 0.96),
            accentColor: Color(red: 0.0, green: 0.33, blue: 0.57),
            isDark: false
        ),
        .energy: UIThemeAttributes(
            backgroundColor: Color(red: 0.98, green: 0.94, blue: 0.88),
            backgroundStyle: .grid,
            topicFillColor: Color(red: 0.83, green: 0.28, blue: 0.15),
            topicBorderColor: Color(red: 0.95, green: 0.77, blue: 0.06),
            topicTextColor: Color.white,
            primaryColor: Color(red: 0.83, green: 0.28, blue: 0.15),
            secondaryColor: Color(red: 0.98, green: 0.94, blue: 0.88),
            accentColor: Color(red: 0.95, green: 0.77, blue: 0.06),
            isDark: false
        ),
        .finance: UIThemeAttributes(
            backgroundColor: Color(red: 0.93, green: 0.94, blue: 0.94),
            backgroundStyle: .grid,
            topicFillColor: Color(red: 0.13, green: 0.28, blue: 0.33),
            topicBorderColor: Color(red: 0.19, green: 0.59, blue: 0.53),
            topicTextColor: Color.white,
            primaryColor: Color(red: 0.13, green: 0.28, blue: 0.33),
            secondaryColor: Color(red: 0.93, green: 0.94, blue: 0.94),
            accentColor: Color(red: 0.19, green: 0.59, blue: 0.53),
            isDark: false
        ),
        .innovation: UIThemeAttributes(
            backgroundColor: Color(red: 0.95, green: 0.97, blue: 0.97),
            backgroundStyle: .dots,
            topicFillColor: Color(red: 0.10, green: 0.74, blue: 0.61),
            topicBorderColor: Color(red: 0.13, green: 0.55, blue: 0.45),
            topicTextColor: Color.white,
            primaryColor: Color(red: 0.10, green: 0.74, blue: 0.61),
            secondaryColor: Color(red: 0.95, green: 0.97, blue: 0.97),
            accentColor: Color(red: 0.13, green: 0.55, blue: 0.45),
            isDark: false
        ),
        .creative: UIThemeAttributes(
            backgroundColor: Color(red: 0.96, green: 0.94, blue: 0.98),
            backgroundStyle: .dots,
            topicFillColor: Color(red: 0.52, green: 0.27, blue: 0.48),
            topicBorderColor: Color(red: 0.9, green: 0.56, blue: 0.36),
            topicTextColor: Color.white,
            primaryColor: Color(red: 0.52, green: 0.27, blue: 0.48),
            secondaryColor: Color(red: 0.96, green: 0.94, blue: 0.98),
            accentColor: Color(red: 0.9, green: 0.56, blue: 0.36),
            isDark: false
        ),
        .sepia: UIThemeAttributes(
            backgroundColor: Color(red: 0.98, green: 0.95, blue: 0.9),
            backgroundStyle: .grid,
            topicFillColor: Color(red: 0.98, green: 0.95, blue: 0.9),
            topicBorderColor: Color(red: 0.6, green: 0.4, blue: 0.2),
            topicTextColor: Color(red: 0.4, green: 0.3, blue: 0.2),
            primaryColor: Color(red: 0.6, green: 0.4, blue: 0.2),
            secondaryColor: Color(red: 0.98, green: 0.95, blue: 0.9),
            accentColor: Color(red: 0.5, green: 0.3, blue: 0.1),
            isDark: false
        ),
        .highContrast: UIThemeAttributes(
            backgroundColor: Color.black,
            backgroundStyle: .grid,
            topicFillColor: Color.black,
            topicBorderColor: Color.yellow,
            topicTextColor: Color.white,
            primaryColor: Color.yellow,
            secondaryColor: Color.black,
            accentColor: Color.white,
            isDark: true
        )
    ]
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: NSNotification.Name("ThemeChange"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDarkModeToggle),
            name: NSNotification.Name("DarkModeToggle"),
            object: nil
        )
    }
    
    @objc private func handleThemeChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let theme = userInfo["theme"] as? UITheme else { return }
        
        updateTheme(to: theme)
    }
    
    @objc private func handleDarkModeToggle(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isDark = userInfo["isDark"] as? Bool else { return }
        
        toggleDarkMode(isDark)
    }
    
    func updateTheme(to theme: UITheme) {
        selectedTheme = theme
        themeError = nil
        
        if let attributes = themeAttributes[theme] {
            NotificationCenter.default.post(
                name: NSNotification.Name("ThemeChanged"),
                object: nil,
                userInfo: [
                    "backgroundColor": attributes.backgroundColor,
                    "backgroundStyle": attributes.backgroundStyle,
                    "topicFillColor": attributes.topicFillColor,
                    "topicBorderColor": attributes.topicBorderColor,
                    "topicTextColor": attributes.topicTextColor,
                    "primaryColor": attributes.primaryColor,
                    "secondaryColor": attributes.secondaryColor,
                    "accentColor": attributes.accentColor,
                    "isDark": attributes.isDark
                ]
            )
        }
    }
    
    func toggleDarkMode(_ isDark: Bool) {
        isDarkMode = isDark
        updateTheme(to: isDark ? UITheme.dark : UITheme.light)
        
        NotificationCenter.default.post(
            name: NSNotification.Name("DarkModeToggled"),
            object: nil,
            userInfo: ["isDark": isDark]
        )
    }
    
    func applyTheme(
        backgroundColor: Color,
        backgroundStyle: UIBackgroundStyle,
        topicFillColor: Color,
        topicBorderColor: Color,
        topicTextColor: Color,
        themeName: String = ""
    ) {
        // Create a new theme with the provided attributes
        let newTheme = UITheme(rawValue: themeName) ?? UITheme.light
        let attributes = UIThemeAttributes(
            backgroundColor: backgroundColor,
            backgroundStyle: backgroundStyle,
            topicFillColor: topicFillColor,
            topicBorderColor: topicBorderColor,
            topicTextColor: topicTextColor,
            primaryColor: topicBorderColor,
            secondaryColor: backgroundColor,
            accentColor: topicBorderColor,
            isDark: isDarkMode
        )
        
        // Store the new theme attributes
        themeAttributes[newTheme] = attributes
        
        // Update the selected theme
        updateTheme(to: newTheme)
    }
    
    // Add a conversion function
    func convertToModelTheme(_ theme: UITheme) -> ModelTheme {
        switch theme {
        case .light: return .light
        case .dark: return .dark
        case .nature: return .nature
        case .ocean: return .ocean
        case .sunset: return .sunset
        case .lavender: return .lavender
        case .minimal: return .minimal
        case .corporate: return .corporate
        case .tech: return .tech
        case .energy: return .energy
        case .finance: return .finance
        case .innovation: return .innovation
        case .creative: return .creative
        case .sepia: return .sepia
        case .highContrast: return .highContrast
        }
    }
    
    func convertBackgroundStyle(_ style: UIBackgroundStyle) -> ModelBackgroundStyle {
        switch style {
        case .none: return .none
        case .grid: return .grid
        case .dots: return .dots
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 