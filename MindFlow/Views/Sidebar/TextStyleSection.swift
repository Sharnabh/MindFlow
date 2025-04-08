import SwiftUI

struct TextStyleSection: View {
    @ObservedObject var viewModel: CanvasViewModel
    let selectedTopic: Topic
    @Binding var isShowingForegroundColorPicker: Bool
    
    var body: some View {
        SidebarSection(title: "Text", content: AnyView(
            VStack(spacing: 12) {
                // Font style
                HStack(spacing: 8) {
                    Text("Font")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    StyledMenuButton(width: 120, action: {
                        // Action is handled in the Menu
                    }) {
                        Menu {
                            ForEach(["Apple SD Gothic", "System", "Helvetica", "Arial", "Times New Roman"], id: \.self) { font in
                                Button(action: {
                                    viewModel.updateTopicFont(selectedTopic.id, font: font)
                                }) {
                                    Text(font)
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedTopic.font)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Font size
                HStack(spacing: 8) {
                    Text("Size")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    StyledMenuButton(width: 120, action: {
                        // Action is handled in the Menu
                    }) {
                        Menu {
                            ForEach([8, 10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64], id: \.self) { size in
                                Button(action: {
                                    viewModel.updateTopicFontSize(selectedTopic.id, size: CGFloat(size))
                                }) {
                                    Text("\(size)")
                                }
                            }
                        } label: {
                            HStack {
                                Text("\(Int(selectedTopic.fontSize))")
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Font weight
                HStack(spacing: 8) {
                    Text("Weight")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    StyledMenuButton(width: 120, action: {
                        // Action is handled in the Menu
                    }) {
                        Menu {
                            ForEach(Font.Weight.allCases, id: \.self) { weight in
                                Button(action: {
                                    viewModel.updateTopicFontWeight(selectedTopic.id, weight: weight)
                                }) {
                                    Text(weight.displayName)
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedTopic.fontWeight.displayName)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Text color
                HStack(spacing: 8) {
                    Text("Color")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    ColorPickerButton(color: selectedTopic.foregroundColor) {
                        isShowingForegroundColorPicker.toggle()
                    }
                    .popover(isPresented: $isShowingForegroundColorPicker, arrowEdge: .bottom) {
                        ColorPickerView(
                            selectedColor: Binding(
                                get: { selectedTopic.foregroundColor },
                                set: { newColor in
                                    viewModel.updateTopicForegroundColor(selectedTopic.id, color: newColor)
                                }
                            ),
                            opacity: Binding(
                                get: { selectedTopic.foregroundOpacity },
                                set: { newOpacity in
                                    viewModel.updateTopicForegroundOpacity(selectedTopic.id, opacity: newOpacity)
                                }
                            )
                        )
                    }
                }
                .padding(.horizontal)
                
                // Text style controls
                HStack(spacing: 0) {
                    ForEach(TextStyle.allCases, id: \.self) { style in
                        Button(action: {
                            let isEnabled = !(selectedTopic.textStyles.contains(style))
                            viewModel.updateTopicTextStyle(selectedTopic.id, style: style, isEnabled: isEnabled)
                        }) {
                            Image(systemName: style.iconName)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 28)
                                .background(selectedTopic.textStyles.contains(style) ? Color.gray.opacity(0.3) : Color.clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if style != .underline {
                            Divider()
                                .frame(height: 16)
                                .background(Color.black.opacity(0.2))
                        }
                    }
                    
                    Divider()
                        .frame(height: 16)
                        .background(Color.black.opacity(0.2))
                    
                    Button(action: {
                        let nextCase = TextCase.allCases.first { $0 != selectedTopic.textCase } ?? .none
                        viewModel.updateTopicTextCase(selectedTopic.id, textCase: nextCase)
                    }) {
                        Image(systemName: "textformat")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(Color(.darkGray))
                .cornerRadius(6)
                .padding(.horizontal)
                
                // Text alignment
                Picker("", selection: Binding(
                    get: { selectedTopic.textAlignment },
                    set: { alignment in
                        viewModel.updateTopicTextAlignment(selectedTopic.id, alignment: alignment)
                    }
                )) {
                    ForEach(TextAlignment.allCases, id: \.self) { alignment in
                        Image(systemName: alignment.iconName)
                            .tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
        ))
    }
} 
