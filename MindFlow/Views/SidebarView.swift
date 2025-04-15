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
    
    private let topBarHeight: CGFloat = 40
    private let sidebarWidth: CGFloat = 300
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: topBarHeight)
            
            HStack(spacing: 0) {
                Spacer()
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
                                    isShowingForegroundColorPicker: $isShowingForegroundColorPicker
                                )
                            } else if sidebarMode == .map {
                                MapModeContent(
                                    viewModel: viewModel,
                                    backgroundStyle: $backgroundStyle,
                                    backgroundColor: $backgroundColor,
                                    backgroundOpacity: $backgroundOpacity,
                                    isShowingBackgroundColorPicker: $isShowingBackgroundColorPicker
                                )
                            } else {
                                AIModeContent(viewModel: viewModel)
                            }
                            
                            Spacer(minLength: 20)
                        }
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: -1, y: 0)
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
                
                BranchStyleSection(viewModel: viewModel, selectedTopic: selectedTopic)
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

// MARK: - CanvasViewModel Extension
extension CanvasViewModel {
    func addTopicHierarchyAsSubtopics(parentTopic: Topic, parentTopics: [TopicWithReason]) {
        // Save current state for undo
        saveState()
        
        // Process all selected parent topics
        let selectedParentTopics = parentTopics.filter { $0.isSelected }
        
        // If no topics are selected, there's nothing to do
        if selectedParentTopics.isEmpty {
            return
        }
        
        // Get the current version of the parent topic using public API
        guard let currentParentTopic = findTopic(id: parentTopic.id) else {
            return
        }
        
        // Create a mutable copy of the parent topic
        var updatedParentTopic = currentParentTopic
        
        // Add all selected topics as subtopics
        for parentTopicWithReason in selectedParentTopics {
            // Create new subtopic based on selected parent topic
            let subtopicCount = updatedParentTopic.subtopics.count
            let subtopicPosition = calculateNewSubtopicPosition(for: updatedParentTopic, subtopicCount: subtopicCount)
            
            var newSubtopic = updatedParentTopic.createSubtopic(at: subtopicPosition, count: subtopicCount + 1)
            newSubtopic.name = parentTopicWithReason.name
            
            // Add all selected children under this new subtopic
            for childTopic in parentTopicWithReason.children where childTopic.isSelected {
                let childCount = newSubtopic.subtopics.count
                let childPosition = calculateNewSubtopicPosition(for: newSubtopic, subtopicCount: childCount)
                
                var newChildTopic = newSubtopic.createSubtopic(at: childPosition, count: childCount + 1)
                newChildTopic.name = childTopic.name
                newSubtopic.subtopics.append(newChildTopic)
            }
            
            // Add the new subtopic to our updated parent
            updatedParentTopic.subtopics.append(newSubtopic)
        }
        
        // Update the parent topic through a public method instead of directly accessing topicService
        updateTopic(updatedParentTopic)
        
        // Update the layout to reflect the new structure
        performAutoLayout()
    }
    
    private func calculateNewSubtopicPosition(for parentTopic: Topic, subtopicCount: Int) -> CGPoint {
        // Constants for spacing
        let horizontalSpacing: CGFloat = 200 // Space between parent and child
        let verticalSpacing: CGFloat = 60 // Space between siblings
        
        // Calculate the total height needed for all subtopics
        let totalSubtopics = subtopicCount + 1 // Including the new subtopic
        let totalHeight = verticalSpacing * CGFloat(totalSubtopics - 1)
        
        // Calculate the starting Y position (top-most subtopic)
        let startY = parentTopic.position.y + totalHeight/2
        
        // Calculate this subtopic's Y position
        let y = startY - (CGFloat(subtopicCount) * verticalSpacing)
        
        // Position the subtopic to the right of the parent
        let x = parentTopic.position.x + horizontalSpacing
        
        return CGPoint(x: x, y: y)
    }
}

