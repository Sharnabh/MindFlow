//
//  ShapeSelector.swift
//  MindFlow
//
//  Created by Sharnabh on 01/04/25.
//

import SwiftUI

// Shape selector view
struct ShapeSelector: View {
   let selectedShape: Topic.Shape
   let onShapeSelected: (Topic.Shape) -> Void
   @State private var isShowingPopover = false
   
   private let shapes: [(Topic.Shape, String)] = [
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
   
   private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
   
   var body: some View {
       HStack(spacing: 8) {
           Text("Shape")
               .foregroundColor(.primary)
               .font(.system(size: 13))
           
           Spacer()
           
           Button(action: {
               isShowingPopover.toggle()
           }) {
               HStack(spacing: 4) {
                   ShapePreview(shape: selectedShape)
                       .frame(width: 16, height: 16)
                       .foregroundColor(.white)
                   
                   Image(systemName: "chevron.down")
                       .font(.system(size: 10))
                       .foregroundColor(.white.opacity(0.8))
               }
               .padding(.horizontal, 8)
               .padding(.vertical, 6)
               .frame(width: 50)
               .background(Color.black.opacity(0.6))
               .cornerRadius(6)
           }
           .buttonStyle(PlainButtonStyle())
           .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
               VStack {
                   LazyVGrid(columns: columns, spacing: 8) {
                       ForEach(shapes, id: \.0) { shape, name in
                           Button(action: {
                               onShapeSelected(shape)
                               isShowingPopover = false
                           }) {
                               ShapePreview(shape: shape)
                                   .frame(width: 32, height: 32)
                                   .background(shape == selectedShape ? Color.blue.opacity(0.2) : Color.clear)
                                   .cornerRadius(4)
                           }
                           .buttonStyle(PlainButtonStyle())
                           .help(name)
                       }
                   }
                   .padding(8)
               }
               .frame(width: 180)
               .background(Color(.windowBackgroundColor))
           }
       }
       .padding(.horizontal)
   }
}

// Shape preview for the menu
struct ShapePreview: View {
   let shape: Topic.Shape
   
   var body: some View {
       Group {
           switch shape {
           case .rectangle:
               RoundedRectangle(cornerRadius: 2)
           case .roundedRectangle:
               RoundedRectangle(cornerRadius: 4)
           case .circle:
               Circle()
           case .roundedSquare:
               RoundedRectangle(cornerRadius: 6)
           case .line:
               Rectangle().frame(height: 2)
           case .diamond:
               Diamond()
           case .hexagon:
               RegularPolygon(sides: 6)
           case .octagon:
               RegularPolygon(sides: 8)
           case .parallelogram:
               Parallelogram()
           case .cloud:
               Cloud()
           case .heart:
               Heart()
           case .shield:
               Shield()
           case .star:
               Star()
           case .document:
               Document()
           case .doubleRectangle:
               DoubleRectangle()
           case .flag:
               Flag()
           case .leftArrow:
               Arrow(pointing: .left)
           case .rightArrow:
               Arrow(pointing: .right)
           }
       }
   }
}
