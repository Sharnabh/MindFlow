import SwiftUI
import Combine

// This view assumes PresentationManager, CanvasViewModel, PresentationSettings, Topic,
// and the nested types PresentationManager.Slide and PresentationSettings.BulletStyle
// are defined and accessible from other files in the same module.

struct PresentationCustomizationView: View {
    @EnvironmentObject var presentationManager: PresentationManager
    @EnvironmentObject var canvasViewModel: CanvasViewModel
    @Binding var isPresented: Bool

    @State private var settings: PresentationSettings = PresentationSettings.defaultSettings
    @State private var slideSelections: [SlideSelection] = []
    @State private var cancellables = Set<AnyCancellable>()

    let fontNames = ["System", "Helvetica Neue", "Arial", "Times New Roman", "Courier New"]

    var body: some View {
        VStack(spacing: 0) {
            Text("Customize Presentation")
                .font(.title2)
                .padding()

            HSplitView {
                // Left Panel: Slide Preview and Selection
                VStack {
                    Text("Select Slides")
                        .font(.headline)
                    List {
                        ForEach($slideSelections, id: \.id) { $selection in // Explicitly provide id
                            HStack {
                                SlideSnapshotView(slide: selection.slide, settings: settings) // Added snapshot
                                Text(selection.slide.heading)
                                Spacer()
                                Toggle("", isOn: $selection.isSelected)
                                
                                // Show delete button only for slides that are duplicates (have same heading as another slide)
                                if isDuplicate(selection.slide) {
                                    Button(action: {
                                        if let index = slideSelections.firstIndex(where: { $0.id == selection.id }) {
                                            slideSelections.remove(at: index)
                                            saveSlideArrangement()
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .help("Delete duplicate slide")
                                }
                            }
                            .contextMenu {
                                Button("Duplicate") {
                                    duplicateSlide(selection)
                                }
                            }
                        }
                        .onMove(perform: moveSlide)
                        .onDelete(perform: deleteSlides)
                    }
                }
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 400)

                ScrollView { // Right Panel: Customization Controls
                    Form {
                        Section(header: Text("Themes")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(PresentationTheme.allCases, id: \.self) { theme in
                                        Button(action: {
                                            applyTheme(theme)
                                        }) {
                                            VStack {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(theme.backgroundColor)
                                                    .frame(width: 80, height: 45)
                                                    .overlay(
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text("Aa")
                                                                .font(.system(size: 12, weight: .bold))
                                                                .foregroundColor(theme.textColor)
                                                            
                                                            HStack(spacing: 3) {
                                                                Text("•")
                                                                    .font(.system(size: 10))
                                                                    .foregroundColor(theme.textColor)
                                                                Text("Aa")
                                                                    .font(.system(size: 9))
                                                                    .foregroundColor(theme.textColor)
                                                            }
                                                        }
                                                        .padding(6)
                                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                                                        alignment: .topLeading
                                                    )
                                                    .shadow(radius: 1)
                                                
                                                Text(theme.name)
                                                    .font(.caption2)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .padding(.horizontal, -8)
                        }
                        
                        Section(header: Text("Appearance")) {
                            ColorPicker("Background Color", selection: $settings.backgroundColor.color)
                            ColorPicker("Font Color", selection: $settings.fontColor.color)
                            Picker("Font Name", selection: $settings.fontName) {
                                ForEach(fontNames, id: \.self) { fontName in
                                    Text(fontName).font(.custom(fontName, size: 14))
                                }
                            }
                            Stepper("Font Size: \(settings.fontSize, specifier: "%.0f")", value: $settings.fontSize, in: 10...72)
                            Stepper("Heading Font Size: \(settings.headingFontSize, specifier: "%.0f")", value: $settings.headingFontSize, in: 10...96)
                            Picker("Bullet Style", selection: $settings.bulletStyle) {
                                ForEach(BulletStyle.allCases) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .frame(minWidth: 300)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Play Presentation") {
                    presentationManager.settings = settings // Apply customized settings
                    let selectedSlides = slideSelections.filter { $0.isSelected }.map { $0.slide }
                    if !selectedSlides.isEmpty {
                        presentationManager.startPresentation(slides: selectedSlides)
                        isPresented = false // Close the customization sheet
                    }
                }
                .disabled(slideSelections.filter { $0.isSelected }.isEmpty)
            }
            .padding()
            .frame(height: 50)
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 400, idealHeight: 500)
        .onAppear {
            loadInitialData()
            setupTopicChangeObserver()
        }
        .onDisappear {
            // Clear subscriptions when view disappears
            cancellables.removeAll()
        }
        .background(
            Button("") {
                // Action for Cmd+D: Duplicate the selected or first slide
                if let selected = slideSelections.first(where: { $0.isSelected }) {
                    duplicateSlide(selected)
                } else if let first = slideSelections.first {
                    duplicateSlide(first)
                }
            }
            .keyboardShortcut("d", modifiers: .command)
            .hidden() // Make the button invisible so it doesn't affect layout
        )
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TopicsChanged"))) { _ in
            print("Debug: Received TopicsChanged notification")
            regenerateSlides()
        }
    }

    private func loadInitialData() {
        // Load current settings from the presentation manager
        self.settings = presentationManager.settings
        // Load slides, prioritizing any existing custom arrangement in PresentationManager
        loadSlides()
    }

    private func loadSlides() {
        print("Debug: Loading slides from topics: \(canvasViewModel.topics.count)")
        
        // First, ensure the presentation manager has up-to-date slides
        presentationManager.updateSlidesFromTopics(canvasViewModel.topics)
        
        // Then check if PresentationManager has an existing customized slide list
        if let existingSlides = presentationManager.activePresentationSlides, !existingSlides.isEmpty {
            self.slideSelections = existingSlides.map { SlideSelection(slide: $0, isSelected: true) }
            print("Debug: Loaded existing custom slide arrangement. Count: \(existingSlides.count)")
        } else {
            // No existing custom list, or it's empty. Generate from topics.
            let allGeneratedSlides = presentationManager.generateSlidesFromTopics(canvasViewModel.topics)
            self.slideSelections = allGeneratedSlides.map { SlideSelection(slide: $0, isSelected: true) }
            print("Debug: Generated new slides from topics. Count: \(allGeneratedSlides.count)")
            // Save this newly generated list as the current custom arrangement
            saveSlideArrangement()
        }
    }

    private func saveSlideArrangement() {
        // Only save if we actually have slides to save
        if !slideSelections.isEmpty {
            let currentSlidesToSave = slideSelections.map { $0.slide }
            presentationManager.activePresentationSlides = currentSlidesToSave
            print("Debug: Saved slide arrangement to PresentationManager. Count: \(currentSlidesToSave.count). First slide (if any): \(currentSlidesToSave.first?.heading ?? "N/A")")
            
            // Post a notification that the presentation slides have been updated
            NotificationCenter.default.post(name: Notification.Name("PresentationSlidesUpdated"), object: nil)
        } else {
            print("Debug: Not saving slide arrangement - no slides available")
        }
    }

    private func moveSlide(from source: IndexSet, to destination: Int) {
        slideSelections.move(fromOffsets: source, toOffset: destination)
        saveSlideArrangement() // Persist changes to PresentationManager
    }

    private func deleteSlides(at offsets: IndexSet) {
        slideSelections.remove(atOffsets: offsets)
        saveSlideArrangement() // Persist changes to PresentationManager
    }

    private func duplicateSlide(_ slideSelectionToDuplicate: SlideSelection) {
        // If Slide is a class, ensure a deep copy is made here.
        // For example, Slide might need a copy() method or a copy initializer:
        // let newSlideData = slideSelectionToDuplicate.slide.copy()
        // If Slide is a struct, direct assignment creates a copy.
        let newSlideData = slideSelectionToDuplicate.slide

        let newSelection = SlideSelection(slide: newSlideData, isSelected: true)
        
        if let index = slideSelections.firstIndex(where: { $0.id == slideSelectionToDuplicate.id }) {
            slideSelections.insert(newSelection, at: index + 1)
        } else {
            slideSelections.append(newSelection)
        }
        saveSlideArrangement() // Persist changes to PresentationManager
    }
    
    private func isDuplicate(_ slide: Slide) -> Bool {
        // Count how many slides have the same heading as this one
        let matchingHeadingCount = slideSelections.filter { $0.slide.heading == slide.heading }.count
        // If there's more than one with this heading, it's a duplicate
        return matchingHeadingCount > 1
    }
    
    private func applyTheme(_ theme: PresentationTheme) {
        // Apply the theme properties to the current settings
        settings.backgroundColor = CodableColor(color: theme.backgroundColor)
        settings.fontColor = CodableColor(color: theme.textColor)
        settings.fontName = theme.fontName
        settings.fontSize = theme.fontSize
        settings.headingFontSize = theme.headingFontSize
        settings.bulletStyle = theme.bulletStyle
        
        // Print debug message
        print("Debug: Applied theme: \(theme.name)")
    }

    private func setupTopicChangeObserver() {
        // Use Combine to observe topic changes in the CanvasViewModel directly
        canvasViewModel.$topics
            .dropFirst() // Skip the initial value
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main) // Add debounce to handle multiple rapid changes
            .sink { topics in
                print("Debug: Detected topic change via Combine. Topic count: \(topics.count)")
                
                // Update the presentation manager's slides directly
                self.presentationManager.updateSlidesFromTopics(topics)
                
                // Then regenerate our view's slides from the updated manager
                self.regenerateSlides()
            }
            .store(in: &cancellables)
    }
    
    private func regenerateSlides() {
        // Print debug before regenerating
        print("Debug: Regenerating slides from \(canvasViewModel.topics.count) topics")
        
        // Get currently selected slide IDs to try to maintain selection
        let selectedSlideHeadings = Set(slideSelections.filter { $0.isSelected }.map { $0.slide.heading })
        
        // Generate fresh slides from current topics
        let newSlides = presentationManager.generateSlidesFromTopics(canvasViewModel.topics)
        print("Debug: Generated \(newSlides.count) new slides")
        
        // Create new slide selections, preserving selection state when possible based on heading matches
        slideSelections = newSlides.map { slide in
            SlideSelection(
                slide: slide,
                isSelected: selectedSlideHeadings.contains(slide.heading)
            )
        }
        
        // If no slides are selected, select them all by default
        if !slideSelections.contains(where: { $0.isSelected }) {
            slideSelections = slideSelections.map { SlideSelection(slide: $0.slide, isSelected: true) }
        }
        
        // Save the updated slide arrangement
        saveSlideArrangement()
    }
}

// Define PresentationTheme enum
enum PresentationTheme: String, CaseIterable {
    case classic = "Classic"
    case modern = "Modern"
    case minimal = "Minimal"
    case dark = "Dark"
    case gradient = "Gradient"
    case nature = "Nature"
    case tech = "Technology"
    case business = "Business"
    
    var name: String {
        return self.rawValue
    }
    
    var backgroundColor: Color {
        switch self {
        case .classic: return Color.white
        case .modern: return Color(red: 0.95, green: 0.95, blue: 0.97)
        case .minimal: return Color(red: 0.98, green: 0.98, blue: 0.98)
        case .dark: return Color(red: 0.15, green: 0.15, blue: 0.18)
        case .gradient: return Color(red: 0.2, green: 0.4, blue: 0.6)
        case .nature: return Color(red: 0.2, green: 0.5, blue: 0.3)
        case .tech: return Color(red: 0.1, green: 0.1, blue: 0.2)
        case .business: return Color(red: 0.95, green: 0.95, blue: 0.95)
        }
    }
    
    var textColor: Color {
        switch self {
        case .classic, .modern, .minimal, .business: return Color.black
        case .dark, .gradient, .nature, .tech: return Color.white
        }
    }
    
    var fontName: String {
        switch self {
        case .classic: return "Helvetica Neue"
        case .modern: return "Arial"
        case .minimal: return "System"
        case .dark: return "Helvetica Neue"
        case .gradient: return "Helvetica Neue"
        case .nature: return "Times New Roman"
        case .tech: return "Courier New"
        case .business: return "Helvetica Neue"
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .minimal: return 14
        case .tech: return 18
        default: return 16
        }
    }
    
    var headingFontSize: CGFloat {
        switch self {
        case .minimal: return 24
        case .tech: return 30
        default: return 28
        }
    }
    
    var bulletStyle: BulletStyle {
        switch self {
        case .classic, .business: return .disc
        case .modern, .gradient: return .dash
        case .minimal: return .circle
        case .dark: return .star
        case .nature: return .square
        case .tech: return .square
        }
    }
}

struct SlideSelection: Identifiable {
    let id = UUID()
    var slide: Slide
    var isSelected: Bool
}

struct SlideSnapshotView: View {
    let slide: Slide
    let settings: PresentationSettings

    var body: some View {
        ZStack {
            settings.backgroundColor.color
            VStack(alignment: .leading, spacing: 4) {
                Text(slide.heading)
                    .font(.system(size: 8, weight: .bold)) // Smaller font for preview
                    .foregroundColor(settings.fontColor.color)
                    .lineLimit(1) // Ensure heading fits

                ForEach(slide.bullets.prefix(2), id: \.self) { bullet in // Show a couple of bullets
                    HStack(alignment: .top, spacing: 2) {
                        Text(settings.bulletStyle.rawValue)
                            .font(.system(size: 6))
                            .foregroundColor(settings.fontColor.color)
                        Text(bullet)
                            .font(.system(size: 6)) // Smaller font for preview
                            .foregroundColor(settings.fontColor.color)
                            .lineLimit(1) // Ensure bullet fits
                    }
                }
                Spacer() // Push content to top
            }
            .padding(4) // Small padding within the snapshot
        }
        .frame(width: 80, height: 60) // Fixed size for the snapshot
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray, lineWidth: 0.5) // Border for the snapshot
        )
    }
}

#if DEBUG
struct PresentationCustomizationView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock services and view models for the preview
        // Ensure these mock initializations are valid and all types are available.
        // If these types themselves are not found, the preview will also fail.
        let mockTopicService = TopicService()
        let mockHistoryService = HistoryService()
        // let mockThemeService = ThemeService() // Removed as it's not an argument for CanvasViewModel
        let mockFileService = FileService() 
        let mockKeyboardService = KeyboardService()
        // let mockSettingsManager = SettingsManager.shared // Removed as SettingsManager is not found and LayoutService init changed
        let mockLayoutService = LayoutService() // Changed: Assumes LayoutService() is a valid initializer

        let mockCanvasViewModel = CanvasViewModel(
            topicService: mockTopicService,
            layoutService: mockLayoutService, // Corrected order
            historyService: mockHistoryService,
            fileService: mockFileService,
            keyboardService: mockKeyboardService
        )

        // Populate mockCanvasViewModel with sample topics for the preview
        // Ensure Topic model is correctly defined and accessible for these lines to work.
        // If 'Topic' is undefined, these will cause errors.
        let topic1ID = UUID()
        let topic2ID = UUID()
        let sampleTopics = [
            Topic(id: topic1ID, name: "Preview Topic 1", position: CGPoint(x: 50, y: 50), subtopics: [
                Topic(name: "Subtopic 1.1", position: CGPoint(x: 150, y: 30), parentId: topic1ID), // Corrected: subtopic name
                Topic(name: "Subtopic 1.2", position: CGPoint(x: 150, y: 70), parentId: topic1ID)
            ]),
            Topic(id: topic2ID, name: "Preview Topic 2", position: CGPoint(x: 50, y: 150)),
            Topic(name: "Preview Topic 3 (No Details)", position: CGPoint(x: 50, y: 250))
        ]
        mockCanvasViewModel.loadTopics(sampleTopics)

        let mockPresentationManager = PresentationManager()
        // Example: mockPresentationManager.settings.backgroundColor = CodableColor(color: .blue)

        return PresentationCustomizationView(isPresented: .constant(true))
            .environmentObject(mockPresentationManager)
            .environmentObject(mockCanvasViewModel)
            .frame(width: 700, height: 550) 
    }
}
#endif
