//
//  ColourPicker.swift
//  MindFlow
//
//  Created by Sharnabh on 08/04/25.
//

import SwiftUI

// Add this struct before the ShapeSelector
struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Binding var opacity: Double
    @State private var hexValue: String = ""
    @State private var showColorPicker = false
    
    let colors: [[Color]] = [
        [.white, .gray.opacity(0.2), .gray.opacity(0.4), .gray.opacity(0.6), .gray.opacity(0.8), .gray, .black],
        [Color(red: 1.0, green: 0.85, blue: 0), Color(red: 1.0, green: 0.63, blue: 0.48), Color(red: 0.6, green: 0.98, blue: 0.6), Color(red: 0.25, green: 0.88, blue: 0.82), Color(red: 0.53, green: 0.81, blue: 0.92), Color(red: 0.39, green: 0.58, blue: 0.93), Color(red: 0.87, green: 0.63, blue: 0.87), Color(red: 1.0, green: 0.41, blue: 0.71), Color(red: 1.0, green: 0.75, blue: 0.8)],
        [Color(red: 1.0, green: 0.72, blue: 0), Color(red: 1.0, green: 0.55, blue: 0.35), Color(red: 0.47, green: 0.98, blue: 0.47), Color(red: 0.13, green: 0.88, blue: 0.82), Color(red: 0.4, green: 0.81, blue: 0.92), Color(red: 0.27, green: 0.46, blue: 0.93), Color(red: 0.74, green: 0.5, blue: 0.87), Color(red: 1.0, green: 0.29, blue: 0.71), Color(red: 1.0, green: 0.63, blue: 0.67)],
        [Color(red: 1.0, green: 0.59, blue: 0), Color(red: 1.0, green: 0.42, blue: 0.23), Color(red: 0.35, green: 0.98, blue: 0.35), Color(red: 0, green: 0.88, blue: 0.82), Color(red: 0.28, green: 0.81, blue: 0.92), Color(red: 0.14, green: 0.34, blue: 0.93), Color(red: 0.62, green: 0.38, blue: 0.87), Color(red: 1.0, green: 0.16, blue: 0.71), Color(red: 1.0, green: 0.5, blue: 0.55)],
        [Color(red: 1.0, green: 0.47, blue: 0), Color(red: 1.0, green: 0.3, blue: 0.1), Color(red: 0.22, green: 0.98, blue: 0.22), Color(red: 0, green: 0.75, blue: 0.69), Color(red: 0.15, green: 0.81, blue: 0.92), Color(red: 0.02, green: 0.21, blue: 0.93), Color(red: 0.49, green: 0.25, blue: 0.87), Color(red: 1.0, green: 0.04, blue: 0.71), Color(red: 1.0, green: 0.38, blue: 0.42)]
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Color grid
            VStack(spacing: 4) {
                ForEach(colors, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                                hexValue = color.toHex() ?? ""
                            }) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(8)
            
            Divider()
            
            // Color wheel and hex input
            HStack {
                Text("#")
                    .foregroundColor(.secondary)
                TextField("", text: $hexValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 60)
                    .onChange(of: hexValue) { oldValue, newValue in
                        if let color = Color(hex: newValue) {
                            selectedColor = color
                        }
                    }
                
                Spacer()
                
                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 8)
            
            Divider()
            
            // Opacity slider
            HStack {
                Text("\(Int(opacity * 100))%")
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                
                Slider(value: $opacity, in: 0...1)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 180)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            hexValue = selectedColor.toHex() ?? ""
        }
    }
}
