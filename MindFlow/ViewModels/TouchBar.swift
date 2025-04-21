//
//  TouchBar.swift
//  MindFlow
//
//  Created by Sharnabh on 08/04/25.
//

import Foundation
import SwiftUI

class InfiniteCanvasTouchBarDelegate: NSObject, NSTouchBarDelegate {
    static let collapseButtonIdentifier = NSTouchBarItem.Identifier("com.mindflow.touchbar.collapse")
    static let relationshipButtonIdentifier = NSTouchBarItem.Identifier("com.mindflow.touchbar.relationship")
    static let autoLayoutButtonIdentifier = NSTouchBarItem.Identifier("com.mindflow.touchbar.autolayout")
    static let touchBarIdentifier = NSTouchBar.CustomizationIdentifier("com.mindflow.touchbar.main")
    
    var viewModel: CanvasViewModel
    var isRelationshipMode: Binding<Bool>
    private var touchBar: NSTouchBar?
    
    init(viewModel: CanvasViewModel, isRelationshipMode: Binding<Bool>) {
        self.viewModel = viewModel
        self.isRelationshipMode = isRelationshipMode
        super.init()
        configureTouchBar()
    }
    
    func configureTouchBar() {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = InfiniteCanvasTouchBarDelegate.touchBarIdentifier
        touchBar.defaultItemIdentifiers = [
            .fixedSpaceSmall,
            InfiniteCanvasTouchBarDelegate.collapseButtonIdentifier,
            .fixedSpaceSmall,
            InfiniteCanvasTouchBarDelegate.autoLayoutButtonIdentifier,
            .fixedSpaceSmall,
            InfiniteCanvasTouchBarDelegate.relationshipButtonIdentifier,
            .fixedSpaceSmall
        ]
        
        self.touchBar = touchBar
        
        // Set as the current touch bar
        if let window = NSApplication.shared.mainWindow {
            window.touchBar = touchBar
        }
    }
    
    func updateTouchBar() {
        // Force the touch bar to update by recreating it
        configureTouchBar()
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case InfiniteCanvasTouchBarDelegate.collapseButtonIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            
            // Create button with only image initially
            let button = NSButton(title: "", image: NSImage(systemSymbolName: "2.circle", accessibilityDescription: "Collapse/Expand") ?? NSImage(), target: self, action: #selector(toggleCollapse))
            
            // Set button style to separate text from image
            button.bezelStyle = .rounded
            button.imagePosition = .imageLeading
            
            // Update button appearance based on selection state
            if let selectedId = viewModel.selectedTopicId,
               let topic = viewModel.getTopicById(selectedId) {
                let isCollapsed = viewModel.isTopicCollapsed(id: selectedId)
                let totalDescendants = viewModel.countAllDescendants(for: topic)
                
                if totalDescendants > 0 {
                    button.image = NSImage(systemSymbolName: "\(totalDescendants).circle", accessibilityDescription: "Collapse/Expand") ?? NSImage()
                    button.title = isCollapsed ? " Expand" : " Collapse" // Add space before text
                    button.isEnabled = true
                } else {
                    button.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Collapse/Expand") ?? NSImage()
                    button.title = " Collapse" // Add space before text
                    button.isEnabled = false
                }
            } else {
                button.isEnabled = false
            }
            
            item.view = button
            return item
            
        case InfiniteCanvasTouchBarDelegate.autoLayoutButtonIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: " Auto Layout", image: NSImage(systemSymbolName: "rectangle.grid.1x2", accessibilityDescription: "Auto Layout") ?? NSImage(), target: self, action: #selector(performAutoLayout))
            
            // Set button style to separate text from image
            button.bezelStyle = .rounded
            button.imagePosition = .imageLeading
            
            item.view = button
            return item
            
        case InfiniteCanvasTouchBarDelegate.relationshipButtonIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: " Relationship", image: NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Create Relationships") ?? NSImage(), target: self, action: #selector(toggleRelationshipMode))
            
            // Set button style to separate text from image
            button.bezelStyle = .rounded
            button.imagePosition = .imageLeading
            
            // Update button appearance based on mode state
            if isRelationshipMode.wrappedValue {
                button.bezelColor = NSColor.blue.withAlphaComponent(0.2)
            }
            
            item.view = button
            return item
            
        default:
            return nil
        }
    }
    
    @objc func toggleCollapse() {
        if let selectedId = viewModel.selectedTopicId {
            viewModel.toggleCollapseState(topicId: selectedId)
            updateTouchBar() // Update button state after toggle
        }
    }
    
    @objc func performAutoLayout() {
        viewModel.performAutoLayout()
    }
    
    @objc func toggleRelationshipMode() {
        isRelationshipMode.wrappedValue.toggle()
        updateTouchBar() // Update button state after toggle
    }
}
