import SwiftUI

struct ThemeSection: View {
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        SidebarSection(title: "Theme", content: AnyView(
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Nature theme
                ThemeButton(
                    name: "Nature",
                    primaryColor: Color(red: 0.4, green: 0.65, blue: 0.4),
                    secondaryColor: Color(red: 0.85, green: 0.9, blue: 0.85),
                    accentColor: Color(red: 0.35, green: 0.55, blue: 0.35),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.9, green: 0.95, blue: 0.9),
                            backgroundStyle: .grid,
                            topicFillColor: Color(red: 0.75, green: 0.85, blue: 0.75),
                            topicBorderColor: Color(red: 0.4, green: 0.65, blue: 0.4),
                            topicTextColor: Color(red: 0.15, green: 0.3, blue: 0.15),
                            themeName: "Nature"
                        )
                    }
                )
                
                // Ocean theme
                ThemeButton(
                    name: "Ocean",
                    primaryColor: Color(red: 0.15, green: 0.5, blue: 0.7),
                    secondaryColor: Color(red: 0.85, green: 0.9, blue: 0.95),
                    accentColor: Color(red: 0.1, green: 0.4, blue: 0.6),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.9, green: 0.95, blue: 1.0),
                            backgroundStyle: .dots,
                            topicFillColor: Color(red: 0.8, green: 0.9, blue: 0.95),
                            topicBorderColor: Color(red: 0.15, green: 0.5, blue: 0.7),
                            topicTextColor: Color(red: 0.1, green: 0.3, blue: 0.5),
                            themeName: "Ocean"
                        )
                    }
                )
                
                // Sunset theme
                ThemeButton(
                    name: "Sunset",
                    primaryColor: Color(red: 0.9, green: 0.5, blue: 0.3),
                    secondaryColor: Color(red: 1.0, green: 0.95, blue: 0.9),
                    accentColor: Color(red: 0.8, green: 0.4, blue: 0.2),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.98, green: 0.95, blue: 0.9),
                            backgroundStyle: .grid,
                            topicFillColor: Color(red: 1.0, green: 0.9, blue: 0.85),
                            topicBorderColor: Color(red: 0.9, green: 0.5, blue: 0.3),
                            topicTextColor: Color(red: 0.6, green: 0.3, blue: 0.1),
                            themeName: "Sunset"
                        )
                    }
                )
                
                // Lavender theme
                ThemeButton(
                    name: "Lavender",
                    primaryColor: Color(red: 0.55, green: 0.45, blue: 0.7),
                    secondaryColor: Color(red: 0.95, green: 0.9, blue: 1.0),
                    accentColor: Color(red: 0.45, green: 0.35, blue: 0.6),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.96, green: 0.94, blue: 0.98),
                            backgroundStyle: .dots,
                            topicFillColor: Color(red: 0.9, green: 0.85, blue: 0.95),
                            topicBorderColor: Color(red: 0.55, green: 0.45, blue: 0.7),
                            topicTextColor: Color(red: 0.4, green: 0.3, blue: 0.5),
                            themeName: "Lavender"
                        )
                    }
                )
                
                // Minimal theme
                ThemeButton(
                    name: "Minimal",
                    primaryColor: Color(red: 0.3, green: 0.3, blue: 0.3),
                    secondaryColor: Color(red: 0.95, green: 0.95, blue: 0.95),
                    accentColor: Color(red: 0.2, green: 0.2, blue: 0.2),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.97, green: 0.97, blue: 0.97),
                            backgroundStyle: .grid,
                            topicFillColor: Color.white,
                            topicBorderColor: Color(red: 0.3, green: 0.3, blue: 0.3),
                            topicTextColor: Color(red: 0.2, green: 0.2, blue: 0.2),
                            themeName: "Minimal"
                        )
                    }
                )
                
                // Dark theme
                ThemeButton(
                    name: "Dark",
                    primaryColor: Color(red: 0.2, green: 0.7, blue: 0.9),
                    secondaryColor: Color(red: 0.15, green: 0.15, blue: 0.15),
                    accentColor: Color(red: 0.1, green: 0.6, blue: 0.8),
                    isDark: true,
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.14),
                            backgroundStyle: .grid,
                            topicFillColor: Color(red: 0.18, green: 0.18, blue: 0.2),
                            topicBorderColor: Color(red: 0.2, green: 0.7, blue: 0.9),
                            topicTextColor: Color.white,
                            themeName: "Dark"
                        )
                    }
                )
                
                // Corporate theme - professional blues for business
                ThemeButton(
                    name: "Corporate",
                    primaryColor: Color(red: 0.11, green: 0.23, blue: 0.39),
                    secondaryColor: Color(red: 0.95, green: 0.95, blue: 0.97),
                    accentColor: Color(red: 0.15, green: 0.31, blue: 0.55),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.95, green: 0.96, blue: 0.98),
                            backgroundStyle: .grid,
                            topicFillColor: Color(red: 0.11, green: 0.23, blue: 0.39),
                            topicBorderColor: Color(red: 0.15, green: 0.31, blue: 0.55),
                            topicTextColor: Color.white,
                            themeName: "Corporate"
                        )
                    }
                )
                
                // Tech theme - inspired by modern tech interfaces
                ThemeButton(
                    name: "Tech",
                    primaryColor: Color(red: 0.0, green: 0.45, blue: 0.78),
                    secondaryColor: Color(red: 0.96, green: 0.96, blue: 0.96),
                    accentColor: Color(red: 0.0, green: 0.33, blue: 0.57),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.96, green: 0.96, blue: 0.96),
                            backgroundStyle: .dots,
                            topicFillColor: Color(red: 0.0, green: 0.45, blue: 0.78),
                            topicBorderColor: Color(red: 0.0, green: 0.33, blue: 0.57),
                            topicTextColor: Color.white,
                            themeName: "Tech"
                        )
                    }
                )
                
                // Energy theme - vibrant and dynamic
                ThemeButton(
                    name: "Energy",
                    primaryColor: Color(red: 0.83, green: 0.28, blue: 0.15),
                    secondaryColor: Color(red: 0.98, green: 0.94, blue: 0.88),
                    accentColor: Color(red: 0.95, green: 0.77, blue: 0.06),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.98, green: 0.94, blue: 0.88),
                            backgroundStyle: .grid,
                            topicFillColor: Color(red: 0.83, green: 0.28, blue: 0.15),
                            topicBorderColor: Color(red: 0.95, green: 0.77, blue: 0.06),
                            topicTextColor: Color.white,
                            themeName: "Energy"
                        )
                    }
                )
                
                // Finance theme - elegant and trustworthy
                ThemeButton(
                    name: "Finance",
                    primaryColor: Color(red: 0.13, green: 0.28, blue: 0.33),
                    secondaryColor: Color(red: 0.93, green: 0.94, blue: 0.94),
                    accentColor: Color(red: 0.19, green: 0.59, blue: 0.53),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.93, green: 0.94, blue: 0.94),
                            backgroundStyle: .grid,
                            topicFillColor: Color(red: 0.13, green: 0.28, blue: 0.33),
                            topicBorderColor: Color(red: 0.19, green: 0.59, blue: 0.53),
                            topicTextColor: Color.white,
                            themeName: "Finance"
                        )
                    }
                )
                
                // Innovation theme - modern and forward-thinking
                ThemeButton(
                    name: "Innovation",
                    primaryColor: Color(red: 0.10, green: 0.74, blue: 0.61),
                    secondaryColor: Color(red: 0.95, green: 0.97, blue: 0.97),
                    accentColor: Color(red: 0.13, green: 0.55, blue: 0.45),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.95, green: 0.97, blue: 0.97),
                            backgroundStyle: .dots,
                            topicFillColor: Color(red: 0.10, green: 0.74, blue: 0.61),
                            topicBorderColor: Color(red: 0.13, green: 0.55, blue: 0.45),
                            topicTextColor: Color.white,
                            themeName: "Innovation"
                        )
                    }
                )
                
                // Creative theme - balanced and sophisticated
                ThemeButton(
                    name: "Creative",
                    primaryColor: Color(red: 0.52, green: 0.27, blue: 0.48),
                    secondaryColor: Color(red: 0.96, green: 0.94, blue: 0.98),
                    accentColor: Color(red: 0.9, green: 0.56, blue: 0.36),
                    onSelect: {
                        applyTheme(
                            viewModel: viewModel,
                            backgroundColor: Color(red: 0.96, green: 0.94, blue: 0.98),
                            backgroundStyle: .dots,
                            topicFillColor: Color(red: 0.52, green: 0.27, blue: 0.48),
                            topicBorderColor: Color(red: 0.9, green: 0.56, blue: 0.36),
                            topicTextColor: Color.white,
                            themeName: "Creative"
                        )
                    }
                )
            }
                .padding(.horizontal)
        ))
    }
    
    private func applyTheme(
        viewModel: CanvasViewModel,
        backgroundColor: Color,
        backgroundStyle: BackgroundStyle,
        topicFillColor: Color,
        topicBorderColor: Color,
        topicTextColor: Color,
        themeName: String = ""
    ) {
        // Post a notification to update the canvas background
        NotificationCenter.default.post(
            name: NSNotification.Name("ApplyThemeToCanvas"),
            object: nil,
            userInfo: [
                "backgroundColor": backgroundColor,
                "backgroundStyle": backgroundStyle
            ]
        )
        
        // Update all topics with the theme colors
        for topicId in viewModel.getAllTopicIds() {
            viewModel.updateTopicBackgroundColor(topicId, color: topicFillColor)
            viewModel.updateTopicBorderColor(topicId, color: topicBorderColor)
            viewModel.updateTopicForegroundColor(topicId, color: topicTextColor)
        }
        
        // Update the theme in the ViewModel
        viewModel.setCurrentTheme(
            topicFillColor: topicFillColor,
            topicBorderColor: topicBorderColor,
            topicTextColor: topicTextColor
        )
    }
}
