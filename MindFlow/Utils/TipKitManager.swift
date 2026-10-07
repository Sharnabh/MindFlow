//
//  TipKitManager.swift
//  MindFlow
//
//  Created by Assistant on 14/03/25.
//

import SwiftUI
import TipKit

typealias Event = Tips.Event

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

// MARK: - TipKit Events

struct TipKitEvents {
    static let appLaunch = Event(id: "app_launch")
    static let firstTopicCreated = Event(id: "first_topic_created")
    static let canvasInteraction = Event(id: "canvas_interaction")
    static let sidebarOpened = Event(id: "sidebar_opened")
    static let aiModeAccessed = Event(id: "ai_mode_accessed")
    static let aiModeWithoutKey = Event(id: "ai_mode_without_key")
    static let collaborationAvailable = Event(id: "collaboration_available")
    static let shareInitiated = Event(id: "share_initiated")
    static let relationshipModeEnabled = Event(id: "relationship_mode_enabled")
    static let keyboardShortcutUsed = Event(id: "keyboard_shortcut_used")
    static let exportInitiated = Event(id: "export_initiated")
    static let presentationModeAccessed = Event(id: "presentation_mode_accessed")
    static let themeSectionOpened = Event(id: "theme_section_opened")
    static let colorPickerOpened = Event(id: "color_picker_opened")
    static let minimapInteraction = Event(id: "minimap_interaction")
    static let undoUsed = Event(id: "undo_used")
    static let autoLayoutAccessed = Event(id: "auto_layout_accessed")
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
        #Rule(TipKitEvents.appLaunch) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.firstTopicCreated) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.canvasInteraction) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.sidebarOpened) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.aiModeAccessed) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.aiModeWithoutKey) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.collaborationAvailable) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.shareInitiated) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.relationshipModeEnabled) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.keyboardShortcutUsed) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.exportInitiated) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.presentationModeAccessed) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.themeSectionOpened) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.colorPickerOpened) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.minimapInteraction) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.undoUsed) {
            $0.donations.count >= 1
        }
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
        #Rule(TipKitEvents.autoLayoutAccessed) {
            $0.donations.count >= 1
        }
    }
}

// MARK: - Event Tracking

extension TipKitManager {
    func trackEvent(_ event: String) {
        Task {
            switch event {
            case "app_launch":
                await TipKitEvents.appLaunch.donate()
            case "first_topic_created":
                await TipKitEvents.firstTopicCreated.donate()
            case "canvas_interaction":
                await TipKitEvents.canvasInteraction.donate()
            case "sidebar_opened":
                await TipKitEvents.sidebarOpened.donate()
            case "ai_mode_accessed":
                await TipKitEvents.aiModeAccessed.donate()
            case "ai_mode_without_key":
                await TipKitEvents.aiModeWithoutKey.donate()
            case "collaboration_available":
                await TipKitEvents.collaborationAvailable.donate()
            case "share_initiated":
                await TipKitEvents.shareInitiated.donate()
            case "relationship_mode_enabled":
                await TipKitEvents.relationshipModeEnabled.donate()
            case "keyboard_shortcut_used":
                await TipKitEvents.keyboardShortcutUsed.donate()
            case "export_initiated":
                await TipKitEvents.exportInitiated.donate()
            case "presentation_mode_accessed":
                await TipKitEvents.presentationModeAccessed.donate()
            case "theme_section_opened":
                await TipKitEvents.themeSectionOpened.donate()
            case "color_picker_opened":
                await TipKitEvents.colorPickerOpened.donate()
            case "minimap_interaction":
                await TipKitEvents.minimapInteraction.donate()
            case "undo_used":
                await TipKitEvents.undoUsed.donate()
            case "auto_layout_accessed":
                await TipKitEvents.autoLayoutAccessed.donate()
            default:
                break
            }
        }
    }
    
    func trackAppLaunch() {
        Task { await TipKitEvents.appLaunch.donate() }
    }
    
    func trackFirstTopicCreated() {
        Task { await TipKitEvents.firstTopicCreated.donate() }
    }
    
    func trackCanvasInteraction() {
        Task { await TipKitEvents.canvasInteraction.donate() }
    }
    
    func trackSidebarOpened() {
        Task { await TipKitEvents.sidebarOpened.donate() }
    }
    
    func trackAIModeAccessed() {
        Task { await TipKitEvents.aiModeAccessed.donate() }
    }
    
    func trackAIModeWithoutKey() {
        Task { await TipKitEvents.aiModeWithoutKey.donate() }
    }
    
    func trackCollaborationAvailable() {
        Task { await TipKitEvents.collaborationAvailable.donate() }
    }
    
    func trackShareInitiated() {
        Task { await TipKitEvents.shareInitiated.donate() }
    }
    
    func trackRelationshipModeEnabled() {
        Task { await TipKitEvents.relationshipModeEnabled.donate() }
    }
    
    func trackKeyboardShortcutUsed() {
        Task { await TipKitEvents.keyboardShortcutUsed.donate() }
    }
    
    func trackExportInitiated() {
        Task { await TipKitEvents.exportInitiated.donate() }
    }
    
    func trackPresentationModeAccessed() {
        Task { await TipKitEvents.presentationModeAccessed.donate() }
    }
    
    func trackThemeSectionOpened() {
        Task { await TipKitEvents.themeSectionOpened.donate() }
    }
    
    func trackColorPickerOpened() {
        Task { await TipKitEvents.colorPickerOpened.donate() }
    }
    
    func trackMinimapInteraction() {
        Task { await TipKitEvents.minimapInteraction.donate() }
    }
    
    func trackUndoUsed() {
        Task { await TipKitEvents.undoUsed.donate() }
    }
    
    func trackAutoLayoutAccessed() {
        Task { await TipKitEvents.autoLayoutAccessed.donate() }
    }
}