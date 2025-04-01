//
//  Shapes.swift
//  MindFlow
//
//  Created by Sharnabh on 01/04/25.
//

import Foundation
import SwiftUI

// Custom shape views
 struct Diamond: Shape {
   func path(in rect: CGRect) -> Path {
       var path = Path()
       path.move(to: CGPoint(x: rect.midX, y: rect.minY))
       path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
       path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
       path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
       path.closeSubpath()
       return path
   }
}

 struct RegularPolygon: Shape {
   let sides: Int
   
   func path(in rect: CGRect) -> Path {
       let center = CGPoint(x: rect.midX, y: rect.midY)
       let radius = min(rect.width, rect.height) / 2
       var path = Path()
       
       for i in 0..<sides {
           let angle = (2.0 * .pi * Double(i)) / Double(sides) - (.pi / 2)
           let point = CGPoint(
               x: center.x + radius * cos(angle),
               y: center.y + radius * sin(angle)
           )
           
           if i == 0 {
               path.move(to: point)
           } else {
               path.addLine(to: point)
           }
       }
       path.closeSubpath()
       return path
   }
}

 struct Parallelogram: Shape {
   func path(in rect: CGRect) -> Path {
       var path = Path()
       let offset: CGFloat = rect.width * 0.2
       path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
       path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
       path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.maxY))
       path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
       path.closeSubpath()
       return path
   }
}

 struct Cloud: Shape {
   func path(in rect: CGRect) -> Path {
       var path = Path()
       let width = rect.width
       let height = rect.height
       let centerY = height * 0.5
       
       path.move(to: CGPoint(x: width * 0.2, y: centerY))
       path.addCurve(
           to: CGPoint(x: width * 0.8, y: centerY),
           control1: CGPoint(x: width * 0.2, y: height * 0.2),
           control2: CGPoint(x: width * 0.8, y: height * 0.2)
       )
       path.addCurve(
           to: CGPoint(x: width * 0.2, y: centerY),
           control1: CGPoint(x: width * 0.8, y: height * 0.8),
           control2: CGPoint(x: width * 0.2, y: height * 0.8)
       )
       path.closeSubpath()
       return path
   }
}

 struct Heart: Shape {
   func path(in rect: CGRect) -> Path {
       var path = Path()
       let width = rect.width
       let height = rect.height
       
       path.move(to: CGPoint(x: width * 0.5, y: height * 0.75))
       path.addCurve(
           to: CGPoint(x: width * 0.1, y: height * 0.35),
           control1: CGPoint(x: width * 0.5, y: height * 0.7),
           control2: CGPoint(x: width * 0.1, y: height * 0.5)
       )
       path.addCurve(
           to: CGPoint(x: width * 0.5, y: height * 0.25),
           control1: CGPoint(x: width * 0.1, y: height * 0.2),
           control2: CGPoint(x: width * 0.5, y: height * 0.25)
       )
       path.addCurve(
           to: CGPoint(x: width * 0.9, y: height * 0.35),
           control1: CGPoint(x: width * 0.5, y: height * 0.25),
           control2: CGPoint(x: width * 0.9, y: height * 0.2)
       )
       path.addCurve(
           to: CGPoint(x: width * 0.5, y: height * 0.75),
           control1: CGPoint(x: width * 0.9, y: height * 0.5),
           control2: CGPoint(x: width * 0.5, y: height * 0.7)
       )
       path.closeSubpath()
       return path
   }
}

 struct Shield: Shape {
   func path(in rect: CGRect) -> Path {
       var path = Path()
       let width = rect.width
       let height = rect.height
       
       path.move(to: CGPoint(x: width * 0.5, y: height))
       path.addCurve(
           to: CGPoint(x: 0, y: height * 0.4),
           control1: CGPoint(x: width * 0.2, y: height * 0.9),
           control2: CGPoint(x: 0, y: height * 0.7)
       )
       path.addLine(to: CGPoint(x: 0, y: 0))
       path.addLine(to: CGPoint(x: width, y: 0))
       path.addLine(to: CGPoint(x: width, y: height * 0.4))
       path.addCurve(
           to: CGPoint(x: width * 0.5, y: height),
           control1: CGPoint(x: width, y: height * 0.7),
           control2: CGPoint(x: width * 0.8, y: height * 0.9)
       )
       path.closeSubpath()
       return path
   }
}

 struct Star: Shape {
   func path(in rect: CGRect) -> Path {
       let center = CGPoint(x: rect.midX, y: rect.midY)
       let radius = min(rect.width, rect.height) / 2
       let innerRadius = radius * 0.4
       let points = 5
       var path = Path()
       
       for i in 0..<points * 2 {
           let angle = (2.0 * .pi * Double(i)) / Double(points * 2) - (.pi / 2)
           let r = i % 2 == 0 ? radius : innerRadius
           let point = CGPoint(
               x: center.x + r * cos(angle),
               y: center.y + r * sin(angle)
           )
           
           if i == 0 {
               path.move(to: point)
           } else {
               path.addLine(to: point)
           }
       }
       path.closeSubpath()
       return path
   }
}

 struct Document: Shape {
   func path(in rect: CGRect) -> Path {
       var path = Path()
       let width = rect.width
       let height = rect.height
       let cornerRadius: CGFloat = 8
       let foldSize: CGFloat = min(width, height) * 0.2
       
       path.move(to: CGPoint(x: 0, y: height))
       path.addLine(to: CGPoint(x: 0, y: cornerRadius))
       path.addArc(
           center: CGPoint(x: cornerRadius, y: cornerRadius),
           radius: cornerRadius,
           startAngle: .degrees(180),
           endAngle: .degrees(270),
           clockwise: false
       )
       path.addLine(to: CGPoint(x: width - foldSize, y: 0))
       path.addLine(to: CGPoint(x: width, y: foldSize))
       path.addLine(to: CGPoint(x: width, y: height))
       path.closeSubpath()
       
       // Add fold line
       path.move(to: CGPoint(x: width - foldSize, y: 0))
       path.addLine(to: CGPoint(x: width - foldSize, y: foldSize))
       path.addLine(to: CGPoint(x: width, y: foldSize))
       
       return path
   }
}

 struct DoubleRectangle: Shape {
   func path(in rect: CGRect) -> Path {
       var path = Path()
       let offset: CGFloat = 4
       
       // Back rectangle
       path.addRect(CGRect(
           x: offset,
           y: offset,
           width: rect.width - offset,
           height: rect.height - offset
       ))
       
       // Front rectangle
       path.addRect(CGRect(
           x: 0,
           y: 0,
           width: rect.width - offset,
           height: rect.height - offset
       ))
       
       return path
   }
}

 struct Flag: Shape {
   func path(in rect: CGRect) -> Path {
       var path = Path()
       let width = rect.width
       let height = rect.height
       let poleWidth: CGFloat = width * 0.1
       
       // Pole
       path.addRect(CGRect(
           x: 0,
           y: 0,
           width: poleWidth,
           height: height
       ))
       
       // Flag part
       path.move(to: CGPoint(x: poleWidth, y: height * 0.2))
       path.addLine(to: CGPoint(x: width, y: height * 0.2))
       path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.5))
       path.addLine(to: CGPoint(x: width, y: height * 0.8))
       path.addLine(to: CGPoint(x: poleWidth, y: height * 0.8))
       path.closeSubpath()
       
       return path
   }
}

 struct Arrow: Shape {
   enum Direction {
       case left
       case right
   }
   
   let pointing: Direction
   
   func path(in rect: CGRect) -> Path {
       var path = Path()
       let width = rect.width
       let height = rect.height
       let arrowWidth = width * 0.3
       
       switch pointing {
       case .left:
           path.move(to: CGPoint(x: 0, y: height * 0.5))
           path.addLine(to: CGPoint(x: arrowWidth, y: 0))
           path.addLine(to: CGPoint(x: arrowWidth, y: height * 0.3))
           path.addLine(to: CGPoint(x: width, y: height * 0.3))
           path.addLine(to: CGPoint(x: width, y: height * 0.7))
           path.addLine(to: CGPoint(x: arrowWidth, y: height * 0.7))
           path.addLine(to: CGPoint(x: arrowWidth, y: height))
           path.closeSubpath()
       case .right:
           path.move(to: CGPoint(x: width, y: height * 0.5))
           path.addLine(to: CGPoint(x: width - arrowWidth, y: 0))
           path.addLine(to: CGPoint(x: width - arrowWidth, y: height * 0.3))
           path.addLine(to: CGPoint(x: 0, y: height * 0.3))
           path.addLine(to: CGPoint(x: 0, y: height * 0.7))
           path.addLine(to: CGPoint(x: width - arrowWidth, y: height * 0.7))
           path.addLine(to: CGPoint(x: width - arrowWidth, y: height))
           path.closeSubpath()
       }
       
       return path
   }
}
