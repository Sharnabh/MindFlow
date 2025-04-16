import XCTest
@testable import MindFlow
import SwiftUI
import AppKit

// Mock logger for testing
class MockLogger: LoggerProtocol {
    var debugMessages: [String] = []
    var errorMessages: [String] = []
    
    func debug(_ message: String) {
        debugMessages.append(message)
    }
    
    func error(_ message: String) {
        errorMessages.append(message)
    }
}

// Mock CanvasViewModel for testing
class MockCanvasViewModel: ObservableObject {
    @Published var selectedTopicId: UUID? = nil
    @Published var topicDeletedId: UUID? = nil
    @Published var topicAddedAt: CGPoint? = nil
    @Published var topicEditingId: UUID? = nil
    @Published var topicCollapsedId: UUID? = nil
    @Published var subtopicAddedTo: UUID? = nil
    var shouldBlockKeyboardShortcuts: Bool = false
    
    func deleteTopic(withId id: UUID) {
        topicDeletedId = id
    }
    
    func addMainTopic(at position: CGPoint) {
        topicAddedAt = position
    }
    
    func beginEditingTopic(withId id: UUID) {
        topicEditingId = id
    }
    
    func collapseExpandTopic(withId id: UUID) {
        topicCollapsedId = id
    }
    
    func addSubtopic(to id: UUID) {
        subtopicAddedTo = id
    }
}

class KeyboardServiceTests: XCTestCase {
    var mockLogger: MockLogger!
    var keyboardService: KeyboardService!
    var mockViewModel: MockCanvasViewModel!
    
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        keyboardService = KeyboardService(logger: mockLogger)
        mockViewModel = MockCanvasViewModel()
    }
    
    override func tearDown() {
        mockLogger = nil
        keyboardService = nil
        mockViewModel = nil
        super.tearDown()
    }
    
    // Helper to create a mock key event
    private func createKeyEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )!
    }
    
    // Test handling delete key
    func testHandleDeleteKey() {
        // Given
        let testId = UUID()
        mockViewModel.selectedTopicId = testId
        let position = CGPoint(x: 100, y: 100)
        let event = createKeyEvent(keyCode: KeyCode.deleteKey)
        
        // When
        keyboardService.handleKeyPress(event, at: position, canvasViewModel: mockViewModel)
        
        // Then
        XCTAssertEqual(mockViewModel.topicDeletedId, testId)
        XCTAssertTrue(mockLogger.debugMessages.contains { 
            $0.contains("Delete key pressed - removing topic with ID: \(testId)")
        })
    }
    
    // Test handling return key
    func testHandleReturnKey() {
        // Given
        let position = CGPoint(x: 100, y: 100)
        let event = createKeyEvent(keyCode: KeyCode.returnKey)
        
        // When
        keyboardService.handleKeyPress(event, at: position, canvasViewModel: mockViewModel)
        
        // Then
        XCTAssertEqual(mockViewModel.topicAddedAt, position)
        XCTAssertTrue(mockLogger.debugMessages.contains { 
            $0.contains("Return key pressed - adding main topic at position: \(position)")
        })
    }
    
    // Test handling space key
    func testHandleSpaceKey() {
        // Given
        let testId = UUID()
        mockViewModel.selectedTopicId = testId
        let position = CGPoint(x: 100, y: 100)
        let event = createKeyEvent(keyCode: KeyCode.spaceKey)
        
        // When
        keyboardService.handleKeyPress(event, at: position, canvasViewModel: mockViewModel)
        
        // Then
        XCTAssertEqual(mockViewModel.topicEditingId, testId)
        XCTAssertTrue(mockLogger.debugMessages.contains { 
            $0.contains("Space pressed - beginning editing for topic: \(testId)")
        })
    }
    
    // Test handling Control+Space key
    func testHandleControlSpaceKey() {
        // Given
        let testId = UUID()
        mockViewModel.selectedTopicId = testId
        let position = CGPoint(x: 100, y: 100)
        let event = createKeyEvent(keyCode: KeyCode.spaceKey, modifiers: .control)
        
        // When
        keyboardService.handleKeyPress(event, at: position, canvasViewModel: mockViewModel)
        
        // Then
        XCTAssertEqual(mockViewModel.topicCollapsedId, testId)
        XCTAssertTrue(mockLogger.debugMessages.contains { 
            $0.contains("Control+Space pressed - toggling collapsed state for topic: \(testId)")
        })
    }
    
    // Test handling Tab key
    func testHandleTabKey() {
        // Given
        let testId = UUID()
        mockViewModel.selectedTopicId = testId
        let position = CGPoint(x: 100, y: 100)
        let event = createKeyEvent(keyCode: KeyCode.tabKey)
        
        // When
        keyboardService.handleKeyPress(event, at: position, canvasViewModel: mockViewModel)
        
        // Then
        XCTAssertEqual(mockViewModel.subtopicAddedTo, testId)
        XCTAssertTrue(mockLogger.debugMessages.contains { 
            $0.contains("Tab pressed - adding subtopic to: \(testId)")
        })
    }
    
    // Test ignoring keyboard events when text input is active
    func testIgnoreKeyboardEventsWhenTextInputActive() {
        // Given
        keyboardService.startTextInput()
        let testId = UUID()
        mockViewModel.selectedTopicId = testId
        let position = CGPoint(x: 100, y: 100)
        let event = createKeyEvent(keyCode: KeyCode.deleteKey)
        
        // When
        keyboardService.handleKeyPress(event, at: position, canvasViewModel: mockViewModel)
        
        // Then
        XCTAssertNil(mockViewModel.topicDeletedId)
        XCTAssertTrue(mockLogger.debugMessages.contains { 
            $0.contains("Ignoring keyboard event due to active text input or editing state")
        })
    }
    
    // Test ignoring keyboard events when view model is blocking shortcuts
    func testIgnoreKeyboardEventsWhenViewModelBlockingShortcuts() {
        // Given
        mockViewModel.shouldBlockKeyboardShortcuts = true
        let testId = UUID()
        mockViewModel.selectedTopicId = testId
        let position = CGPoint(x: 100, y: 100)
        let event = createKeyEvent(keyCode: KeyCode.deleteKey)
        
        // When
        keyboardService.handleKeyPress(event, at: position, canvasViewModel: mockViewModel)
        
        // Then
        XCTAssertNil(mockViewModel.topicDeletedId)
        XCTAssertTrue(mockLogger.debugMessages.contains { 
            $0.contains("Ignoring keyboard event due to active text input or editing state")
        })
    }
} 