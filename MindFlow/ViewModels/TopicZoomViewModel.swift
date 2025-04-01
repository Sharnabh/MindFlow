import SwiftUI
import AppKit

class TopicZoomViewModel: ObservableObject {
    @Published var scale: CGFloat = 1.0
    @Published var minScale: CGFloat = 0.1
    @Published var maxScale: CGFloat = 5.0
    @Published var zoomCenter: CGPoint = .zero
    @Published var isZooming: Bool = false
    @Published var zoomError: String?
    
    private let zoomStep: CGFloat = 0.1
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleZoomIn),
            name: NSNotification.Name("ZoomIn"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleZoomOut),
            name: NSNotification.Name("ZoomOut"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleZoomReset),
            name: NSNotification.Name("ZoomReset"),
            object: nil
        )
    }
    
    @objc private func handleZoomIn() {
        zoomIn()
    }
    
    @objc private func handleZoomOut() {
        zoomOut()
    }
    
    @objc private func handleZoomReset() {
        resetZoom()
    }
    
    func zoomIn() {
        let newScale = min(scale + zoomStep, maxScale)
        updateZoom(to: newScale)
    }
    
    func zoomOut() {
        let newScale = max(scale - zoomStep, minScale)
        updateZoom(to: newScale)
    }
    
    func resetZoom() {
        updateZoom(to: 1.0)
    }
    
    func updateZoom(to newScale: CGFloat) {
        isZooming = true
        zoomError = nil
        
        let oldScale = scale
        scale = newScale
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ZoomChanged"),
            object: nil,
            userInfo: [
                "oldScale": oldScale,
                "newScale": newScale,
                "center": zoomCenter
            ]
        )
        
        isZooming = false
    }
    
    func setZoomCenter(_ point: CGPoint) {
        zoomCenter = point
    }
    
    func getZoomedPoint(_ point: CGPoint) -> CGPoint {
        let dx = point.x - zoomCenter.x
        let dy = point.y - zoomCenter.y
        
        return CGPoint(
            x: zoomCenter.x + dx * scale,
            y: zoomCenter.y + dy * scale
        )
    }
    
    func getUnzoomedPoint(_ point: CGPoint) -> CGPoint {
        let dx = point.x - zoomCenter.x
        let dy = point.y - zoomCenter.y
        
        return CGPoint(
            x: zoomCenter.x + dx / scale,
            y: zoomCenter.y + dy / scale
        )
    }
    
    func getZoomedSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }
    
    func getUnzoomedSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width / scale,
            height: size.height / scale
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 