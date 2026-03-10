//
//  TipKitManager.swift
//  MindFlow
//
//  Created by Assistant on 14/03/25.
//

import SwiftUI
import TipKit

// MARK: - TipKit Manager
class TipKitManager: ObservableObject {
    static let shared = TipKitManager()
    
    private init() {
        configureTipKit()
    }
    
    private func configureTipKit() {
        // Configure TipKit with iCloud sync
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }
}

// MARK: - Onboarding Tips

struct WelcomeTip: Tip {
    var title: Text {
        Text("Welcome to MindFlow!")
    }
    
    var message: Text? {
        Text("Create beautiful mind maps and organize your thoughts. Let's get you started!")
    }
    
    var image: Image? {
        Image(systemName: "brain.head.profile")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'app_launch'")
    }
}

struct CanvasNavigationTip: Tip {
    var title: Text {
        Text("Navigate Your Canvas")
    }
    
    var message: Text? {
        Text("Drag to pan around your mind map, use pinch gestures or scroll to zoom in and out. The minimap in the top-right helps you navigate large maps.")
    }
    
    var image: Image? {
        Image(systemName: "hand.draw")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'first_topic_created'")
    }
}

struct TopicCreationTip: Tip {
    var title: Text {
        Text("Create Your First Topic")
    }
    
    var message: Text? {
        Text("Double-click anywhere on the canvas or press Enter to create a new topic. Type to add your content!")
    }
    
    var image: Image? {
        Image(systemName: "plus.circle")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'canvas_interaction'")
    }
}

struct SidebarDiscoveryTip: Tip {
    var title: Text {
        Text("Discover the Sidebar")
    }
    
    var message: Text? {
        Text("Click the sidebar button to access styling options, AI assistant, and advanced features. The sidebar is your control center!")
    }
    
    var image: Image? {
        Image(systemName: "sidebar.left")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'sidebar_opened'")
    }
}

// MARK: - AI Assistant Tips

struct AIAssistantTip: Tip {
    var title: Text {
        Text("AI-Powered Ideas")
    }
    
    var message: Text? {
        Text("Switch to AI mode in the sidebar to generate new ideas, organize topics, and get creative suggestions. Set up your API key first!")
    }
    
    var image: Image? {
        Image(systemName: "brain.head.profile")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'ai_mode_accessed'")
    }
}

struct APIKeySetupTip: Tip {
    var title: Text {
        Text("Set Up AI Assistant")
    }
    
    var message: Text? {
        Text("To use the AI features, you'll need a Gemini API key. Click 'Set API Key' to get started with AI-powered mind mapping.")
    }
    
    var image: Image? {
        Image(systemName: "key")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'ai_mode_without_key'")
    }
}

// MARK: - Collaboration Tips

struct CollaborationTip: Tip {
    var title: Text {
        Text("Real-Time Collaboration")
    }
    
    var message: Text? {
        Text("Share your mind maps with others and collaborate in real-time. See live cursors and changes as they happen!")
    }
    
    var image: Image? {
        Image(systemName: "person.2")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'collaboration_available'")
    }
}

struct SharingTip: Tip {
    var title: Text {
        Text("Share Your Mind Map")
    }
    
    var message: Text? {
        Text("Use the share button to invite others to collaborate on your mind map. They'll see your changes in real-time!")
    }
    
    var image: Image? {
        Image(systemName: "square.and.arrow.up")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'share_initiated'")
    }
}

// MARK: - Advanced Feature Tips

struct RelationshipModeTip: Tip {
    var title: Text {
        Text("Create Connections")
    }
    
    var message: Text? {
        Text("Enable relationship mode to draw connections between topics. Choose from straight, curved, or squared lines to show different relationships.")
    }
    
    var image: Image? {
        Image(systemName: "arrow.triangle.branch")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'relationship_mode_enabled'")
    }
}

struct KeyboardShortcutsTip: Tip {
    var title: Text {
        Text("Keyboard Shortcuts")
    }
    
    var message: Text? {
        Text("Speed up your workflow! Cmd+N for new map, Cmd+S to save, Cmd+E to export, and many more. Check the menu for all shortcuts.")
    }
    
    var image: Image? {
        Image(systemName: "keyboard")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'keyboard_shortcut_used'")
    }
}

struct ExportTip: Tip {
    var title: Text {
        Text("Export Your Work")
    }
    
