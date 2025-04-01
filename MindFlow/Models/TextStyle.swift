//
//  TextStyle.swift
//  MindFlow
//
//  Created by Sharnabh on 01/04/25.
//

import Foundation
import SwiftUI

// Add these enums before the ColorPickerView struct
enum TextStyle: CaseIterable {
   case bold
   case italic
   case strikethrough
   case underline
   
   var iconName: String {
       switch self {
       case .bold: return "bold"
       case .italic: return "italic"
       case .strikethrough: return "strikethrough"
       case .underline: return "underline"
       }
   }
}

enum TextCase: CaseIterable {
   case none
   case uppercase
   case lowercase
   case capitalize
   
   var displayName: String {
       switch self {
       case .none: return "Default"
       case .uppercase: return "UPPERCASE"
       case .lowercase: return "lowercase"
       case .capitalize: return "Capitalize"
       }
   }
}

enum TextAlignment: CaseIterable {
   case left
   case center
   case right
   
   var iconName: String {
       switch self {
       case .left: return "text.alignleft"
       case .center: return "text.aligncenter"
       case .right: return "text.alignright"
       }
   }
}

extension Font.Weight: @retroactive CaseIterable {
   public static var allCases: [Font.Weight] = [
       .thin,
       .ultraLight,
       .light,
       .regular,
       .medium,
       .semibold,
       .bold,
       .heavy
   ]
   
   var displayName: String {
       switch self {
       case .thin: return "Thin"
       case .ultraLight: return "Extra Light"
       case .light: return "Light"
       case .regular: return "Regular"
       case .medium: return "Medium"
       case .semibold: return "Semibold"
       case .bold: return "Bold"
       case .heavy: return "Extra Bold"
       default: return "Regular"
       }
   }
}
