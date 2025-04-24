import SwiftUI

/// A view that displays the avatar and status of active collaborators
struct CollaboratorIndicator: View {
    let collaborator: Collaborator
    let showLabel: Bool
    
    init(collaborator: Collaborator, showLabel: Bool = false) {
        self.collaborator = collaborator
        self.showLabel = showLabel
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar
            ZStack {
                // Background circle with collaborator's color
                Circle()
                    .fill(Color(hex: collaborator.color) ?? .blue)
                    .frame(width: 32, height: 32)
                
                if let photoURL = collaborator.photoURL {
                    // User photo
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    } placeholder: {
                        // Initial while loading
                        Text(collaborator.displayName.prefix(1).uppercased())
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    // Initial if no photo
                    Text(collaborator.displayName.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Online indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.5)
                    )
                    .position(x: 26, y: 26)
            }
            
            // Name label (optional)
            if showLabel {
                Text(collaborator.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
        }
    }
}

/// A view that displays all active collaborators in a document
struct CollaboratorsView: View {
    @ObservedObject var collaborationService: CollaborationService
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header
            HStack {
                Text("Collaborators")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(collaborationService.collaborators.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Collaborator list
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    if collaborationService.collaborators.isEmpty {
                        Text("No active collaborators")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(collaborationService.collaborators) { collaborator in
                            CollaboratorIndicator(collaborator: collaborator, showLabel: true)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Divider()
                
                // Share button
                Button(action: {
                    // Trigger sharing flow (we'll implement this later)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowSharingOptions"),
                        object: nil
                    )
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 14))
                        
                        Text("Invite Collaborators")
                            .font(.subheadline)
                    }
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .background(Color(.secondarySystemFill))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .frame(width: 240)
    }
}

/// A view that shows collaborator cursors on the canvas
struct CollaboratorCursor: View {
    let collaborator: Collaborator
    let position: CGPoint
    
    var body: some View {
        VStack(spacing: 0) {
            // Cursor
            Image(systemName: "cursor.rays")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: collaborator.color) ?? .blue)
                .offset(x: -2, y: -2) // Adjust to align cursor point correctly
            
            // Name tag
            Text(collaborator.displayName)
                .font(.system(size: 11))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: collaborator.color)?.opacity(0.2) ?? Color.blue.opacity(0.2))
                .foregroundColor(Color(hex: collaborator.color) ?? .blue)
                .cornerRadius(4)
                .offset(y: -4)
        }
        .position(position)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: position)
    }
} 
