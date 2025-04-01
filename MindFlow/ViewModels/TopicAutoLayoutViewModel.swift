import SwiftUI
import AppKit

// Define a simple protocol for layout algorithms
protocol LayoutAlgorithm {
    func layout(_ topics: [Topic]) async throws -> [Topic]
}

class TopicAutoLayoutViewModel: ObservableObject {
    @Published var isLayouting: Bool = false
    @Published var layoutProgress: Double = 0
    @Published var layoutError: String?
    
    private var layoutAlgorithm: LayoutAlgorithm
    
    init(layoutAlgorithm: LayoutAlgorithm) {
        self.layoutAlgorithm = layoutAlgorithm
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoLayoutRequest),
            name: NSNotification.Name("AutoLayoutRequest"),
            object: nil
        )
    }
    
    @objc private func handleAutoLayoutRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let topics = userInfo["topics"] as? [Topic] else { return }
        
        performAutoLayout(topics)
    }
    
    func performAutoLayout(_ topics: [Topic]) {
        isLayouting = true
        layoutProgress = 0
        layoutError = nil
        
        Task {
            do {
                let progress = Progress(totalUnitCount: 100)
                
                for i in 0...100 {
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
                    await MainActor.run {
                        layoutProgress = Double(i) / 100
                    }
                    progress.completedUnitCount = Int64(i)
                }
                
                let layoutedTopics = try await layoutAlgorithm.layout(topics)
                
                await MainActor.run {
                    isLayouting = false
                    layoutProgress = 1
                }
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("TopicsLayouted"),
                    object: nil,
                    userInfo: ["topics": layoutedTopics]
                )
            } catch {
                await MainActor.run {
                    isLayouting = false
                    layoutError = error.localizedDescription
                }
            }
        }
    }
    
    func setLayoutAlgorithm(_ algorithm: LayoutAlgorithm) {
        self.layoutAlgorithm = algorithm
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 