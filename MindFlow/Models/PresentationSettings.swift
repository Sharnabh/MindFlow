import SwiftUI

enum BulletStyle: String, CaseIterable, Identifiable, Codable {
    case disc = "•"
    case dash = "-"
    case star = "*"
    case circle = "◦"
    case square = "▪︎"

    var id: String { self.rawValue }
}

struct PresentationSettings: Equatable, Codable {
    var backgroundColor: CodableColor = CodableColor(color: .black)
    var fontColor: CodableColor = CodableColor(color: .white)
    var fontName: String = "System"
    var fontSize: CGFloat = 28
    var headingFontSize: CGFloat = 44
    var bulletStyle: BulletStyle = .disc
    
    // Add a default initializer if needed, or rely on memberwise.
    // CodableColor is a wrapper to make Color Codable.

    static let defaultSettings = PresentationSettings(
        backgroundColor: CodableColor(color: .black),
        fontColor: CodableColor(color: .white),
        fontName: "System",
        fontSize: 28,
        headingFontSize: 44,
        bulletStyle: .disc
    )
}

// Helper struct to make Color Codable
struct CodableColor: Equatable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(color: Color) {
        let nsColor = NSColor(color) // Changed UIColor to NSColor
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var o: CGFloat = 0
        // Use getRed(_:green:blue:alpha:) for NSColor
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &o)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(o)
    }

    var color: Color {
        get {
            Color(red: red, green: green, blue: blue, opacity: opacity)
        }
        set {
            let nsColor = NSColor(newValue)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var o: CGFloat = 0
            nsColor.getRed(&r, green: &g, blue: &b, alpha: &o)
            self.red = Double(r)
            self.green = Double(g)
            self.blue = Double(b)
            self.opacity = Double(o)
        }
    }
}
