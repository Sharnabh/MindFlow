import SwiftUI

// Reusable components
struct SidebarSection: View {
    let title: String
    let content: AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .foregroundColor(.primary)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            AnyView(content)
        }
    }
}

struct ColorPickerButton: View {
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 50, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Main SidebarView
struct SidebarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isSidebarOpen: Bool
    @Binding var sidebarMode: SidebarMode
    @Binding var backgroundStyle: BackgroundStyle
    @Binding var backgroundColor: Color
    @Binding var backgroundOpacity: Double
    @Binding var isShowingColorPicker: Bool
    @Binding var isShowingBorderColorPicker: Bool
    @Binding var isShowingForegroundColorPicker: Bool
    @Binding var isShowingBackgroundColorPicker: Bool
    @Binding var isRelationshipMode: Bool
    @Binding var isCircularRelationshipMode: Bool
    @Binding var isSquaredRelationshipMode: Bool
    @Binding var sidebarWidth: CGFloat
    
    private let topBarHeight: CGFloat = 40
    private let minSidebarWidth: CGFloat = 220
    private let maxSidebarWidth: CGFloat = 600
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: topBarHeight)
            
            HStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.windowBackgroundColor))
                        .frame(width: sidebarWidth)
                        .overlay(
                            VStack(spacing: 16) {
                                // Mode selector
                                Picker("", selection: $sidebarMode) {
                                    Text("Style").tag(SidebarMode.style)
                                    Text("Map").tag(SidebarMode.map)
                                    Text("AI").tag(SidebarMode.ai)
                                    Text("Collaborate").tag(SidebarMode.collaboration)
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal)
                                .padding(.top, 12)
                                
                                Divider()
                                    .padding(.horizontal)
                                
                                if sidebarMode == .style {
                                    StyleModeContent(
                                        viewModel: viewModel,
                                        isShowingColorPicker: $isShowingColorPicker,
                                        isShowingBorderColorPicker: $isShowingBorderColorPicker,
                                        isShowingForegroundColorPicker: $isShowingForegroundColorPicker,
                                        isCircularRelationshipMode: $isCircularRelationshipMode,
                                        isSquaredRelationshipMode: $isSquaredRelationshipMode
                                    )
                                } else if sidebarMode == .map {
                                    MapModeContent(
                                        viewModel: viewModel,
                                        backgroundStyle: $backgroundStyle,
                                        backgroundColor: $backgroundColor,
                                        backgroundOpacity: $backgroundOpacity,
                                        isShowingBackgroundColorPicker: $isShowingBackgroundColorPicker,
                                        isRelationshipMode: $isRelationshipMode,
                                        isCircularRelationshipMode: $isCircularRelationshipMode,
                                        isSquaredRelationshipMode: $isSquaredRelationshipMode
                                    )
                                } else if sidebarMode == .ai {
                                    AIModeContent(viewModel: viewModel)
                                } else if sidebarMode == .collaboration {
                                    CollaborationModeContent(viewModel: viewModel)
                                }
                                
                                Spacer(minLength: 20)
                            }
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: -1, y: 0)
                        .gesture(
                            // Consume drag gestures to prevent canvas from moving when dragging on sidebar
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in }
                                .onEnded { _ in }
                        )
                    // Drag handle for resizing - positioned on the left
                    DragHandleView(
                        sidebarWidth: $sidebarWidth,
                        minSidebarWidth: minSidebarWidth,
                        maxSidebarWidth: maxSidebarWidth
                    )
                }
            }
        }
    }
}

// Style mode content
private struct StyleModeContent: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isShowingColorPicker: Bool
    @Binding var isShowingBorderColorPicker: Bool
    @Binding var isShowingForegroundColorPicker: Bool
    @Binding var isCircularRelationshipMode: Bool
    @Binding var isSquaredRelationshipMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if let selectedTopic = viewModel.getSelectedTopic() {
                TopicStyleSection(
                    viewModel: viewModel,
                    selectedTopic: selectedTopic,
                    isShowingColorPicker: $isShowingColorPicker,
                    isShowingBorderColorPicker: $isShowingBorderColorPicker
                )
                
                TextStyleSection(
                    viewModel: viewModel,
                    selectedTopic: selectedTopic,
                    isShowingForegroundColorPicker: $isShowingForegroundColorPicker
                )
                
                BranchStyleSection(viewModel: viewModel, selectedTopic: selectedTopic, isCircularRelationshipMode: $isCircularRelationshipMode, isSquaredRelationshipMode: $isSquaredRelationshipMode)
            } else {
                Text("Select a topic to edit its properties")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

// Map mode content
private struct MapModeContent: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var backgroundStyle: BackgroundStyle
    @Binding var backgroundColor: Color
    @Binding var backgroundOpacity: Double
    @Binding var isShowingBackgroundColorPicker: Bool
    @Binding var isRelationshipMode: Bool
    @Binding var isCircularRelationshipMode: Bool
    @Binding var isSquaredRelationshipMode: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                BackgroundSection(
                    backgroundStyle: $backgroundStyle,
                    backgroundColor: $backgroundColor,
                    backgroundOpacity: $backgroundOpacity,
                    isShowingBackgroundColorPicker: $isShowingBackgroundColorPicker,
                    viewModel: viewModel
                )
                
                AutoLayoutSection()
                ThemeSection(viewModel: viewModel)
            }
        }
    }
}

// Collaboration mode content
private struct CollaborationModeContent: View {
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Collaboration Features")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Status:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("✅ Your documents are saved to iCloud")
                    Text("✅ Auto-sync across your devices")
                    Text("⏳ Real-time collaboration coming soon")
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's Next:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("🚀 Share documents with others")
                    Text("👥 Live collaborative editing")
                    Text("💬 Real-time comments")
                    Text("📱 Cross-platform support")
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

// MARK: - Theme Management
private func applyTheme(
    backgroundColor: Color,
    backgroundStyle: BackgroundStyle,
    topicFillColor: Color,
    topicBorderColor: Color,
    topicTextColor: Color,
    themeName: String = ""
) {
    // ... existing implementation ...
}

// MARK: - Drag Handle Component
private struct DragHandleView: View {
    @Binding var sidebarWidth: CGFloat
    let minSidebarWidth: CGFloat
    let maxSidebarWidth: CGFloat
    
    @State private var isHovering = false
    @State private var isDragging = false
    
    var body: some View {
        Rectangle()
            .fill(handleColor)
            .frame(width: handleWidth)
            .overlay(
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let newWidth = sidebarWidth - value.translation.width
                        sidebarWidth = min(max(newWidth, minSidebarWidth), maxSidebarWidth)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
                
                // Change cursor on hover (macOS)
                #if os(macOS)
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
                #endif
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
    }
    
    private var handleColor: Color {
        if isDragging {
            return Color.blue.opacity(0.6)
        } else if isHovering {
            return Color.gray.opacity(0.5)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private var accentColor: Color {
        if isDragging {
            return Color.blue.opacity(0.9)
        } else if isHovering {
            return Color.blue.opacity(0.8)
        } else {
            return Color.blue.opacity(0.6)
        }
    }
    
    private var handleWidth: CGFloat {
        isDragging ? 6 : (isHovering ? 5 : 4)
    }
}

