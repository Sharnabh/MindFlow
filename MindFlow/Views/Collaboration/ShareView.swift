import SwiftUI
import Combine

/// A view for sharing a document with others
struct ShareView: View {
    @EnvironmentObject var authService: AuthenticationService
    @ObservedObject var viewModel: ShareViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var emailToInvite = ""
    @State private var selectedAccessLevel: DocumentAccessLevel = .edit
    @State private var linkCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Share Document")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding()
            .background(Color(.secondarySystemFill))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current collaborators
                    if !viewModel.collaborators.isEmpty {
                        collaboratorList
                    }
                    
                    // Invite by email
                    inviteByEmail
                    
                    // Share link
                    shareLink
                }
                .padding()
            }
            
            Divider()
            
            // Footer with done button
            HStack {
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .background(Color(.systemFill))
        .onAppear {
            viewModel.loadCollaborators()
            viewModel.createShareLink()
        }
    }
    
    // MARK: - Subviews
    
    private var collaboratorList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People with access")
                .font(.headline)
            
            Divider()
            
            collaboratorListContent
        }
    }
    
    private var collaboratorListContent: some View {
        ForEach(viewModel.collaborators, id: \.id) { collaborator in
            CollaboratorRow(
                collaborator: collaborator,
                currentUserId: authService.currentUser?.id,
                onUpdateAccess: { accessLevel in
                    viewModel.updateCollaboratorAccess(
                        userId: collaborator.id,
                        accessLevel: accessLevel
                    )
                },
                onRemove: {
                    viewModel.removeCollaborator(id: collaborator.id)
                }
            )
            .padding(.vertical, 4)
        }
    }
    
    private var inviteByEmail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite people")
                .font(.headline)
            
            HStack {
                TextField("Email address", text: $emailToInvite)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Menu {
                    ForEach(DocumentAccessLevel.allCases.filter { $0 != .owner }, id: \.self) { level in
                        Button(action: {
                            selectedAccessLevel = level
                        }) {
                            Text(level.displayName)
                            if selectedAccessLevel == level {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Text(selectedAccessLevel.displayName)
                        .frame(width: 100)
                }
                .menuStyle(BorderedButtonMenuStyle())
                
                Button(action: {
                    viewModel.inviteUser(email: emailToInvite, accessLevel: selectedAccessLevel)
                    emailToInvite = ""
                }) {
                    Text("Invite")
                }
                .buttonStyle(.borderedProminent)
                .disabled(emailToInvite.isEmpty || !emailToInvite.isValidEmail())
            }
            
            if viewModel.isInviting {
                ProgressView()
                    .padding(.top, 4)
            }
            
            if let error = viewModel.inviteError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
    }
    
    private var shareLink: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share link")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Anyone with this link can view this document")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    if let shareLink = viewModel.shareLink {
                        Text(shareLink)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemFill))
                            .cornerRadius(6)
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(shareLink, forType: .string)
                            withAnimation {
                                linkCopied = true
                            }
                            
                            // Reset the copied state after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    linkCopied = false
                                }
                            }
                        }) {
                            if linkCopied {
                                Label("Copied", systemImage: "checkmark")
                                    .foregroundColor(.green)
                            } else {
                                Text("Copy")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(linkCopied)
                    } else if viewModel.isCreatingLink {
                        ProgressView()
                    } else {
                        Text("Failed to create share link")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Button("Retry") {
                            viewModel.createShareLink()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(Color(.tertiarySystemFill))
            .cornerRadius(8)
        }
    }
}

// MARK: - Extensions

extension DocumentAccessLevel {
    static var allCases: [DocumentAccessLevel] {
        [.viewOnly, .comment, .edit, .owner]
    }
    
    var displayName: String {
        switch self {
        case .viewOnly:
            return "View only"
        case .comment:
            return "Can comment"
        case .edit:
            return "Can edit"
        case .owner:
            return "Owner"
        }
    }
}

extension String {
    func isValidEmail() -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
}

// MARK: - View Model

class ShareViewModel: ObservableObject {
    @Published var collaborators: [DocumentCollaborator] = []
    @Published var shareLink: String?
    @Published var isCreatingLink = false
    @Published var isInviting = false
    @Published var inviteError: String?
    
    private let documentId: String
    private let documentSharingService: DocumentSharingService
    private var cancellables = Set<AnyCancellable>()
    
    init(documentId: String, documentSharingService: DocumentSharingService) {
        self.documentId = documentId
        self.documentSharingService = documentSharingService
    }
    
