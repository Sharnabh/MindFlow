//
//  StartupScreenView.swift
//  MindFlow
//
//  Created by Sharnabh on 14/03/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct StartupScreenView: View {
    @EnvironmentObject var viewModel: CanvasViewModel
    @EnvironmentObject var authService: AuthenticationService
    @Binding var showingStartupScreen: Bool
    @State private var selectedOption: StartupOption = .templates
    @State private var recentFiles: [RecentFile] = []
    @State private var trashedFiles: [RecentFile] = []
    @State private var showingWelcome: Bool = true
    @StateObject private var authState: AuthState
    
    // Colors from logo.svg
    private let backgroundColor = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "#2B5876") ?? .blue, Color(hex: "#4E4376") ?? .purple]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let mainNodeColor = Color.white
    private let blueNodeColor = Color(hex: "#64B5F6") ?? .blue
    private let greenNodeColor = Color(hex: "#81C784") ?? .green
    private let yellowNodeColor = Color(hex: "#FFD54F") ?? .yellow
    private let redNodeColor = Color(hex: "#E57373") ?? .red
    private let purpleNodeColor = Color(hex: "#B39DDB") ?? .purple
    private let tealNodeColor = Color(hex: "#4DB6AC") ?? .teal
    private let lightYellowColor = Color(hex: "#FFF176") ?? .yellow
    private let pinkNodeColor = Color(hex: "#F48FB1") ?? .pink
    private let centralLogoColor = Color(hex: "#4E4376") ?? .purple
    
    enum StartupOption: String, CaseIterable, Identifiable {
        case templates = "Templates"
        case recent = "Recent"
        case openLocalFiles = "Open Local Files"
        case trash = "Trash"
        
        var id: String { self.rawValue }
    }
    
    struct RecentFile: Identifiable {
        let id = UUID()
        let name: String
        let date: Date
        let url: URL
    }
    
    struct TemplateItem: Identifiable {
        let id = UUID()
        let name: String
        let sfSymbolName: String
    }
    
    // Sample templates
    let templates: [TemplateItem] = [
        TemplateItem(name: "Mind Map", sfSymbolName: "brain"),
        TemplateItem(name: "Tree", sfSymbolName: "tree"),
        TemplateItem(name: "Concept Map", sfSymbolName: "network"),
        TemplateItem(name: "Flowchart", sfSymbolName: "arrow.triangle.branch"),
        TemplateItem(name: "Org Chart", sfSymbolName: "person.3")
    ]
    
    init(showingStartupScreen: Binding<Bool>, authService: AuthenticationService) {
        self._showingStartupScreen = showingStartupScreen
        self._authState = StateObject(wrappedValue: AuthState(authService: authService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // App logo and title
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                        .overlay {
                            LogoPathView(color: centralLogoColor)
                        }
                }
                
                Text("MindFlow")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 10)
            }
            .frame(height: 120)
            .padding(.top, 40)
            
            // Authentication status and sign-in button
            HStack {
                if authService.isAuthenticated, let user = authService.currentUser {
                    HStack(spacing: 10) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                        
                        Text(getFirstName(from: user.displayName ?? "User"))
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(20)
                } else {
                    Button(action: {
                        authState.presentAuthFlow()
                    }) {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 18))
                            Text("Sign In")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.bottom, 20)
            
            // Main content
            HStack(spacing: 20) {
                // Left sidebar with options
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(StartupOption.allCases) { option in
                        HStack {
                            Text(option.rawValue)
                                .font(.title3)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(selectedOption == option ? centralLogoColor : Color.clear)
                        .foregroundColor(selectedOption == option ? .white : .primary)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Hide welcome screen when an option is selected
                            showingWelcome = false
                            selectedOption = option
                            
                            // If "Open Local Files" is selected, show file picker right away
                            if option == .openLocalFiles {
                                openFilePicker()
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: 250)
                .padding(20)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Right content area
                VStack {
                    if showingWelcome {
                        welcomeView
                    } else {
                        // Content based on selected option
                        switch selectedOption {
                        case .templates:
                            templatesView
                                .padding(.vertical, 0)
                        case .recent:
                            recentFilesView
                        case .openLocalFiles:
                            // This is handled by openFilePicker() when the option is selected
                            EmptyView()
                        case .trash:
                            trashView
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
            
            Spacer()
        }
        .background(backgroundColor)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // Load recent files and trash data
            loadRecentFiles()
            loadTrashFiles()
        }
        .sheet(isPresented: $authState.showAuthFlow) {
            AuthView()
                .environmentObject(authService)
                .environmentObject(authState)
                .frame(width: 500, height: 600)
        }
        
    }


// Templates view
var templatesView: some View {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 250))], spacing: 25) {
            ForEach(templates) { template in
                templateCard(template: template)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
    }
    .padding(20)
}

