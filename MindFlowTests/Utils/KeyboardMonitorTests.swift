import XCTest
@testable import MindFlow
import AppKit
import SwiftUI

// Mock notification center for testing
class MockNotificationCenter: NotificationCenterProtocol {
    var postedNotifications: [(name: NSNotification.Name, object: Any?, userInfo: [AnyHashable: Any]?)] = []
    
    func post(name: NSNotification.Name, object: Any?, userInfo: [AnyHashable: Any]?) {
        postedNotifications.append((name: name, object: object, userInfo: userInfo))
    }
}

class KeyboardMonitorTests: XCTestCase {
    var mockNotificationCenter: MockNotificationCenter!
    var keyboardMonitor: KeyboardMonitor!
    var keyHandlerCalled: Bool = false
    var handledEvent: NSEvent?
    
    override func setUp() {
        super.setUp()
        mockNotificationCenter = MockNotificationCenter()
        keyboardMonitor = KeyboardMonitor(notificationCenter: mockNotificationCenter)
        keyHandlerCalled = false
        handledEvent = nil
        
        // Set up key handler
        keyboardMonitor.keyHandler = { [weak self] event in
            self?.keyHandlerCalled = true
            self?.handledEvent = event
        }
    }
    
    override func tearDown() {
        keyboardMonitor.stopMonitoring()
        mockNotificationCenter = nil
        keyboardMonitor = nil
        super.tearDown()
    }
    
    // Helper to check if a notification was posted
    private func wasNotificationPosted(named name: NSNotification.Name) -> Bool {
        return mockNotificationCenter.postedNotifications.contains { $0.name == name }
    }
    
    // Helper to get event from the userInfo of a posted notification
    private func getEventFromNotification(named name: NSNotification.Name) -> NSEvent? {
        let notification = mockNotificationCenter.postedNotifications.first { $0.name == name }
        return notification?.userInfo?["event"] as? NSEvent
    }
    
    // Test handling return key
    func testHandleReturnKey() {
        // Mocking NSEvent.keyDown is challenging in tests since it's a system event
        // Typically, you would test whether the keyHandler is called and 
        // notifications are posted, which we can do without real events
        
        // When someone invokes the keyHandler with a return key event
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: KeyCode.returnKey
        )!
        
        // We can call the handler directly and verify our notification-related logic
        keyboardMonitor.keyHandler?(event)
        
        // Then a notification should be posted
        XCTAssertTrue(wasNotificationPosted(named: .returnKeyPressed))
        XCTAssertEqual(getEventFromNotification(named: .returnKeyPressed)?.keyCode, KeyCode.returnKey)
    }
    
    // Test handling undo key combination (Cmd+Z)
    func testHandleUndoKeyCombination() {
        // When someone invokes the keyHandler with Cmd+Z
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: KeyCode.zKey
        )!
        
        keyboardMonitor.keyHandler?(event)
        
        // Then an undo notification should be posted
        XCTAssertTrue(wasNotificationPosted(named: .undoRequested))
        XCTAssertEqual(getEventFromNotification(named: .undoRequested)?.keyCode, KeyCode.zKey)
    }
    
    // Test handling redo key combination (Cmd+Shift+Z)
    func testHandleRedoKeyCombination() {
        // When someone invokes the keyHandler with Cmd+Shift+Z
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "Z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: KeyCode.zKey
        )!
        
        keyboardMonitor.keyHandler?(event)
        
        // Then a redo notification should be posted
        XCTAssertTrue(wasNotificationPosted(named: .redoRequested))
        XCTAssertEqual(getEventFromNotification(named: .redoRequested)?.keyCode, KeyCode.zKey)
    }
} 