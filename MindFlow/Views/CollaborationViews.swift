import SwiftUI
import CloudKit

// MARK: - Collaboration UI Components

// MARK: - Share Acceptance View
struct ShareAcceptanceView: View {
    let shareURL: URL
    @State private var isAccepting = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var shareAccepted = false
    @State private var shareMetadata: CKShare.Metadata?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "person.2.badge.plus")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Accept Share")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if shareAccepted {
                // Success state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 50))
                    
                    Text("Share Accepted!")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("You can now collaborate on this mind map.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open Document") {
                        // Close the share acceptance view
                        NotificationCenter.default.post(name: NSNotification.Name("CloseShareAcceptance"), object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                // Share info and accept button
                VStack(spacing: 16) {
                    // Share URL info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share Details")
                            .font(.headline)
                        
                        Text("You've been invited to collaborate on a mind map.")
                            .foregroundColor(.secondary)
                        
                        if let metadata = shareMetadata {
                            Text("Document: \(metadata.share[CKShare.SystemFieldKey.title] as? String ?? "Unknown")")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Accept button
                    HStack {
                        if isAccepting {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Accepting...")
                                .font(.subheadline)
                        } else {
                            Button("Accept Share") {
                                acceptShare()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear {
            loadShareMetadata()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
    
    private func loadShareMetadata() {
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.sharnabhB.MindFlow")
                let metadata = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare.Metadata, Error>) in
                    container.fetchShareMetadata(with: shareURL) { metadata, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let metadata = metadata {
                            continuation.resume(returning: metadata)
                        } else {
                            continuation.resume(throwing: NSError(domain: "CloudKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No metadata returned"]))
                        }
                    }
                }
                await MainActor.run {
                    self.shareMetadata = metadata
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load share details: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func acceptShare() {
        guard let metadata = shareMetadata else { return }
        
        isAccepting = true
        errorMessage = nil
        
        Task {
            do {
                try await CollaborationService.shared.acceptShare(from: metadata)
                await MainActor.run {
                    self.shareAccepted = true
                    self.isAccepting = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to accept share: \(error.localizedDescription)"
                    self.showingError = true
                    self.isAccepting = false
                }
            }
        }
    }
}

// MARK: - Share Acceptance Overlay
struct ShareAcceptanceOverlay: View {
    @State private var shareURL: URL?
    @State private var showingShareAcceptance = false
    
    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowShareAcceptance"))) { notification in
                if let url = notification.userInfo?["shareURL"] as? URL {
                    shareURL = url
                    showingShareAcceptance = true
                }
            }
            .sheet(isPresented: $showingShareAcceptance) {
                if let url = shareURL {
                    ShareAcceptanceView(shareURL: url)
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseShareAcceptance"))) { _ in
                            showingShareAcceptance = false
                        }
                }
            }
    }
}

struct CollaborationPanel: View {
    @ObservedObject private var collaborationService = CollaborationService.shared
    let document: MindMapDocument
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var isSharing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                Text("Collaboration")
                    .font(.headline)
                Spacer()
                
                if isShared {
                    Button("Stop Sharing") {
                        stopSharing()
                    }
                    .buttonStyle(.bordered)
                } else {
                    HStack {
                        if isSharing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Sharing...")
                                .font(.caption)
                        } else {
                            Button("Share Document") {
                                shareDocument()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            
            if isShared {
                // Show collaborators
                collaboratorsSection
                
                // Share link section
                shareLinkSection
                
                // Live users section
                liveUsersSection
            } else {
                // Not shared yet
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("Start collaborating")
                        .font(.headline)
                    Text("Share this mind map to work together in real-time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url]) {
                    showingShareSheet = false
                }
            }
        }
        .alert("Sharing Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
    
    private var isShared: Bool {
        collaborationService.activeCollaborations[document.id] != nil
    }
    
    private var collaboratorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collaborators")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let collaboration = collaborationService.activeCollaborations[document.id] {
                ForEach(collaboration.participants, id: \.userIdentity.userRecordID) { participant in
                    CollaboratorRow(participant: participant)
                }
            }
        }
    }
    
    private var shareLinkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Share Link")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text("Anyone with this link can edit")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Copy Link") {
                    copyShareLink()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Share...") {
                    showingShareSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private var liveUsersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Currently Active")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if collaborationService.liveUsers.isEmpty {
                Text("No one else is currently editing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(collaborationService.liveUsers.values), id: \.userID) { presence in
                    LiveUserRow(presence: presence)
                }
            }
        }
    }
    
    private func shareDocument() {
        print("🔄 Starting document sharing process...")
        isSharing = true
        errorMessage = nil
        
        Task {
            do {
                // First check CloudKit availability
                print("🔍 Checking CloudKit availability...")
                let container = CKContainer(identifier: "iCloud.com.sharnabhB.MindFlow")
                let status = try await container.accountStatus()
                
                if status != .available {
                    throw NSError(domain: "CloudKitError", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "iCloud account not available. Please sign in to iCloud in System Preferences."
                    ])
                }
                print("✅ CloudKit account is available")
                
                print("📄 Converting document to CloudKit record...")
                let share = try await collaborationService.shareDocument(document)
                
                await MainActor.run {
                    // Get the custom URL from collaboration info instead of CloudKit share URL
                    if let collaborationInfo = collaborationService.activeCollaborations[document.id] {
                        print("✅ Share created successfully: \(collaborationInfo.shareURL.absoluteString)")
                        shareURL = collaborationInfo.shareURL
                    } else {
                        print("❌ No collaboration info found")
                        shareURL = share.url // Fallback to CloudKit URL
                    }
                    showingShareSheet = true
                    isSharing = false
                }
            } catch {
                print("❌ Failed to share document: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to share document: \(error.localizedDescription)"
                    showingError = true
                    isSharing = false
                }
            }
        }
    }
    
    private func stopSharing() {
        Task {
            try await collaborationService.stopSharing(document)
        }
    }
    
    private func copyShareLink() {
        if let url = shareURL {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(url.absoluteString, forType: .string)
        }
    }
}