// Template card view
func templateCard(template: TemplateItem) -> some View {
    VStack(spacing: 15) {
        ZStack {
            // Card background with full coverage
            RoundedRectangle(cornerRadius: 12)
                .fill(getColorForTemplate(template: template))
                .aspectRatio(1.7, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
            
            // Template visualization
            VStack(spacing: 0) {
                // Template icon in circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: template.sfSymbolName)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(getColorForTemplate(template: template))
                }
                .padding(.bottom, 8)
            }
            .padding()
        }
        
        Text(template.name)
            .font(.headline)
            .foregroundColor(.white)
    }
    .frame(width: 200)
    .background(Color.clear)
    .onTapGesture {
        createNewFromTemplate(template: template)
    }
}

// Function to get a color based on the template
func getColorForTemplate(template: TemplateItem) -> Color {
    switch template.name {
    case "Mind Map":
        return centralLogoColor
    case "Tree":
        return greenNodeColor
    case "Concept Map":
        return blueNodeColor
    case "Flowchart":
        return tealNodeColor
    case "Org Chart":
        return purpleNodeColor
    default:
        return Color(hex: "#4E4376") ?? .purple
    }
}

// Recent files view
var recentFilesView: some View {
    Group {
        if recentFiles.isEmpty {
            Text("No recent files")
                .font(.title)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            List {
                ForEach(recentFiles) { file in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(file.name)
                                .font(.headline)
                            Text(formattedDate(file.date))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            moveToTrash(file: file)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(redNodeColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openRecentFile(file: file)
                    }
                    .listRowBackground(Color.white.opacity(0.1))
                }
            }
            .cornerRadius(8)
        }
    }
    .padding(10)
}

// Trash view
var trashView: some View {
    Group {
        if trashedFiles.isEmpty {
            Text("Trash is empty")
                .font(.title)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            VStack {
                List {
                    ForEach(trashedFiles) { file in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(file.name)
                                    .font(.headline)
                                Text(formattedDate(file.date))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                restoreFromTrash(file: file)
                            }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .foregroundColor(blueNodeColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            
                            Button(action: {
                                permanentlyDelete(file: file)
                            }) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(redNodeColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.white.opacity(0.1))
                    }
                }
                .cornerRadius(8)
                
                Button("Empty Trash") {
                    emptyTrash()
                }
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(redNodeColor)
                .cornerRadius(8)
                .padding()
                .disabled(trashedFiles.isEmpty)
            }
        }
    }
    .padding(10)
}

// Format date
func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

// Load recent files
func loadRecentFiles() {
    // Use UserDefaults to load recent files
    recentFiles = UserDefaults.standard.loadRecentFiles()
    
    // If empty, provide some sample data for testing
    if recentFiles.isEmpty {
        let sampleDates = [
            Date(),
            Date().addingTimeInterval(-86400), // Yesterday
            Date().addingTimeInterval(-172800) // 2 days ago
        ]
        
        recentFiles = [
            RecentFile(name: "Project Planning", date: sampleDates[0], url: URL(string: "file:///project.mindflow")!),
            RecentFile(name: "Marketing Strategy", date: sampleDates[1], url: URL(string: "file:///marketing.mindflow")!),
            RecentFile(name: "Personal Goals", date: sampleDates[2], url: URL(string: "file:///goals.mindflow")!)
        ]
    }
}

