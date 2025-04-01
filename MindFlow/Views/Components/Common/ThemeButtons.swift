//
//  ThemeButtons.swift
//  MindFlow
//
//  Created by Sharnabh on 01/04/25.
//

import SwiftUI

// Add this after ColorPickerView struct near line 2220
// Theme button for the theme selector
struct ThemeButton: View {
   let name: String
   let primaryColor: Color
   let secondaryColor: Color
   let accentColor: Color
   var isDark: Bool = false
   let onSelect: () -> Void
   
   var body: some View {
       Button(action: onSelect) {
           VStack {
               ZStack {
                   // Background
                   RoundedRectangle(cornerRadius: 8)
                       .fill(secondaryColor)
                       .frame(height: 60)
                   
                   // Sample topic
                   RoundedRectangle(cornerRadius: 6)
                       .fill(isDark ? Color(red: 0.18, green: 0.18, blue: 0.2) : .white)
                       .frame(width: 50, height: 24)
                       .overlay(
                           RoundedRectangle(cornerRadius: 6)
                               .stroke(primaryColor, lineWidth: 2)
                       )
                       .shadow(color: accentColor.opacity(0.3), radius: 2, x: 0, y: 1)
               }
               
               Text(name)
                   .font(.system(size: 12))
                   .foregroundColor(isDark ? .white : .primary)
                   .padding(.top, 4)
           }
           .padding(4)
           .background(
               RoundedRectangle(cornerRadius: 10)
                   .stroke(Color.gray.opacity(0.2), lineWidth: 1)
           )
       }
       .buttonStyle(PlainButtonStyle())
   }
}
