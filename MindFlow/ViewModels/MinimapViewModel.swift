import SwiftUI
import AppKit

class MinimapViewModel: ObservableObject {
    @Published var isVisible: Bool = true
    @Published var size: CGSize = CGSize(width: 200, height: 150)
    @Published var position: CGPoint = CGPoint(x: 20, y: 20)
    @Published var scale: CGFloat = 0.1
    @Published var minimapError: String?
    
    private let minSize: CGFloat = 100
    private let maxSize: CGFloat = 400
    private let sizeStep: CGFloat = 50
    
    let topics: [Topic]
    let visibleRect: CGRect
    let topicsBounds: CGRect
    let onTapLocation: (CGPoint) -> Void
    
    init(topics: [Topic] = [], 
         visibleRect: CGRect = .zero, 
         topicsBounds: CGRect = .zero, 
         size: CGSize = CGSize(width: 200, height: 150), 
         onTapLocation: @escaping (CGPoint) -> Void = { _ in }) {
        self.topics = topics
        self.visibleRect = visibleRect
        self.topicsBounds = topicsBounds
        self.size = size
        self.onTapLocation = onTapLocation
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMinimapToggle),
            name: NSNotification.Name("MinimapToggle"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMinimapSizeChange),
            name: NSNotification.Name("MinimapSizeChange"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMinimapPositionChange),
            name: NSNotification.Name("MinimapPositionChange"),
            object: nil
        )
    }
    
    @objc private func handleMinimapToggle() {
        isVisible.toggle()
        minimapError = nil
    }
    
    @objc private func handleMinimapSizeChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let size = userInfo["size"] as? CGSize else { return }
        
        updateSize(to: size)
    }
    
    @objc private func handleMinimapPositionChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let position = userInfo["position"] as? CGPoint else { return }
        
        updatePosition(to: position)
    }
    
    func toggleMinimap() {
        isVisible.toggle()
        minimapError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("MinimapChanged"),
            object: nil,
            userInfo: ["isVisible": isVisible]
        )
    }
    
    func increaseSize() {
        let newSize = CGSize(
            width: min(size.width + sizeStep, maxSize),
            height: min(size.height + sizeStep, maxSize)
        )
        updateSize(to: newSize)
    }
    
    func decreaseSize() {
        let newSize = CGSize(
            width: max(size.width - sizeStep, minSize),
            height: max(size.height - sizeStep, minSize)
        )
        updateSize(to: newSize)
    }
    
    func updateSize(to size: CGSize) {
        self.size = size
        minimapError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("MinimapChanged"),
            object: nil,
            userInfo: ["size": size]
        )
    }
    
    func updatePosition(to position: CGPoint) {
        self.position = position
        minimapError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("MinimapChanged"),
            object: nil,
            userInfo: ["position": position]
        )
    }
    
    // Helper function to check if any topic has curved style
    func hasCurvedStyle(_ topics: [Topic]) -> Bool {
        for topic in topics {
            if topic.branchStyle == .curved {
                return true
            }
            if hasCurvedStyle(topic.subtopics) {
                return true
            }
        }
        return false
    }
    
    func scaleToMinimap(_ point: CGPoint) -> CGPoint {
        guard !topicsBounds.isEmpty else { return .zero }
        
        let scaleX = size.width / topicsBounds.width
        let scaleY = size.height / topicsBounds.height
        let scale = min(scaleX, scaleY)
        
        return CGPoint(
            x: (point.x - topicsBounds.minX) * scale,
            y: (point.y - topicsBounds.minY) * scale
        )
    }
    
    func handleTap(at point: CGPoint) {
        onTapLocation(point)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 