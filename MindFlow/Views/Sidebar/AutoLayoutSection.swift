import SwiftUI

struct AutoLayoutSection: View {
    var body: some View {
        SidebarSection(title: "Auto Layout Settings", content: AnyView(
            VStack(spacing: 12) {
                // Placeholder for future auto-layout settings
                Text("Auto-layout settings will be available in a future update")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
        ))
    }
} 