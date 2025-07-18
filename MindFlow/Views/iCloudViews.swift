import SwiftUI

// iCloud status indicator view
struct iCloudStatusView: View {
    @ObservedObject private var documentManager = DocumentManager.shared
    @EnvironmentObject private var iCloudService: iCloudService
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iCloudService.isAvailable ? "icloud.fill" : "icloud.slash")
                .foregroundColor(iCloudService.isAvailable ? .blue : .gray)
                .font(.system(size: 16))
            
            Text(iCloudService.isAvailable ? "iCloud" : "iCloud Unavailable")
                .font(.caption)
                .foregroundColor(iCloudService.isAvailable ? .primary : .secondary)
            
            if let activeDocument = documentManager.activeDocument,
               let url = activeDocument.url,
               documentManager.isiCloudDocument(activeDocument) {
                syncStatusIcon(for: url)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private func syncStatusIcon(for url: URL) -> some View {
        if let status = documentManager.getiCloudSyncStatus(for: url) {
            switch status {
            case .notDownloaded:
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundColor(.orange)
            case .downloading(let progress):
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.5)
            case .downloaded:
                Image(systemName: "checkmark.icloud")
                    .foregroundColor(.green)
            case .uploading(let progress):
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.5)
            case .conflict:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundColor(.red)
            case .error:
                Image(systemName: "xmark.icloud")
                    .foregroundColor(.red)
            }
        }
    }
}

// iCloud document picker
struct iCloudDocumentPicker: View {
    @ObservedObject private var documentManager = DocumentManager.shared
    @EnvironmentObject private var iCloudService: iCloudService
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let onDocumentSelected: (URL) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("iCloud Documents")
                    .font(.headline)
                
                Spacer()
                
                Button("Refresh") {
                    refreshDocuments()
                }
                .disabled(isLoading)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading iCloud documents...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if iCloudService.documents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "icloud")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No iCloud documents found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Save a document to iCloud to see it here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200))
                ], spacing: 12) {
                    ForEach(iCloudService.documents, id: \.self) { url in
                        iCloudDocumentCard(url: url) {
                            onDocumentSelected(url)
                        }
                    }
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .onAppear {
            refreshDocuments()
        }
    }
    
    private func refreshDocuments() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await documentManager.refreshiCloudDocuments()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// Individual iCloud document card
struct iCloudDocumentCard: View {
    let url: URL
    let onTap: () -> Void
    
    @ObservedObject private var documentManager = DocumentManager.shared
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Spacer()
                
                syncStatusView
            }
            
            Text(url.lastPathComponent)
                .font(.headline)
                .lineLimit(2)
            
            Text(url.deletingLastPathComponent().lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            HStack {
                Button("Open") {
                    onTap()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Menu {
                    Button("Delete") {
                        deleteDocument()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    @ViewBuilder
    private var syncStatusView: some View {
        if let status = documentManager.getiCloudSyncStatus(for: url) {
            switch status {
            case .notDownloaded:
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundColor(.orange)
            case .downloading(let progress):
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.7)
            case .downloaded:
                Image(systemName: "checkmark.icloud")
                    .foregroundColor(.green)
            case .uploading(let progress):
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.7)
            case .conflict:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundColor(.red)
            case .error:
                Image(systemName: "xmark.icloud")
                    .foregroundColor(.red)
            }
        }
    }
    
    private func deleteDocument() {
        Task {
            do {
                try await documentManager.deleteiCloudDocument(at: url)
            } catch {
                print("Failed to delete document: \(error)")
            }
        }
    }
}

// iCloud save dialog
struct iCloudSaveDialog: View {
    @Binding var isPresented: Bool
    let document: MindMapDocument
    let onSave: (URL) -> Void
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Save to iCloud")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Document: \(document.filename)")
                    .font(.headline)
                
                Text("This will save your mind map to iCloud, making it available on all your devices.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save to iCloud") {
                    saveTiCloud()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
        }
        .padding()
        .frame(width: 400)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    private func saveTiCloud() {
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                let savedURL = try await DocumentManager.shared.saveToiCloud(document: document)
                await MainActor.run {
                    isSaving = false
                    onSave(savedURL)
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    VStack {
        iCloudStatusView()
        Divider()
        iCloudDocumentPicker { url in
            print("Selected: \(url)")
        }
    }
    .padding()
}
