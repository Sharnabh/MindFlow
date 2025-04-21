import SwiftUI

struct TopicStyleSection: View {
    @ObservedObject var viewModel: CanvasViewModel
    let selectedTopic: Topic
    @Binding var isShowingColorPicker: Bool
    @Binding var isShowingBorderColorPicker: Bool
    
    var body: some View {
        SidebarSection(title: "Topic Style", content: AnyView(
            VStack(spacing: 12) {
                // Shape selector
                ShapeSelector(
                    selectedShape: selectedTopic.shape,
                    onShapeSelected: { shape in
                        viewModel.updateTopicShape(selectedTopic.id, shape: shape)
                    }
                )
                
                // Fill control
                HStack(spacing: 8) {
                    Text("Fill")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    ColorPickerButton(color: selectedTopic.backgroundColor) {
                        isShowingColorPicker.toggle()
                    }
                    .popover(isPresented: $isShowingColorPicker, arrowEdge: .bottom) {
                        ColorPickerView(
                            selectedColor: Binding(
                                get: { selectedTopic.backgroundColor },
                                set: { newColor in
                                    viewModel.updateTopicBackgroundColor(selectedTopic.id, color: newColor)
                                }
                            ),
                            opacity: Binding(
                                get: { selectedTopic.backgroundOpacity },
                                set: { newOpacity in
                                    viewModel.updateTopicBackgroundOpacity(selectedTopic.id, opacity: newOpacity)
                                }
                            ),
                            viewModel: viewModel
                        )
                    }
                }
                .padding(.horizontal)
                
                // Border control
                HStack(spacing: 8) {
                    Text("Border")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    ColorPickerButton(color: selectedTopic.borderColor) {
                        isShowingBorderColorPicker.toggle()
                    }
                    .popover(isPresented: $isShowingBorderColorPicker, arrowEdge: .bottom) {
                        ColorPickerView(
                            selectedColor: Binding(
                                get: { selectedTopic.borderColor },
                                set: { newColor in
                                    viewModel.updateTopicBorderColor(selectedTopic.id, color: newColor)
                                }
                            ),
                            opacity: Binding(
                                get: { selectedTopic.borderOpacity },
                                set: { newOpacity in
                                    viewModel.updateTopicBorderOpacity(selectedTopic.id, opacity: newOpacity)
                                }
                            ),
                            viewModel: viewModel
                        )
                    }
                }
                .padding(.horizontal)
                
                // Border width control
                HStack(spacing: 8) {
                    Text("Border Width")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    Menu {
                        ForEach(Topic.BorderWidth.allCases, id: \.self) { width in
                            Button(action: {
                                viewModel.updateTopicBorderWidth(selectedTopic.id, width: width)
                            }) {
                                HStack {
                                    if selectedTopic.borderWidth == width {
                                        Image(systemName: "checkmark")
                                            .frame(width: 16, alignment: .center)
                                    } else {
                                        Color.clear
                                            .frame(width: 16)
                                    }
                                    Text(width.displayName)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedTopic.borderWidth.displayName)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(width: 100)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal)
            }
        ))
    }
} 