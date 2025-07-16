import SwiftUI

struct BranchStyleSection: View {
    @ObservedObject var viewModel: CanvasViewModel
    let selectedTopic: Topic
    @Binding var isCircularRelationshipMode: Bool
    @Binding var isSquaredRelationshipMode: Bool
    
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
                
                // Circular relationship mode toggle
                HStack {
                    Toggle("Circular Relationships", isOn: Binding(
                        get: { isCircularRelationshipMode },
                        set: { newValue in
                            if newValue {
                                isSquaredRelationshipMode = false // Disable squared mode
                            }
                            isCircularRelationshipMode = newValue
                        }
                    ))
                        .font(.system(size: 14))
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .help("Create curved/circular relationship lines between topics")
                
                // Squared relationship mode toggle
                HStack {
                    Toggle("Squared Relationships", isOn: Binding(
                        get: { isSquaredRelationshipMode },
                        set: { newValue in
                            if newValue {
                                isCircularRelationshipMode = false // Disable circular mode
                            }
                            isSquaredRelationshipMode = newValue
                        }
                    ))
                        .font(.system(size: 14))
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .help("Create squared S-shaped relationship lines between topics")
                
                // Information text for circular mode
                if isCircularRelationshipMode {
                    Text("Circular mode creates curved relationship lines")
                        .foregroundColor(.blue)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                
                // Information text for squared mode
                if isSquaredRelationshipMode {
                    Text("Squared mode creates rectangular S-shaped relationship lines")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
            }
        ))
    }
} 
