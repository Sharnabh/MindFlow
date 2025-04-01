//
//  Colour.swift
//  MindFlow
//
//  Created by Sharnabh on 01/04/25.
//

import Foundation
import SwiftUI

// Add these extensions for color handling
extension Color {
   init?(hex: String) {
       var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
       hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
       
       var rgb: UInt64 = 0
       
       guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
       
       self.init(
           red: Double((rgb & 0xFF0000) >> 16) / 255.0,
           green: Double((rgb & 0x00FF00) >> 8) / 255.0,
           blue: Double(rgb & 0x0000FF) / 255.0
       )
   }
   
   func toHex() -> String? {
       let uic = NSColor(self)
       guard let components = uic.cgColor.components else { return nil }
       
       let r = Float(components[0])
       let g = Float(components[1])
       let b = Float(components[2])
       
       return String(format: "%02X%02X%02X",
           Int(r * 255),
           Int(g * 255),
           Int(b * 255)
       )
   }
}
