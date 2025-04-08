import SwiftUI

struct BranchStyleSection: View {
    @ObservedObject var viewModel: CanvasViewModel
    let selectedTopic: Topic
    
    var body: some View {
        SidebarSection(title: "Branch Style", content: AnyView(
            VStack(spacing: 12) {
                // Description text
                Text("Branch style applies to all connections on the canvas")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Branch style dropdown
                HStack(spacing: 8) {
                    Menu {
                        ForEach(Topic.BranchStyle.allCases, id: \.self) { style in
                            Button(action: {
                                // Use null UUID to indicate we want to update all topics
                                viewModel.updateTopicBranchStyle(nil, style: style)
                            }) {
                                HStack {
                                    // Check the current global style by looking at the selected topic
                                    if selectedTopic.branchStyle == style {
                                        Image(systemName: "checkmark")
                                            .frame(width: 16, alignment: .center)
                                    } else {
                                        Color.clear
                                            .frame(width: 16)
                                    }
                                    Text(style.displayName)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedTopic.branchStyle.displayName)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(width: 120)
                        .background(Color(.darkGray))
                        .cornerRadius(6)
                    }
                    
                    // Visual indicator for global setting
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                        .help("Changes all connections on the canvas")
                }
                .padding(.horizontal)
            }
        ))
    }
} 