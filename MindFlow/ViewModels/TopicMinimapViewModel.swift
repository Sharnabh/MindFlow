import SwiftUI
import AppKit

class TopicMinimapViewModel: ObservableObject {
    @Published var isVisible: Bool = true
    @Published var size: CGSize = CGSize(width: 200, height: 150)
    @Published var position: CGPoint = .zero
    @Published var scale: CGFloat = 0.1
    @Published var minimapError: String?
    
    private let minSize: CGSize = CGSize(width: 100, height: 75)
    private let maxSize: CGSize = CGSize(width: 400, height: 300)
    private let sizeStep: CGFloat = 20
    
    init() {
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
        toggleMinimap()
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
            width: min(size.width + sizeStep, maxSize.width),
            height: min(size.height + sizeStep, maxSize.height)
        )
        updateSize(to: newSize)
    }
    
    func decreaseSize() {
        let newSize = CGSize(
            width: max(size.width - sizeStep, minSize.width),
            height: max(size.height - sizeStep, minSize.height)
        )
        updateSize(to: newSize)
    }
    
    func updateSize(to newSize: CGSize) {
        size = newSize
        minimapError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("MinimapChanged"),
            object: nil,
            userInfo: ["size": size]
        )
    }
    
    func updatePosition(to newPosition: CGPoint) {
        position = newPosition
        minimapError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("MinimapChanged"),
            object: nil,
            userInfo: ["position": position]
        )
    }
    
    func getMinimapRect() -> CGRect {
        CGRect(origin: position, size: size)
    }
    
    func getMinimapPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: position.x + point.x * scale,
            y: position.y + point.y * scale
        )
    }
    
    func getCanvasPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - position.x) / scale,
            y: (point.y - position.y) / scale
        )
    }
    
    func getMinimapSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }
    
    func getCanvasSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width / scale,
            height: size.height / scale
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 