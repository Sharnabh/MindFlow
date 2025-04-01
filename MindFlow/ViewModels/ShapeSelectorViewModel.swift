import SwiftUI
import AppKit

class ShapeSelectorViewModel: ObservableObject {
    @Published var selectedShape: Topic.Shape
    @Published var isShowingPopover = false
    
    let shapes: [(Topic.Shape, String)] = [
        (.rectangle, "Rectangle"),
        (.roundedRectangle, "Rounded Rectangle"),
        (.circle, "Circle"),
        (.roundedSquare, "Rounded Square"),
        (.line, "Line"),
        (.diamond, "Diamond"),
        (.hexagon, "Hexagon"),
        (.octagon, "Octagon"),
        (.parallelogram, "Parallelogram"),
        (.cloud, "Cloud"),
        (.heart, "Heart"),
        (.shield, "Shield"),
        (.star, "Star"),
        (.document, "Document"),
        (.doubleRectangle, "Double Rectangle"),
        (.flag, "Flag"),
        (.leftArrow, "Left Arrow"),
        (.rightArrow, "Right Arrow")
    ]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    init(selectedShape: Topic.Shape) {
        self.selectedShape = selectedShape
    }
    
    init() {
        self.selectedShape = .rectangle // Set a default shape
    }
    
    func selectShape(_ shape: Topic.Shape) {
        selectedShape = shape
        isShowingPopover = false
    }
} 