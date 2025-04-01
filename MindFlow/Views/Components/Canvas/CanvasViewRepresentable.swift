//
//  CanvasViewRepresentable.swift
//  MindFlow
//
//  Created by Sharnabh on 01/04/25.
//

import Foundation
import SwiftUI

// NSViewRepresentable to get access to the underlying NSView for export
struct CanvasViewRepresentable: NSViewRepresentable {
   var onViewCreated: (CanvasViewRepresentable) -> Void
   var nsView: NSView?
   
   func makeNSView(context: Context) -> NSView {
       let view = NSView()
       view.wantsLayer = true
       
       // Create a mutable copy with the view set
       var mutableSelf = self
       mutableSelf.nsView = view
       
       // Call back with the reference to this representable
       DispatchQueue.main.async {
           onViewCreated(mutableSelf)
       }
       
       return view
   }
   
   func updateNSView(_ nsView: NSView, context: Context) {
       // Nothing to update
   }
}
