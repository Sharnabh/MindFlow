import SwiftUI
import AppKit

class TopicBranchViewModel: ObservableObject {
    @Published var isCollapsed: Bool = false
    @Published var isHovered: Bool = false
    @Published var isSelected: Bool = false
    
    @Published var branchError: String?
    private var branchStyle: BranchStyle = .straight
    
    let topic: Topic
    let onSelect: (Topic) -> Void
    let onCollapse: (Topic) -> Void
    let onDelete: (Topic) -> Void
    
    init(topic: Topic, onSelect: @escaping (Topic) -> Void, onCollapse: @escaping (Topic) -> Void, onDelete: @escaping (Topic) -> Void) {
        self.topic = topic
        self.isCollapsed = topic.isCollapsed
        self.onSelect = onSelect
        self.onCollapse = onCollapse
        self.onDelete = onDelete
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBranchStyleChange),
            name: NSNotification.Name("BranchStyleChange"),
            object: nil
        )
    }
    
    @objc private func handleBranchStyleChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let style = userInfo["style"] as? BranchStyle else { return }
        
        updateBranchStyle(to: style)
    }
    
    func updateBranchStyle(to style: BranchStyle) {
        branchStyle = style
        branchError = nil
        
        NotificationCenter.default.post(
            name: NSNotification.Name("BranchStyleChanged"),
            object: nil,
            userInfo: ["style": style]
        )
    }
    
    func handleTap() {
        onSelect(topic)
    }
    
    func handleCollapse() {
        isCollapsed.toggle()
        onCollapse(topic)
    }
    
    func handleDelete() {
        onDelete(topic)
    }
    
    func calculateBranchPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        
        switch branchStyle {
        case .straight:
            path.addLine(to: end)
        case .curved:
            let control1 = CGPoint(x: start.x + (end.x - start.x) * 0.5, y: start.y)
            let control2 = CGPoint(x: start.x + (end.x - start.x) * 0.5, y: end.y)
            path.addCurve(to: end, control1: control1, control2: control2)
        case .default:
            path.addLine(to: end)
        }
        
        return path
    }
    
    func getBranchPath(from start: CGPoint, to end: CGPoint, style: BranchStyle) -> Path {
        var path = Path()
        
        switch style {
        case .straight:
            path.move(to: start)
            path.addLine(to: end)
            
        case .curved:
            let dx = end.x - start.x
            let dy = end.y - start.y
            let distance = sqrt(dx * dx + dy * dy)
            
            let controlPoint1 = CGPoint(
                x: start.x + dx * 0.25,
                y: start.y + dy * 0.25
            )
            let controlPoint2 = CGPoint(
                x: start.x + dx * 0.75,
                y: start.y + dy * 0.75
            )
            
            path.move(to: start)
            path.addCurve(to: end, control1: controlPoint1, control2: controlPoint2)
            
        case .default:
            path.move(to: start)
            path.addLine(to: end)
        }
        
        return path
    }
    
    func getCollapseButtonPosition(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return CGPoint(
            x: start.x + dx * 0.5,
            y: start.y + dy * 0.5
        )
    }
    
    func getCollapseButtonRotation(from start: CGPoint, to end: CGPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return atan2(dy, dx)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 