// Load trash files
func loadTrashFiles() {
    // Use UserDefaults to load trashed files
    trashedFiles = UserDefaults.standard.loadTrashedFiles()
    
    // If empty, provide some sample data for testing
    if trashedFiles.isEmpty {
        trashedFiles = [
            RecentFile(name: "Archived Project", date: Date().addingTimeInterval(-604800), url: URL(string: "file:///archived.mindflow")!),
            RecentFile(name: "Old Notes", date: Date().addingTimeInterval(-1209600), url: URL(string: "file:///old.mindflow")!)
        ]
    }
}

// Open file picker
func openFilePicker() {
    // Create an NSOpenPanel
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowsMultipleSelection = false
//    openPanel.allowedFileTypes = ["mindflow"]
    openPanel.allowedContentTypes = [UTType(filenameExtension: "mindflow")!]
    
    openPanel.begin { response in
        if response == .OK, let url = openPanel.url {
            // Open the selected file
            MindFlowFileManager.shared.loadFile(from: url) { loadedTopics, errorMessage in
                if let topics = loadedTopics {
                    // Close the startup screen and show the canvas
                    closeStartupScreenAndShowCanvas()
                    
                    // Notify the canvas view model to load these topics
                    NotificationCenter.default.post(
                        name: NSNotification.Name("LoadTopics"),
                        object: nil,
                        userInfo: ["topics": topics]
                    )
                    
                    // Add to recent files
                    let newRecentFile = RecentFile(name: url.lastPathComponent, date: Date(), url: url)
                    UserDefaults.standard.addToRecentFiles(newRecentFile)
                    
                    // Refresh our local list
                    recentFiles = UserDefaults.standard.loadRecentFiles()
                }
            }
        }
    }
}

// Open a recent file
func openRecentFile(file: RecentFile) {
    MindFlowFileManager.shared.loadFile(from: file.url) { loadedTopics, errorMessage in
        if let topics = loadedTopics {
            // Close the startup screen and show the canvas
            closeStartupScreenAndShowCanvas()
            
            // Notify the canvas view model to load these topics
            NotificationCenter.default.post(
                name: NSNotification.Name("LoadTopics"),
                object: nil,
                userInfo: ["topics": topics]
            )
        }
    }
}

// Move file to trash
func moveToTrash(file: RecentFile) {
    UserDefaults.standard.moveFileToTrash(file)
    
    // Refresh our local lists
    recentFiles = UserDefaults.standard.loadRecentFiles()
    trashedFiles = UserDefaults.standard.loadTrashedFiles()
}

// Restore file from trash
func restoreFromTrash(file: RecentFile) {
    UserDefaults.standard.restoreFileFromTrash(file)
    
    // Refresh our local lists
    recentFiles = UserDefaults.standard.loadRecentFiles()
    trashedFiles = UserDefaults.standard.loadTrashedFiles()
}

// Permanently delete file
func permanentlyDelete(file: RecentFile) {
    UserDefaults.standard.deleteFileFromTrash(file)
    
    // Refresh our local list
    trashedFiles = UserDefaults.standard.loadTrashedFiles()
}

// Empty trash
func emptyTrash() {
    UserDefaults.standard.emptyTrash()
    trashedFiles = []
}

