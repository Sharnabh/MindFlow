import SwiftUI
import AppKit

class TopicFileViewModel: ObservableObject {
    @Published var isSaving: Bool = false
    @Published var isLoading: Bool = false
    @Published var saveError: String?
    @Published var loadError: String?
    @Published var currentFile: URL?
    
    private let fileManager: MindFlowFileManager
    
    init(fileManager: MindFlowFileManager = MindFlowFileManager.shared) {
        self.fileManager = fileManager
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSaveRequest),
            name: NSNotification.Name("SaveRequest"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLoadRequest),
            name: NSNotification.Name("LoadRequest"),
            object: nil
        )
    }
    
    @objc private func handleSaveRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let topics = userInfo["topics"] as? [Topic] else { return }
        
        saveTopics(topics)
    }
    
    @objc private func handleLoadRequest(_ notification: Notification) {
        loadTopics()
    }
    
    func saveTopics(_ topics: [Topic]) {
        isSaving = true
        saveError = nil
        
        fileManager.saveCurrentFile(topics: topics) { success, error in
            DispatchQueue.main.async {
                self.isSaving = false
                
                if !success, let errorMessage = error {
                    self.saveError = errorMessage
                }
            }
        }
    }
    
    func loadTopics() {
        isLoading = true
        loadError = nil
        
        fileManager.loadFile { topics, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let errorMessage = error {
                    self.loadError = errorMessage
                    return
                }
                
                if let topics = topics {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TopicsLoaded"),
                        object: nil,
                        userInfo: ["topics": topics]
                    )
                }
            }
        }
    }
    
    func saveAs() {
        fileManager.saveFileAs(topics: []) { success, error in
            DispatchQueue.main.async {
                if !success, let errorMessage = error {
                    self.saveError = errorMessage
                }
            }
        }
    }
    
    func open() {
        fileManager.loadFile { topics, error in
            DispatchQueue.main.async {
                if let errorMessage = error {
                    self.loadError = errorMessage
                    return
                }
                
                if let topics = topics {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TopicsLoaded"),
                        object: nil,
                        userInfo: ["topics": topics]
                    )
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 