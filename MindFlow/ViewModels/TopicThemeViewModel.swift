import SwiftUI
import AppKit

class TopicThemeViewModel: ObservableObject {
    @Published var currentTheme: Theme = .light
    @Published var isDarkMode: Bool = false
    @Published var primaryColor: Color = .blue
    @Published var secondaryColor: Color = .gray
    @Published var accentColor: Color = .orange
    @Published var backgroundColor: Color = .white
    @Published var textColor: Color = .black
    @Published var themeError: String?
    
    private let themes: [Theme: ThemeAttributes] = [
        .light: ThemeAttributes(
            primaryColor: .blue,
            secondaryColor: .gray,
            accentColor: .orange,
            backgroundColor: .white,
            textColor: .black,
            isDark: false
        ),
        .dark: ThemeAttributes(
            primaryColor: .blue,
            secondaryColor: .gray,
            accentColor: .orange,
            backgroundColor: .black,
            textColor: .white,
            isDark: true
        ),
        .sepia: ThemeAttributes(
            primaryColor: .brown,
            secondaryColor: .gray,
            accentColor: .orange,
            backgroundColor: Color(red: 0.98, green: 0.95, blue: 0.9),
            textColor: .black,
            isDark: false
        ),
        .highContrast: ThemeAttributes(
            primaryColor: .yellow,
            secondaryColor: .white,
            accentColor: .green,
            backgroundColor: .black,
            textColor: .white,
            isDark: true
        )
    ]
    
    init() {
        setupObservers()
        applyTheme(.light)
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
              let theme = userInfo["theme"] as? Theme else { return }
        
        applyTheme(theme)
    }
    
    @objc private func handleDarkModeToggle() {
        toggleDarkMode()
    }
    
    func applyTheme(_ theme: Theme) {
        guard let attributes = themes[theme] else { return }
        
        currentTheme = theme
        primaryColor = attributes.primaryColor
        secondaryColor = attributes.secondaryColor
        accentColor = attributes.accentColor
        backgroundColor = attributes.backgroundColor
        textColor = attributes.textColor
        isDarkMode = attributes.isDark
        themeError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ThemeApplied"),
            object: nil,
            userInfo: ["theme": theme]
        )
    }
    
    func toggleDarkMode() {
        let newTheme: Theme = isDarkMode ? .light : .dark
        applyTheme(newTheme)
    }
    
    func updateColors(
        primary: Color? = nil,
        secondary: Color? = nil,
        accent: Color? = nil,
        background: Color? = nil,
        text: Color? = nil
    ) {
        if let primary = primary {
            primaryColor = primary
        }
        if let secondary = secondary {
            secondaryColor = secondary
        }
        if let accent = accent {
            accentColor = accent
        }
        if let background = background {
            backgroundColor = background
        }
        if let text = text {
            textColor = text
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ThemeColorsUpdated"),
            object: nil,
            userInfo: [
                "primaryColor": primaryColor,
                "secondaryColor": secondaryColor,
                "accentColor": accentColor,
                "backgroundColor": backgroundColor,
                "textColor": textColor
            ]
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

enum Theme: String {
    case light
    case dark
    case sepia
    case highContrast
}

struct ThemeAttributes {
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    let backgroundColor: Color
    let textColor: Color
    let isDark: Bool
} 