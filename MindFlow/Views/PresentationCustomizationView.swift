import SwiftUI

// This view assumes PresentationManager, CanvasViewModel, PresentationSettings, Topic,
// and the nested types PresentationManager.Slide and PresentationSettings.BulletStyle
// are defined and accessible from other files in the same module.

struct PresentationCustomizationView: View {
    @EnvironmentObject var presentationManager: PresentationManager
    @EnvironmentObject var canvasViewModel: CanvasViewModel
    @Binding var isPresented: Bool

    @State private var settings: PresentationSettings = PresentationSettings.defaultSettings
    @State private var slideSelections: [SlideSelection] = []

    let fontNames = ["System", "Helvetica Neue", "Arial", "Times New Roman", "Courier New"]

    var body: some View {
        VStack(spacing: 0) {
            Text("Customize Presentation")
                .font(.title2)
                .padding()

            HSplitView {
                // Left Panel: Slide Preview and Selection
                List {
                    ForEach(slideSelections.indices, id: \.self) { index in
                        HStack {
                            Text(slideSelections[index].slide.heading)
                                .lineLimit(1)
                            Spacer()
                            Toggle("", isOn: $slideSelections[index].isSelected)
                                .labelsHidden()
                        }
                    }
                }
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 400)

                ScrollView { // Right Panel: Customization Controls
                    Form {
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
        .onAppear(perform: loadInitialData)
    }

    private func loadInitialData() {
        // Load current settings from the presentation manager
        self.settings = presentationManager.settings
        // Load slides based on current topics in the canvas view model
        loadSlides()
    }

    private func loadSlides() {
        // This function assumes canvasViewModel.topics is populated.
        // It also relies on presentationManager.generateSlidesFromTopics to correctly produce slides.
        let allSlides = presentationManager.generateSlidesFromTopics(canvasViewModel.topics)
        self.slideSelections = allSlides.map { SlideSelection(slide: $0, isSelected: true) }
    }
}

struct SlideSelection: Identifiable {
    var id: UUID { slide.id }
    var slide: Slide // Corrected: Slide is a top-level struct
    var isSelected: Bool
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