// Create new file from template
func createNewFromTemplate(template: TemplateItem) {
    // Convert TemplateItem to TemplateType
    let templateType: TemplateType
    switch template.name {
    case "Mind Map": templateType = .mindMap
    case "Tree": templateType = .tree
    case "Concept Map": templateType = .conceptMap
    case "Flowchart": templateType = .flowchart
    case "Org Chart": templateType = .orgChart
    default: templateType = .mindMap
    }
    
    // Create a central topic with template type (but don't add it to canvas yet)
    let centralTopic = Topic(
        name: template.name, 
        position: CGPoint(x: 0, y: 0),
        templateType: templateType
    )
    
    // Open save dialog first
    let savePanel = NSSavePanel()
    savePanel.canCreateDirectories = true
    savePanel.showsTagField = true
    savePanel.title = "Save New Mind Map"
    savePanel.nameFieldStringValue = template.name
    savePanel.allowedContentTypes = [UTType.mindFlowType]
    
    savePanel.begin { result in
        if result == .OK, let url = savePanel.url {
            // Close the startup screen and show the canvas
            self.closeStartupScreenAndShowCanvas()
            
            // Clear the canvas
            MindFlowFileManager.shared.newFile()
            NotificationCenter.default.post(name: NSNotification.Name("ClearCanvas"), object: nil)
            
            // Create a new mind map with a template structure
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Add the central topic to the canvas
                self.viewModel.topicService.addTopic(centralTopic)
                
                // Select the topic
                self.viewModel.topicService.selectTopic(withId: centralTopic.id)
                
                // Save the file
                MindFlowFileManager.shared.saveFile(topics: [centralTopic], to: url) { success, errorMessage in
                    if success {
                        // Set as current file
                        MindFlowFileManager.shared.currentURL = url
                        
                        // Add to recent files
                        let newRecentFile = RecentFile(
                            name: url.lastPathComponent,
                            date: Date(),
                            url: url
                        )
                        UserDefaults.standard.addToRecentFiles(newRecentFile)
                    } else if let error = errorMessage {
                        // Display error alert
                        let alert = NSAlert()
                        alert.messageText = "Failed to save file"
                        alert.informativeText = error
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }
}

// Close the startup screen and transition to canvas
func closeStartupScreenAndShowCanvas() {
    // Close the startup screen
    showingStartupScreen = false
}

// Welcome screen component
var welcomeView: some View {
    ZStack {
        // Background with gradient - full coverage
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        blueNodeColor.opacity(0.3),
                        purpleNodeColor.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        
        VStack(spacing: 30) {
            // Main welcome message
            VStack(spacing: 15) {
                Text("Welcome to MindFlow")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Create beautiful mind maps and organize your thoughts")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Features highlight
            VStack(spacing: 15) {
                featureRow(icon: "brain.head.profile", title: "Intuitive Mind Mapping", description: "Organize your ideas visually with our intuitive interface")
                featureRow(icon: "rectangle.3.group", title: "Multiple Templates", description: "Choose from various templates for different thinking styles")
                featureRow(icon: "arrow.triangle.branch", title: "Flexible Connections", description: "Create complex relationships between your ideas")
            }
            .padding(.vertical)
            
            // Start button
            Button(action: {
                // Switch to templates tab
                selectedOption = .templates
                showingWelcome = false
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .background(centralLogoColor)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 60)
    }
}

// Helper function for feature rows
func featureRow(icon: String, title: String, description: String) -> some View {
    HStack(alignment: .center, spacing: 15) {
        Image(systemName: icon)
            .font(.system(size: 22))
            .foregroundColor(.white)
            .frame(width: 45, height: 45)
            .background(greenNodeColor.opacity(0.7))
            .clipShape(Circle())
        
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        
        Spacer()
    }
    .padding(.horizontal)
}

// Helper function to extract first name
func getFirstName(from fullName: String) -> String {
    return fullName.components(separatedBy: " ").first ?? fullName
}
}

// Logo path extracted as a separate view
struct LogoPathView: View {
    let color: Color
    
    var body: some View {
        Path { path in
            let width: CGFloat = 30
            let height: CGFloat = 28
            let x = 30 - width/2
            let y = 30 - height/2
            
            // Left line
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + height))
            
            // Middle up
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + width/2, y: y + height/3))
            
            // Middle down
            path.addLine(to: CGPoint(x: x + width, y: y))
            
            // Right line
            path.move(to: CGPoint(x: x + width, y: y))
            path.addLine(to: CGPoint(x: x + width, y: y + height))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
}

//#Preview {
//    let authService = DependencyContainer.shared.makeAuthService()
//    return StartupScreenView(showingStartupScreen: .constant(true), authService: authService)
//        .environmentObject(DependencyContainer.shared.makeCanvasViewModel())
//        .environmentObject(authService)
//        .frame(width: 1000, height: 600)
//}
