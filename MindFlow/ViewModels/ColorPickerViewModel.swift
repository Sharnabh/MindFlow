import SwiftUI
import AppKit

class ColorPickerViewModel: ObservableObject {
    @Published var selectedColor: Color
    @Published var opacity: Double
    @Published var hexValue: String = ""
    
    let colors: [[Color]] = [
        [.white, .gray.opacity(0.2), .gray.opacity(0.4), .gray.opacity(0.6), .gray.opacity(0.8), .gray, .black],
        [Color(red: 1.0, green: 0.85, blue: 0), Color(red: 1.0, green: 0.63, blue: 0.48), Color(red: 0.6, green: 0.98, blue: 0.6), Color(red: 0.25, green: 0.88, blue: 0.82), Color(red: 0.53, green: 0.81, blue: 0.92), Color(red: 0.39, green: 0.58, blue: 0.93), Color(red: 0.87, green: 0.63, blue: 0.87), Color(red: 1.0, green: 0.41, blue: 0.71), Color(red: 1.0, green: 0.75, blue: 0.8)],
        [Color(red: 1.0, green: 0.72, blue: 0), Color(red: 1.0, green: 0.55, blue: 0.35), Color(red: 0.47, green: 0.98, blue: 0.47), Color(red: 0.13, green: 0.88, blue: 0.82), Color(red: 0.4, green: 0.81, blue: 0.92), Color(red: 0.27, green: 0.46, blue: 0.93), Color(red: 0.74, green: 0.5, blue: 0.87), Color(red: 1.0, green: 0.29, blue: 0.71), Color(red: 1.0, green: 0.63, blue: 0.67)],
        [Color(red: 1.0, green: 0.59, blue: 0), Color(red: 1.0, green: 0.42, blue: 0.23), Color(red: 0.35, green: 0.98, blue: 0.35), Color(red: 0, green: 0.88, blue: 0.82), Color(red: 0.28, green: 0.81, blue: 0.92), Color(red: 0.14, green: 0.34, blue: 0.93), Color(red: 0.62, green: 0.38, blue: 0.87), Color(red: 1.0, green: 0.16, blue: 0.71), Color(red: 1.0, green: 0.5, blue: 0.55)],
        [Color(red: 1.0, green: 0.47, blue: 0), Color(red: 1.0, green: 0.3, blue: 0.1), Color(red: 0.22, green: 0.98, blue: 0.22), Color(red: 0, green: 0.75, blue: 0.69), Color(red: 0.15, green: 0.81, blue: 0.92), Color(red: 0.02, green: 0.21, blue: 0.93), Color(red: 0.49, green: 0.25, blue: 0.87), Color(red: 1.0, green: 0.04, blue: 0.71), Color(red: 1.0, green: 0.38, blue: 0.42)]
    ]
    
    init(selectedColor: Color, opacity: Double) {
        self.selectedColor = selectedColor
        self.opacity = opacity
        self.hexValue = selectedColor.toHex() ?? ""
    }
    
    func selectColor(_ color: Color) {
        selectedColor = color
        hexValue = color.toHex() ?? ""
    }
    
    func updateFromHex(_ hex: String) {
        if let color = Color(hex: hex) {
            selectedColor = color
        }
    }
} 