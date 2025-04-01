import SwiftUI
import AppKit

class TopicPanViewModel: ObservableObject {
    @Published var isPanning: Bool = false
    @Published var panOffset: CGSize = .zero
    @Published var lastPanLocation: CGPoint = .zero
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePanStart),
            name: NSNotification.Name("PanStart"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePanMove),
            name: NSNotification.Name("PanMove"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePanEnd),
            name: NSNotification.Name("PanEnd"),
            object: nil
        )
    }
    
    @objc private func handlePanStart(_ notification: Notification) {
        guard let location = notification.userInfo?["location"] as? CGPoint else { return }
        isPanning = true
        lastPanLocation = location
    }
    
    @objc private func handlePanMove(_ notification: Notification) {
        guard let location = notification.userInfo?["location"] as? CGPoint else { return }
        let delta = CGSize(
            width: location.x - lastPanLocation.x,
            height: location.y - lastPanLocation.y
        )
        panOffset = CGSize(
            width: panOffset.width + delta.width,
            height: panOffset.height + delta.height
        )
        lastPanLocation = location
    }
    
    @objc private func handlePanEnd() {
        isPanning = false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 