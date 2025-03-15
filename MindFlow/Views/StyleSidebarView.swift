import SwiftUI

struct StyleSidebarView: View {
    @Binding var style: TopicStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Style")
                .font(.headline)
                .padding(.bottom, 5)
            
            // Shape Picker
            VStack(alignment: .leading) {
                Text("Shape")
                    .font(.subheadline)
                Picker("Shape", selection: $style.shape) {
                    Text("Rounded").tag(TopicStyle.TopicShape.roundedRectangle)
                    Text("Rectangle").tag(TopicStyle.TopicShape.rectangle)
                    Text("Capsule").tag(TopicStyle.TopicShape.capsule)
                    Text("Ellipse").tag(TopicStyle.TopicShape.ellipse)
                }
                .pickerStyle(.segmented)
            }
            
            // Colors Section
            VStack(alignment: .leading, spacing: 12) {
                // Border Color
                ColorPicker("Border Color", selection: $style.borderColor)
                
                // Foreground Color
                ColorPicker("Text Color", selection: $style.foregroundColor)
                
                // Background Color
                ColorPicker("Background", selection: $style.backgroundColor)
            }
            
            // Font Style
            VStack(alignment: .leading) {
                Text("Font Style")
                    .font(.subheadline)
                Picker("Font Style", selection: .constant(0)) {
                    Text("Default").tag(0)
                    Text("Rounded").tag(1)
                    Text("Monospaced").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: 0) { value in
                    switch value {
                    case 0: style.fontStyle = .body
                    case 1: style.fontStyle = .system(.body, design: .rounded)
                    case 2: style.fontStyle = .system(.body, design: .monospaced)
                    default: break
                    }
                }
            }
            
            // Border Properties
            VStack(alignment: .leading, spacing: 12) {
                // Border Width
                VStack(alignment: .leading) {
                    Text("Border Width")
                        .font(.subheadline)
                    Slider(value: $style.borderWidth, in: 0...5, step: 0.5)
                }
                
                // Border Style
                VStack(alignment: .leading) {
                    Text("Border Style")
                        .font(.subheadline)
                    Picker("Border Style", selection: $style.borderStyle) {
                        Text("Solid").tag(TopicStyle.TopicBorderStyle.solid)
                        Text("Dashed").tag(TopicStyle.TopicBorderStyle.dashed)
                        Text("Dotted").tag(TopicStyle.TopicBorderStyle.dotted)
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            // Preset Styles
            VStack(alignment: .leading, spacing: 8) {
                Text("Presets")
                    .font(.subheadline)
                
                HStack {
                    Button("Default") { style = .default }
                    Button("Modern") { style = .modern }
                    Button("Minimal") { style = .minimal }
                }
            }
            
            Spacer()
        }
        .padding()
    }
} 