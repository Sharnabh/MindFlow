import SwiftUI
import AppKit

class TopicResizeViewModel: ObservableObject {
    @Published var resizeError: String?
    @Published var isResizing: Bool = false
    @Published var currentHandle: ResizeHandle?
    @Published var originalSize: CGSize?
    @Published var originalPosition: CGPoint?
    
    private let topic: Topic
    
    init(topic: Topic) {
        self.topic = topic
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResizeStart),
            name: NSNotification.Name("ResizeStart"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResizeEnd),
            name: NSNotification.Name("ResizeEnd"),
            object: nil
        )
    }
    
    @objc private func handleResizeStart(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let handle = userInfo["handle"] as? ResizeHandle else { return }
        
        isResizing = true
        currentHandle = handle
        originalSize = topic.size
        originalPosition = topic.position
    }
    
    @objc private func handleResizeEnd() {
        isResizing = false
        currentHandle = nil
        originalSize = nil
        originalPosition = nil
    }
    
    func startResize(handle: ResizeHandle) {
        resizeError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ResizeStart"),
            object: nil,
            userInfo: ["handle": handle]
        )
    }
    
    func endResize() {
        resizeError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ResizeEnd"),
            object: nil
        )
    }
    
    func updateSize(delta: CGSize) {
        guard let originalSize = originalSize else { return }
        
        var newSize = originalSize
        var newPosition = originalPosition ?? topic.position
        
        switch currentHandle {
        case .topLeft:
            newSize.width -= delta.width
            newSize.height -= delta.height
            newPosition.x += delta.width
            newPosition.y += delta.height
            
        case .top:
            newSize.height -= delta.height
            newPosition.y += delta.height
            
        case .topRight:
            newSize.width += delta.width
            newSize.height -= delta.height
            newPosition.y += delta.height
            
        case .right:
            newSize.width += delta.width
            
        case .bottomRight:
            newSize.width += delta.width
            newSize.height += delta.height
            
        case .bottom:
            newSize.height += delta.height
            
        case .bottomLeft:
            newSize.width -= delta.width
            newSize.height += delta.height
            newPosition.x += delta.width
            
        case .left:
            newSize.width -= delta.width
            newPosition.x += delta.width
            
        case .none:
            return
        }
        
        // Ensure minimum size
        newSize.width = max(100, newSize.width)
        newSize.height = max(50, newSize.height)
        
        resizeError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("TopicResize"),
            object: nil,
            userInfo: [
                "size": newSize,
                "position": newPosition
            ]
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 