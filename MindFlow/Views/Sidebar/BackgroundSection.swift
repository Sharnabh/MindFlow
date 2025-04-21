import SwiftUI

struct BackgroundSection: View {
    @Binding var backgroundStyle: BackgroundStyle
    @Binding var backgroundColor: Color
    @Binding var backgroundOpacity: Double
    @Binding var isShowingBackgroundColorPicker: Bool
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        SidebarSection(title: "Canvas Background", content: AnyView(
            VStack(spacing: 12) {
                // Background style selector
                HStack(spacing: 8) {
                    Text("Style")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    Picker("", selection: $backgroundStyle) {
                        ForEach(BackgroundStyle.allCases) { style in
                            HStack {
                                Image(systemName: style.iconName)
                                    .font(.system(size: 14))
                                Text(style.rawValue)
                            }
                            .tag(style)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                }
                .padding(.horizontal)
                
                // Background color control
                HStack(spacing: 8) {
                    Text("Color")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    ColorPickerButton(color: backgroundColor) {
                        isShowingBackgroundColorPicker.toggle()
                    }
                    .popover(isPresented: $isShowingBackgroundColorPicker, arrowEdge: .bottom) {
                        ColorPickerView(
                            selectedColor: $backgroundColor,
                            opacity: $backgroundOpacity,
                            viewModel: viewModel
                        )
                    }
                }
                .padding(.horizontal)
            }
        ))
    }
} 