import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: Theme = Theme.defaultTheme
    
    private init() {}
    
    // MARK: - Theme Management
    
    func applyTheme(
        viewModel: CanvasViewModel,
        backgroundColor: Color,
        backgroundStyle: BackgroundStyle,
        topicFillColor: Color,
        topicBorderColor: Color,
        topicTextColor: Color,
        themeName: String
    ) {
        let newTheme = Theme(
            name: themeName,
            backgroundColor: backgroundColor,
            backgroundStyle: backgroundStyle,
            topicFillColor: topicFillColor,
            topicBorderColor: topicBorderColor,
            topicTextColor: topicTextColor
        )
        
        // Update all topics with the theme colors
        for topicId in viewModel.getAllTopicIds() {
            // Update fill color
            viewModel.updateTopicBackgroundColor(topicId, color: topicFillColor)
            
            // Update border color
            viewModel.updateTopicBorderColor(topicId, color: topicBorderColor)
            
            // Update text color
            viewModel.updateTopicForegroundColor(topicId, color: topicTextColor)
        }
        
        // Update the theme in the ViewModel
        viewModel.setCurrentTheme(
            topicFillColor: topicFillColor,
            topicBorderColor: topicBorderColor,
            topicTextColor: topicTextColor
        )
        
        currentTheme = newTheme
        NotificationCenter.default.post(name: NSNotification.Name("ThemeApplied"), object: newTheme)
    }
    
    func resetToDefaultTheme(viewModel: CanvasViewModel) {
        applyTheme(
            viewModel: viewModel,
            backgroundColor: Theme.defaultTheme.backgroundColor,
            backgroundStyle: Theme.defaultTheme.backgroundStyle,
            topicFillColor: Theme.defaultTheme.topicFillColor,
            topicBorderColor: Theme.defaultTheme.topicBorderColor,
            topicTextColor: Theme.defaultTheme.topicTextColor,
            themeName: Theme.defaultTheme.name
        )
    }
}

// MARK: - Theme Model

struct Theme: Identifiable {
    var id = UUID()
    var name: String
    var backgroundColor: Color
    var backgroundStyle: BackgroundStyle
    var topicFillColor: Color
    var topicBorderColor: Color
    var topicTextColor: Color
    
    static var defaultTheme: Theme {
        Theme(
            name: "Default",
            backgroundColor: .white,
            backgroundStyle: .none,
            topicFillColor: Color(red: 0.95, green: 0.95, blue: 0.97),
            topicBorderColor: Color(red: 0.8, green: 0.8, blue: 0.8),
            topicTextColor: .black
        )
    }
} 
