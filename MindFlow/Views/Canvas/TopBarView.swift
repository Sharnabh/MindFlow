import SwiftUI

struct TopBarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isSidebarOpen: Bool
    @Binding var isRelationshipMode: Bool
    let topBarHeight: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(Color(.windowBackgroundColor))
            .frame(height: topBarHeight)
            .overlay(
                HStack(spacing: 0) {
                    Text("MindFlow")
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // Group all central buttons together in the middle
                    HStack(spacing: 12) {
                        // Auto layout button
                        Button(action: {
                            viewModel.performAutoLayout()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "rectangle.grid.1x2")
                                    .font(.system(size: 14))
                                Text("Auto Layout")
                                    .font(.system(size: 13))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.15))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Automatically arrange topics with perfect spacing")
                        .focusable(false) // Prevent Auto Layout button from gaining focus
                        
                        // Collapse button - enabled when a topic with children is selected
                        Button(action: {
                            if let selectedId = viewModel.selectedTopicId {
                                viewModel.toggleCollapseState(topicId: selectedId)
                            }
                        }) {
                            HStack(spacing: 4) {
                                let isCollapsed = viewModel.selectedTopicId.flatMap(viewModel.isTopicCollapsed) ?? false
                                let totalDescendants = viewModel.selectedTopicId.flatMap { id in 
                                    if let topic = viewModel.getTopicById(id) {
                                        return viewModel.countAllDescendants(for: topic)
                                    }
                                    return 0
                                } ?? 0
                                
                                Image(systemName: isCollapsed ? "chevron.down.circle" : "chevron.right.circle")
                                    .foregroundColor(totalDescendants > 0 ? .primary : .gray)
                                    .font(.system(size: 14))
                                
                                Text(isCollapsed ? "Expand" : "Collapse")
                                    .font(.system(size: 13))
                                    .foregroundColor(totalDescendants > 0 ? .primary : .gray)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.15))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.selectedTopicId == nil || 
                                 (viewModel.selectedTopicId.flatMap { id in 
                                     viewModel.getTopicById(id)
                                 }.flatMap { topic in 
                                     viewModel.countAllDescendants(for: topic)
                                 } ?? 0) == 0)
                        .help("Collapse or expand the selected topic")
                        .focusable(false) // Prevent Collapse button from gaining focus
                        
                        // Relationship button
                        Button(action: {
                            isRelationshipMode.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundColor(isRelationshipMode ? .blue : .primary)
                                    .font(.system(size: 14))
                                
                                Text("Relationship")
                                    .font(.system(size: 13))
                                    .foregroundColor(isRelationshipMode ? .blue : .primary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isRelationshipMode ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Create relationships between topics")
                        .focusable(false) // Prevent Relationship button from gaining focus
                    }
                    
                    Spacer()
                    
                    // Sidebar toggle button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarOpen.toggle()
                        }
                    }) {
                        Image(systemName: isSidebarOpen ? "sidebar.right" : "sidebar.right")
                            .foregroundColor(.primary)
                            .font(.system(size: 14, weight: .regular))
                            .frame(width: 28, height: topBarHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(.windowBackgroundColor))
                    .focusable(false) // Prevent the button from receiving focus
                }
            )
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            .zIndex(1) // Ensure top bar stays above other content
    }
} 