    func loadCollaborators() {
        documentSharingService.getDocumentCollaborators(documentId: documentId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to load collaborators: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] collaborators in
                    self?.collaborators = collaborators
                }
            )
            .store(in: &cancellables)
    }
    
    func createShareLink() {
        isCreatingLink = true
        
        documentSharingService.createShareLink(
            documentId: documentId,
            accessLevel: .viewOnly
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isCreatingLink = false
                
                if case .failure(let error) = completion {
                    print("Failed to create share link: \(error.localizedDescription)")
                }
            },
            receiveValue: { [weak self] shareLink in
                self?.shareLink = shareLink
            }
        )
        .store(in: &cancellables)
    }
    
    func inviteUser(email: String, accessLevel: DocumentAccessLevel) {
        guard !email.isEmpty, email.isValidEmail() else {
            inviteError = "Invalid email address"
            return
        }
        
        isInviting = true
        inviteError = nil
        
        documentSharingService.inviteUserToDocument(
            email: email,
            documentId: documentId,
            accessLevel: accessLevel
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isInviting = false
                
                if case .failure(let error) = completion {
                    self?.inviteError = error.localizedDescription
                }
            },
            receiveValue: { [weak self] success in
                if success {
                    // Reload collaborators
                    self?.loadCollaborators()
                }
            }
        )
        .store(in: &cancellables)
    }
    
    func updateCollaboratorAccess(userId: String, accessLevel: DocumentAccessLevel) {
        documentSharingService.updateCollaboratorAccess(
            userId: userId,
            documentId: documentId,
            accessLevel: accessLevel
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Failed to update access: \(error.localizedDescription)")
                }
            },
            receiveValue: { [weak self] success in
                if success {
                    // Update the local collaborator
                    if let index = self?.collaborators.firstIndex(where: { $0.id == userId }) {
                        // Create a new collaborator with updated access level
                        let oldCollaborator = self?.collaborators[index]
                        guard let oldCollaborator = oldCollaborator else { return }
                        
                        let updatedCollaborator = DocumentCollaborator(
                            id: oldCollaborator.id,
                            email: oldCollaborator.email,
                            displayName: oldCollaborator.displayName,
                            photoURL: oldCollaborator.photoURL,
                            accessLevel: accessLevel,
                            joinedAt: oldCollaborator.joinedAt,
                            lastActive: oldCollaborator.lastActive,
                            invitedBy: oldCollaborator.invitedBy,
                            status: oldCollaborator.status
                        )
                        
                        self?.collaborators[index] = updatedCollaborator
                    }
                }
            }
        )
        .store(in: &cancellables)
    }
    
    func removeCollaborator(id: String) {
        documentSharingService.removeCollaborator(userId: id, documentId: documentId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to remove collaborator: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        // Remove from the local list
                        self?.collaborators.removeAll { $0.id == id }
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// Add this new view after the ShareViewModel class
struct CollaboratorRow: View {
    let collaborator: DocumentCollaborator
    let currentUserId: String?
    let onUpdateAccess: (DocumentAccessLevel) -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            // Avatar
            collaboratorAvatar
            
            // Info
            collaboratorInfo
            
            Spacer()
            
            // Role menu
            collaboratorAccessMenu
        }
    }
    
    private var collaboratorAvatar: some View {
        Group {
            if let photoURL = collaborator.photoURL {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } placeholder: {
                    initialsAvatar
                }
            } else {
                initialsAvatar
            }
        }
    }
    
    private var initialsAvatar: some View {
        Text(collaborator.displayName.prefix(1).uppercased())
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.accentColor))
    }
    
    private var collaboratorInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(collaborator.displayName)
                    .font(.body)
                
                if collaborator.id == currentUserId {
                    Text("(you)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(collaborator.email)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var collaboratorAccessMenu: some View {
        Menu {
            ForEach(DocumentAccessLevel.allCases, id: \.self) { level in
                Button(action: {
                    onUpdateAccess(level)
                }) {
                    Text(level.displayName)
                    if collaborator.accessLevel == level {
                        Image(systemName: "checkmark")
                    }
                }
                .disabled(
                    collaborator.id == currentUserId || 
                    collaborator.accessLevel == .owner
                )
            }
            
            Divider()
            
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
            .disabled(
                collaborator.id == currentUserId || 
                collaborator.accessLevel == .owner
            )
        } label: {
            Text(collaborator.accessLevel.displayName)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill))
                .cornerRadius(4)
        }
    }
} 