struct CollaboratorRow: View {
    let participant: CKShare.Participant
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.displayName)
                    .font(.body)
                Text(permissionText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if participant.role == .owner {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch participant.acceptanceStatus {
        case .accepted: return .green
        case .pending: return .orange
        case .removed: return .red
        @unknown default: return .gray
        }
    }
    
    private var permissionText: String {
        switch participant.permission {
        case .readOnly: return "Can view"
        case .readWrite: return "Can edit"
        @unknown default: return "Unknown"
        }
    }
}

struct LiveUserRow: View {
    let presence: UserPresence
    
    var body: some View {
        HStack {
            Circle()
                .fill(presence.color)
                .frame(width: 12, height: 12)
            
            Text(presence.displayName)
                .font(.body)
            
            Spacer()
            
            Text("Active now")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(.vertical, 2)
    }
}

// Live cursor overlay for the canvas
struct LiveCursorOverlay: View {
    @ObservedObject private var collaborationService = CollaborationService.shared
    let canvasSize: CGSize
    let scale: CGFloat
    let offset: CGPoint
    
    var body: some View {
        ForEach(Array(collaborationService.liveUsers.values), id: \.userID) { presence in
            if let cursorPosition = presence.cursorPosition {
                LiveCursor(
                    user: presence,
                    position: convertToCanvasPosition(cursorPosition)
                )
            }
        }
    }
    
    private func convertToCanvasPosition(_ worldPosition: CGPoint) -> CGPoint {
        return CGPoint(
            x: (worldPosition.x + offset.x) * scale,
            y: (worldPosition.y + offset.y) * scale
        )
    }
}

struct LiveCursor: View {
    let user: UserPresence
    let position: CGPoint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Cursor pointer
            Image(systemName: "cursor.rays")
                .foregroundColor(user.color)
                .font(.system(size: 16))
            
            // User name label
            Text(user.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(user.color)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .position(position)
        .animation(.easeInOut(duration: 0.2), value: position)
    }
}

// Share sheet for macOS
struct ShareSheet: NSViewRepresentable {
    let activityItems: [Any]
    let onDismiss: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: self.activityItems)
            picker.delegate = context.coordinator
            
            // Show the picker from the view
            if let window = view.window {
                let rect = NSRect(x: 0, y: 0, width: 1, height: 1)
                picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, NSSharingServicePickerDelegate {
        let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            onDismiss()
        }
    }
}

// Conflict resolution dialog
struct ConflictResolutionDialog: View {
    let localChange: String
    let remoteChange: String
    let onResolve: (Bool) -> Void // true for remote, false for local
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Editing Conflict")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Someone else made changes to the same element")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your changes:")
                        .font(.headline)
                    Text(localChange)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Their changes:")
                        .font(.headline)
                    Text(remoteChange)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: 12) {
                Button("Keep Mine") {
                    onResolve(false)
                }
                .buttonStyle(.bordered)
                
                Button("Use Theirs") {
                    onResolve(true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    let sampleDocument = MindMapDocument(filename: "Sample.mindflow")
    return CollaborationPanel(document: sampleDocument)
        .frame(width: 300, height: 400)
}