    var message: Text? {
        Text("Export your mind maps as images or PDFs. Perfect for presentations, reports, or sharing with others who don't have MindFlow.")
    }
    
    var image: Image? {
        Image(systemName: "square.and.arrow.down")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'export_initiated'")
    }
}

struct PresentationModeTip: Tip {
    var title: Text {
        Text("Presentation Mode")
    }
    
    var message: Text? {
        Text("Transform your mind map into a presentation! Use the presentation button to create slides and present your ideas professionally.")
    }
    
    var image: Image? {
        Image(systemName: "presentation")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'presentation_mode_accessed'")
    }
}

// MARK: - Styling Tips

struct ThemeTip: Tip {
    var title: Text {
        Text("Apply Themes")
    }
    
    var message: Text? {
        Text("Choose from beautiful pre-designed themes or create your own. Themes apply consistent colors and styles across your entire mind map.")
    }
    
    var image: Image? {
        Image(systemName: "paintpalette")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'theme_section_opened'")
    }
}

struct ColorCustomizationTip: Tip {
    var title: Text {
        Text("Customize Colors")
    }
    
    var message: Text? {
        Text("Make your mind map unique! Change topic colors, borders, and text colors. Select a topic and use the color picker in the sidebar.")
    }
    
    var image: Image? {
        Image(systemName: "paintbrush")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'color_picker_opened'")
    }
}

// MARK: - Power User Tips

struct MinimapTip: Tip {
    var title: Text {
        Text("Use the Minimap")
    }
    
    var message: Text? {
        Text("The minimap shows your entire mind map at a glance. Click anywhere on it to quickly navigate to that area of your canvas.")
    }
    
    var image: Image? {
        Image(systemName: "map")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'minimap_interaction'")
    }
}

struct UndoRedoTip: Tip {
    var title: Text {
        Text("Undo & Redo")
    }
    
    var message: Text? {
        Text("Made a mistake? Use Cmd+Z to undo or Cmd+Shift+Z to redo. Your changes are automatically saved as you work.")
    }
    
    var image: Image? {
        Image(systemName: "arrow.uturn.backward")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'undo_used'")
    }
}

struct AutoLayoutTip: Tip {
    var title: Text {
        Text("Auto-Layout")
    }
    
    var message: Text? {
        Text("Let MindFlow organize your topics automatically! Use the auto-layout feature to create clean, structured mind maps.")
    }
    
    var image: Image? {
        Image(systemName: "arrow.triangle.branch")
    }
    
    var rules: [Rule] {
        #Rule("$event == 'auto_layout_accessed'")
    }
}

// MARK: - Event Tracking

extension TipKitManager {
    func trackEvent(_ event: String) {
        // Track events for tip triggers
        Task {
            await Tips.recordEvent("$event == '\(event)'")
        }
    }
    
    func trackAppLaunch() {
        trackEvent("app_launch")
    }
    
    func trackFirstTopicCreated() {
        trackEvent("first_topic_created")
    }
    
    func trackCanvasInteraction() {
        trackEvent("canvas_interaction")
    }
    
    func trackSidebarOpened() {
        trackEvent("sidebar_opened")
    }
    
    func trackAIModeAccessed() {
        trackEvent("ai_mode_accessed")
    }
    
    func trackAIModeWithoutKey() {
        trackEvent("ai_mode_without_key")
    }
    
    func trackCollaborationAvailable() {
        trackEvent("collaboration_available")
    }
    
    func trackShareInitiated() {
        trackEvent("share_initiated")
    }
    
    func trackRelationshipModeEnabled() {
        trackEvent("relationship_mode_enabled")
    }
    
    func trackKeyboardShortcutUsed() {
        trackEvent("keyboard_shortcut_used")
    }
    
    func trackExportInitiated() {
        trackEvent("export_initiated")
    }
    
    func trackPresentationModeAccessed() {
        trackEvent("presentation_mode_accessed")
    }
    
    func trackThemeSectionOpened() {
        trackEvent("theme_section_opened")
    }
    
    func trackColorPickerOpened() {
        trackEvent("color_picker_opened")
    }
    
    func trackMinimapInteraction() {
        trackEvent("minimap_interaction")
    }
    
    func trackUndoUsed() {
        trackEvent("undo_used")
    }
    
    func trackAutoLayoutAccessed() {
        trackEvent("auto_layout_accessed")
    }
}