//
//  TipViews.swift
//  MindFlow
//
//  Created by Assistant on 14/03/25.
//

import SwiftUI
import TipKit

// MARK: - Tip View Modifiers

extension View {
    /// Add a tip to any view with custom positioning
    func tipView<T: Tip>(_ tip: T, placement: TipViewPlacement = .automatic) -> some View {
        self.popoverTip(tip, placement: placement)
    }
    
    /// Add a tip with custom arrow edge
    func tipView<T: Tip>(_ tip: T, arrowEdge: Edge) -> some View {
        self.popoverTip(tip, arrowEdge: arrowEdge)
    }
}

// MARK: - Custom Tip View Components

struct WelcomeTipView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Welcome to MindFlow!")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("Create beautiful mind maps and organize your thoughts. Let's get you started!")
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                Spacer()
                Button("Get Started") {
                    // Dismiss tip
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: 300)
    }
}

struct CanvasNavigationTipView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.draw")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Navigate Your Canvas")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "hand.point.up")
                        .foregroundColor(.blue)
                    Text("Drag to pan around")
                        .font(.body)
                }
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                    Text("Pinch or scroll to zoom")
                        .font(.body)
                }
                
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(.blue)
                    Text("Use minimap for quick navigation")
                        .font(.body)
                }
            }
        }
        .padding()
        .frame(maxWidth: 300)
    }
}

struct AIAssistantTipView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("AI-Powered Ideas")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("Switch to AI mode in the sidebar to generate new ideas, organize topics, and get creative suggestions.")
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "sidebar.left")
                    .foregroundColor(.blue)
                Text("Open sidebar → Switch to AI mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: 300)
    }
}

struct CollaborationTipView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Real-Time Collaboration")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("Share your mind maps with others and collaborate in real-time. See live cursors and changes as they happen!")
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
                Text("Use the share button to invite others")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: 300)
    }
}

// MARK: - Tip Container Views

struct TipContainerView<Content: View>: View {
    let content: Content
    let tip: any Tip
    let placement: TipViewPlacement
    
    init(@ViewBuilder content: () -> Content, tip: any Tip, placement: TipViewPlacement = .automatic) {
        self.content = content()
        self.tip = tip
        self.placement = placement
    }
    
    var body: some View {
        content
            .popoverTip(tip, placement: placement)
    }
}

// MARK: - Conditional Tip Views

struct ConditionalTipView<Content: View, T: Tip>: View {
    let content: Content
    let tip: T
    let condition: Bool
    let placement: TipViewPlacement
    
    init(@ViewBuilder content: () -> Content, tip: T, condition: Bool, placement: TipViewPlacement = .automatic) {
        self.content = content()
        self.tip = tip
        self.condition = condition
        self.placement = placement
    }
    
    var body: some View {
        if condition {
            content
                .popoverTip(tip, placement: placement)
        } else {
            content
        }
    }
}

// MARK: - Tip Button Styles

struct TipButtonStyle: ButtonStyle {
    let isHighlighted: Bool
    
    init(isHighlighted: Bool = false) {
        self.isHighlighted = isHighlighted
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? Color.blue.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHighlighted ? Color.blue : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Tip Progress Indicator

struct TipProgressView: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index < currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.1))
        )
    }
}

// MARK: - Tip Dismissal Handler

class TipDismissalHandler: ObservableObject {
    @Published var dismissedTips: Set<String> = []
    
    func dismissTip(_ tipId: String) {
        dismissedTips.insert(tipId)
    }
    
    func isTipDismissed(_ tipId: String) -> Bool {
        dismissedTips.contains(tipId)
    }
    
    func resetDismissedTips() {
        dismissedTips.removeAll()
    }
}

// MARK: - Tip Analytics

struct TipAnalytics {
    static func trackTipShown(_ tipId: String) {
        // Track tip shown event
        print("Tip shown: \(tipId)")
    }
    
    static func trackTipDismissed(_ tipId: String) {
        // Track tip dismissed event
        print("Tip dismissed: \(tipId)")
    }
    
    static func trackTipAction(_ tipId: String, action: String) {
        // Track tip action event
        print("Tip action: \(tipId) - \(action)")
    }
}

