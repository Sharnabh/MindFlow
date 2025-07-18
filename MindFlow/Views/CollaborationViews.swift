import SwiftUI
import CloudKit

// MARK: - Collaboration UI Components

struct CollaborationPanel: View {
    @ObservedObject private var collaborationService = CollaborationService.shared
    let document: MindMapDocument
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    
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
                    Button("Share Document") {
                        shareDocument()
                    }
                    .buttonStyle(.borderedProminent)
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
        Task {
            do {
                let share = try await collaborationService.shareDocument(document)
                await MainActor.run {
                    shareURL = share.url
                    showingShareSheet = true
                }
            } catch {
                // Handle error
                print("Failed to share document: \(error)")
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
