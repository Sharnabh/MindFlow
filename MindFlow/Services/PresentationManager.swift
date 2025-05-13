import SwiftUI

// Represents a slide in the presentation
struct Slide: Identifiable {
    let id = UUID()
    let heading: String
    let bullets: [String]
    let sourceTopicId: UUID? // Original topic that generated this slide
    let childTopics: [Topic] // Child topics for next slides
}

// Handles presentation of mind maps as slides
class PresentationManager: ObservableObject {
    static let shared = PresentationManager()
    
    @Published var isPresenting: Bool = false {
        didSet {
            // When isPresenting changes, trigger the appropriate presentation helper method
            if isPresenting {
                PresentationHelper.shared.enterPresentationMode()
            } else {
                PresentationHelper.shared.exitPresentationMode()
            }
        }
    }
    @Published var slides: [Slide] = []
    @Published var activePresentationSlides: [Slide]? // Added for persisting slide arrangements
    @Published var currentSlideIndex: Int = 0
    @Published var slideTransition: AnyTransition = .opacity
    @Published var settings: PresentationSettings = PresentationSettings.defaultSettings
    
    // Converts a mind map to slides
    func generateSlidesFromTopics(_ topics: [Topic]) -> [Slide] {
        var generatedSlides: [Slide] = []
        
        // Find root topics (those without parents)
        let rootTopics = topics.filter { $0.parentId == nil }
        
        // If there is more than one root topic, add an overview slide first.
        if rootTopics.count > 1 {
            let overviewHeading = "Overview" // Changed heading
            let overviewBullets = rootTopics.map { $0.name }
            let overviewSlide = Slide(
                heading: overviewHeading,
                bullets: overviewBullets,
                sourceTopicId: nil, // Explicitly nil for an overview slide
                childTopics: rootTopics // Children are all root topics for context
            )
            generatedSlides.append(overviewSlide)
        }
        
        // For each root topic, start the recursive slide generation
        for rootTopic in rootTopics {
            createSlidesRecursively(for: rootTopic, into: &generatedSlides)
        }
        
        return generatedSlides
    }
    
    // Recursively creates slides. A slide is created for 'topic' if it has subtopics.
    // Then, recursion continues for each subtopic.
    private func createSlidesRecursively(for topic: Topic, into slides: inout [Slide]) {
        // If the current topic has subtopics, create a slide for it.
        // Its name will be the heading, and its subtopics' names will be the bullets.
        if !topic.subtopics.isEmpty {
            let bullets = topic.subtopics.map { $0.name }
            let slide = Slide(
                heading: topic.name,
                bullets: bullets,
                sourceTopicId: topic.id,
                childTopics: topic.subtopics
            )
            slides.append(slide)
        }
        
        // Regardless of whether a slide was created for the current topic,
        // recurse for all its subtopics. They might have their own subtopics
        // and thus warrant their own slides.
        for subtopic in topic.subtopics {
            createSlidesRecursively(for: subtopic, into: &slides)
        }
    }
    
    // Starts presentation with already generated/selected slides
    func startPresentation(slides: [Slide]) { // Modified to accept slides
        self.slides = slides // Use the provided slides
        self.currentSlideIndex = 0
        // Ensure isPresenting is set to true only if there are slides
        if !self.slides.isEmpty {
            self.isPresenting = true
        } else {
            print("Attempted to start presentation with no slides.")
            self.isPresenting = false
        }
    }
    
    // Navigate to next slide
    func nextSlide() {
        if currentSlideIndex < slides.count - 1 {
            slideTransition = .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
            currentSlideIndex += 1
        }
    }
    
    // Navigate to previous slide
    func previousSlide() {
        if currentSlideIndex > 0 {
            slideTransition = .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
            currentSlideIndex -= 1
        }
    }
    
    // End presentation
    func endPresentation() {
        isPresenting = false
        slides = []
        currentSlideIndex = 0
        
        // Post notification to ensure all components know the presentation has ended
        NotificationCenter.default.post(name: .init("PresentationEnded"), object: nil)
    }
}