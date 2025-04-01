import SwiftUI
import AppKit

class TopicGridViewModel: ObservableObject {
    @Published var isGridVisible: Bool = true
    @Published var gridSize: CGFloat = 50
    @Published var gridColor: Color = .gray.opacity(0.2)
    @Published var gridError: String?
    
    private let minGridSize: CGFloat = 10
    private let maxGridSize: CGFloat = 200
    private let gridStep: CGFloat = 10
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGridToggle),
            name: NSNotification.Name("GridToggle"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGridSizeChange),
            name: NSNotification.Name("GridSizeChange"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGridColorChange),
            name: NSNotification.Name("GridColorChange"),
            object: nil
        )
    }
    
    @objc private func handleGridToggle() {
        toggleGrid()
    }
    
    @objc private func handleGridSizeChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let size = userInfo["size"] as? CGFloat else { return }
        
        updateGridSize(to: size)
    }
    
    @objc private func handleGridColorChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let color = userInfo["color"] as? Color else { return }
        
        updateGridColor(to: color)
    }
    
    func toggleGrid() {
        isGridVisible.toggle()
        gridError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("GridChanged"),
            object: nil,
            userInfo: ["isVisible": isGridVisible]
        )
    }
    
    func increaseGridSize() {
        let newSize = min(gridSize + gridStep, maxGridSize)
        updateGridSize(to: newSize)
    }
    
    func decreaseGridSize() {
        let newSize = max(gridSize - gridStep, minGridSize)
        updateGridSize(to: newSize)
    }
    
    func updateGridSize(to size: CGFloat) {
        gridSize = size
        gridError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("GridChanged"),
            object: nil,
            userInfo: ["size": size]
        )
    }
    
    func updateGridColor(to color: Color) {
        gridColor = color
        gridError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("GridChanged"),
            object: nil,
            userInfo: ["color": color]
        )
    }
    
    func snapPoint(_ point: CGPoint) -> CGPoint {
        let x = round(point.x / gridSize) * gridSize
        let y = round(point.y / gridSize) * gridSize
        return CGPoint(x: x, y: y)
    }
    
    func getGridLines(in rect: CGRect) -> [Path] {
        var lines: [Path] = []
        
        let startX = floor(rect.minX / gridSize) * gridSize
        let endX = ceil(rect.maxX / gridSize) * gridSize
        let startY = floor(rect.minY / gridSize) * gridSize
        let endY = ceil(rect.maxY / gridSize) * gridSize
        
        // Vertical lines
        for x in stride(from: startX, through: endX, by: gridSize) {
            var path = Path()
            path.move(to: CGPoint(x: x, y: startY))
            path.addLine(to: CGPoint(x: x, y: endY))
            lines.append(path)
        }
        
        // Horizontal lines
        for y in stride(from: startY, through: endY, by: gridSize) {
            var path = Path()
            path.move(to: CGPoint(x: startX, y: y))
            path.addLine(to: CGPoint(x: endX, y: y))
            lines.append(path)
        }
        
        return lines
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct GridLine {
    let start: CGPoint
    let end: CGPoint
} 