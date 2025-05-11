import SwiftUI

struct TopBarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isSidebarOpen: Bool
    @Binding var isRelationshipMode: Bool
    @State private var showingNoteEditor = false
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
                        // Present button - start presentation mode
                        Button(action: {
                            // Start the presentation mode
                            if !viewModel.topics.isEmpty {
                                PresentationManager.shared.startPresentation(topics: viewModel.topics)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 14))
                                Text("Present")
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
                        .help("Start presentation mode")
                        .disabled(viewModel.topics.isEmpty)
                        .focusable(false)
                        
                        // Auto layout button
                        Button(action: {
                            viewModel.performFullAutoLayout()
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
                        
                        // Note button - for adding/editing notes to the selected topic
                        Button(action: {
                            if let selectedId = viewModel.selectedTopicId {
                                // Always open the editor near the topic, not in the top bar
                                viewModel.showingNoteEditorForTopicId = selectedId
                                
                                // Check if topic has a note
                                let hasNote = viewModel.selectedTopicId.flatMap { id in
                                    viewModel.getTopicById(id)
                                }.flatMap { topic in
                                    viewModel.topicHasNote(topic)
                                } ?? false
                                
                                if (hasNote) {
                                    // If topic already has a note, load its content
                                    if let topic = viewModel.getTopicById(selectedId), let note = topic.note {
                                        viewModel.currentNoteContent = note.content
                                    }
                                } else {
                                    // For topics without notes, create a new one
                                    viewModel.currentNoteContent = ""
                                    viewModel.addNoteToSelectedTopic()
                                }
                                
                                // Set editing to true to show the editor
                                viewModel.isEditingNote = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                // Show different icon if the selected topic has a note
                                let hasNote = viewModel.selectedTopicId.flatMap { id in
                                    viewModel.getTopicById(id)
                                }.flatMap { topic in
                                    viewModel.topicHasNote(topic)
                                } ?? false
                                
                                Image(systemName: hasNote ? "doc.text.fill" : "doc.badge.plus")
                                    .foregroundColor(viewModel.selectedTopicId != nil ? (hasNote ? .blue : .primary) : .gray)
                                    .font(.system(size: 14))
                                
                                Text("Note")
                                    .font(.system(size: 13))
                                    .foregroundColor(viewModel.selectedTopicId != nil ? (hasNote ? .blue : .primary) : .gray)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.15))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.selectedTopicId == nil)
                        .help("Add or edit a note for the selected topic")
                        .focusable(false)
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

// Note Editor View
struct NoteEditorView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Topic Note")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.saveNote()
                    isPresented = false
                }) {
                    Text("Save")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button(action: {
                    viewModel.deleteNoteFromSelectedTopic()
                    isPresented = false
                }) {
                    Text("Delete")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.selectedTopicId.flatMap { id in
                    viewModel.getTopicById(id)
                }.flatMap { topic in
                    !viewModel.topicHasNote(topic)
                } ?? true)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            TextEditor(text: $viewModel.currentNoteContent)
                .font(.body)
                .padding(8)
                .frame(minWidth: 400, minHeight: 250)
                .overlay(
                    Group {
                        if viewModel.currentNoteContent.isEmpty {
                            Text("Enter note text here...")
                                .foregroundColor(.gray)
                                .padding(16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
                )
                .onChange(of: viewModel.currentNoteContent) { _, _ in
                    // Auto-save as content changes without closing the editor
                    viewModel.autoSaveCurrentNote()
                }
        }
        .onDisappear {
            // Final save when editor is closed
            viewModel.saveNote()
            // Clean up and reset state when the editor is closed
            viewModel.isEditingNote = false
        }
    }
}