//
//  ShapePreview.swift
//  MindFlow
//
//  Created by Sharnabh on 08/04/25.
//

import SwiftUI

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
