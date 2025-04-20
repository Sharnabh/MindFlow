import SwiftUI
import UniformTypeIdentifiers

struct TemplateSelectionPopup: View {
    // Callback when a template is selected
    var onSelectTemplate: (TemplateType) -> Void
    
    // Colors from the app
    private let backgroundColor = Color(hex: "#2B5876") ?? .blue
    private let mainNodeColor = Color.white
    private let blueNodeColor = Color(hex: "#64B5F6") ?? .blue
    private let greenNodeColor = Color(hex: "#81C784") ?? .green
    private let tealNodeColor = Color(hex: "#4DB6AC") ?? .teal
    private let purpleNodeColor = Color(hex: "#B39DDB") ?? .purple
    private let centralLogoColor = Color(hex: "#4E4376") ?? .purple
    
    // Available templates
    private let templates = [
        (name: "Mind Map", icon: "brain", type: TemplateType.mindMap, color: Color(hex: "#4E4376") ?? .purple),
        (name: "Tree", icon: "tree", type: TemplateType.tree, color: Color(hex: "#81C784") ?? .green),
        (name: "Concept Map", icon: "network", type: TemplateType.conceptMap, color: Color(hex: "#64B5F6") ?? .blue),
        (name: "Flowchart", icon: "arrow.triangle.branch", type: TemplateType.flowchart, color: Color(hex: "#4DB6AC") ?? .teal),
        (name: "Org Chart", icon: "person.3", type: TemplateType.orgChart, color: Color(hex: "#B39DDB") ?? .purple)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Select a Template")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 16)
            
            // Template grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 140))], spacing: 16) {
                ForEach(templates, id: \.name) { template in
                    templateCard(template: template)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(hex: "#2B5876")?.opacity(0.95) ?? Color.blue.opacity(0.95))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
        .padding(20)
        .frame(width: 420, height: 340)
    }
    
    // Template card view
    func templateCard(template: (name: String, icon: String, type: TemplateType, color: Color)) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(template.color)
                    .frame(height: 100)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                
                // Template icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(template.color)
                }
            }
            
            Text(template.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectTemplate(template.type)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.5)
            .edgesIgnoringSafeArea(.all)
        
        TemplateSelectionPopup { template in
            print("Selected template: \(template)")
        }
    }
} 