//
//  MiniMapView.swift
//  MindFlow
//
//  Created by Sharnabh on 01/04/25.
//

import SwiftUI

// Minimap view that shows a scaled-down version of all topics
struct MinimapView: View {
   let topics: [Topic]
   let visibleRect: CGRect
   let topicsBounds: CGRect
   let size: CGSize
   let onTapLocation: (CGPoint) -> Void
   
   // Helper function to check if any topic has curved style
   private func hasCurvedStyle(_ topics: [Topic]) -> Bool {
       for topic in topics {
           if topic.branchStyle == .curved {
               return true
           }
           if hasCurvedStyle(topic.subtopics) {
               return true
           }
       }
       return false
   }
   
   var body: some View {
       Canvas { context, size in
           // Check if any topic has curved style
           let shouldUseCurvedStyle = hasCurvedStyle(topics)
           
           // Draw topics as dots
           for topic in topics {
               func drawTopic(_ topic: Topic, color: Color) {
                   let position = scaleToMinimap(topic.position)
                   let dotSize: CGFloat = 6
                   
                   context.fill(
                       Path(ellipseIn: CGRect(
                           x: position.x - dotSize/2,
                           y: position.y - dotSize/2,
                           width: dotSize,
                           height: dotSize
                       )),
                       with: .color(color)
                   )
                   
                   // Draw lines to subtopics
                   for subtopic in topic.subtopics {
                       let startPoint = position
                       let endPoint = scaleToMinimap(subtopic.position)
                       
                       // Use curved style if any topic has curved style
                       if shouldUseCurvedStyle {
                           // Draw curved path
                           let dx = endPoint.x - startPoint.x
                           _ = endPoint.y - startPoint.y
                           let midX = startPoint.x + dx * 0.5
                           
                           let control1 = CGPoint(x: midX, y: startPoint.y)
                           let control2 = CGPoint(x: midX, y: endPoint.y)
                           
                           context.stroke(
                               Path { path in
                                   path.move(to: startPoint)
                                   path.addCurve(to: endPoint,
                                               control1: control1,
                                               control2: control2)
                               },
                               with: .color(topic.borderColor.opacity(1.0)),
                               lineWidth: 1
                           )
                       } else {
                           // Draw straight line
                           context.stroke(
                               Path { path in
                                   path.move(to: startPoint)
                                   path.addLine(to: endPoint)
                               },
                               with: .color(topic.borderColor.opacity(1.0)),
                               lineWidth: 1
                           )
                       }
                       
                       // Recursively draw subtopics
                       drawTopic(subtopic, color: topic.borderColor.opacity(1.0))
                   }
               }
               
               // Draw main topic
               drawTopic(topic, color: topic.borderColor)
           }
           
           // Draw visible area rectangle
           if !topicsBounds.isEmpty {
               let visibleRectInMinimap = CGRect(
                   x: (visibleRect.minX - topicsBounds.minX) * (size.width / topicsBounds.width),
                   y: (visibleRect.minY - topicsBounds.minY) * (size.height / topicsBounds.height),
                   width: visibleRect.width * (size.width / topicsBounds.width),
                   height: visibleRect.height * (size.height / topicsBounds.height)
               )
               
               context.stroke(
                   Path(visibleRectInMinimap),
                   with: .color(.blue.opacity(0.5)),
                   lineWidth: 1
               )
           }
       }
       .simultaneousGesture(
           TapGesture()
               .onEnded { _ in
                   // Handle tap at the current cursor position
                   if let window = NSApp.keyWindow,
                      let contentView = window.contentView {
                       let mouseLocation = NSEvent.mouseLocation
                       let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                       let viewPoint = contentView.convert(windowPoint, from: nil)
                       
                       // Convert the point to be relative to the minimap
                       if let minimapFrame = (contentView as? NSHostingView<MinimapView>)?.frame {
                           let relativePoint = CGPoint(
                               x: viewPoint.x - minimapFrame.minX,
                               y: viewPoint.y - minimapFrame.minY
                           )
                           onTapLocation(relativePoint)
                       }
                   }
               }
       )
       .simultaneousGesture(
           DragGesture(minimumDistance: 0)
               .onChanged { value in
                   onTapLocation(value.location)
               }
       )
       .contentShape(Rectangle()) // Make entire minimap tappable
   }
   
   private func scaleToMinimap(_ point: CGPoint) -> CGPoint {
       guard !topicsBounds.isEmpty else { return .zero }
       
       let scaleX = size.width / topicsBounds.width
       let scaleY = size.height / topicsBounds.height
       let scale = min(scaleX, scaleY)
       
       return CGPoint(
           x: (point.x - topicsBounds.minX) * scale,
           y: (point.y - topicsBounds.minY) * scale
       )
   }
}
