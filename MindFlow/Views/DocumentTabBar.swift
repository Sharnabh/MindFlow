import SwiftUI

struct DocumentTabBar: View {
    @ObservedObject var documentManager = DocumentManager.shared
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(documentManager.documents.enumerated()), id: \.element.id) { index, document in
                    documentTab(document: document, index: index)
                }
                
                // Add new document button
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowTemplateSelection"), object: nil)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 30)
        .background(Color(.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    func documentTab(document: MindMapDocument, index: Int) -> some View {
        HStack(spacing: 4) {
            // Document name
            Text(document.filename)
                .font(.system(size: 12))
                .lineLimit(1)
                .padding(.leading, 8)
            
            // Close button
            Button(action: {
                documentManager.closeDocument(at: index)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(.vertical, 4)
        .frame(minWidth: 100, maxWidth: 180)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(documentManager.activeDocumentIndex == index 
                      ? Color.accentColor.opacity(0.2)
                      : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(documentManager.activeDocumentIndex == index 
                        ? Color.accentColor
                        : Color.gray.opacity(0.3), 
                        lineWidth: 0.5)
        )
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            documentManager.activeDocumentIndex = index
        }
    }
}

#Preview {
    DocumentTabBar()
} 