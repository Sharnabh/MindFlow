import SwiftUI
import AppKit

class TouchBarViewModel: NSObject, ObservableObject {
    static let collapseButtonIdentifier = NSTouchBarItem.Identifier("com.mindflow.touchbar.collapse")
    static let relationshipButtonIdentifier = NSTouchBarItem.Identifier("com.mindflow.touchbar.relationship")
    static let autoLayoutButtonIdentifier = NSTouchBarItem.Identifier("com.mindflow.touchbar.autolayout")
    static let touchBarIdentifier = NSTouchBar.CustomizationIdentifier("com.mindflow.touchbar.main")
    
    private var viewModel: CanvasViewModel
    private var isRelationshipMode: Binding<Bool>
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
        touchBar.customizationIdentifier = TouchBarViewModel.touchBarIdentifier
        touchBar.defaultItemIdentifiers = [
            .fixedSpaceSmall,
            TouchBarViewModel.collapseButtonIdentifier,
            .fixedSpaceSmall,
            TouchBarViewModel.autoLayoutButtonIdentifier,
            .fixedSpaceSmall,
            TouchBarViewModel.relationshipButtonIdentifier,
            .fixedSpaceSmall
        ]
        
        self.touchBar = touchBar
        
        if let window = NSApplication.shared.mainWindow {
            window.touchBar = touchBar
        }
    }
    
    func updateTouchBar() {
        configureTouchBar()
    }
}

extension TouchBarViewModel: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case TouchBarViewModel.collapseButtonIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            
            let button = NSButton(title: "", image: NSImage(systemSymbolName: "2.circle", accessibilityDescription: "Collapse/Expand") ?? NSImage(), target: self, action: #selector(toggleCollapse))
            
            button.bezelStyle = .rounded
            button.imagePosition = .imageLeading
            
            if let selectedId = viewModel.selectedTopicId,
               let topic = viewModel.getTopicById(selectedId) {
                let isCollapsed = viewModel.isTopicCollapsed(id: selectedId)
                let totalDescendants = viewModel.countAllDescendants(for: topic)
                
                if totalDescendants > 0 {
                    button.image = NSImage(systemSymbolName: "\(totalDescendants).circle", accessibilityDescription: "Collapse/Expand") ?? NSImage()
                    button.title = isCollapsed ? " Expand" : " Collapse"
                    button.isEnabled = true
                } else {
                    button.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Collapse/Expand") ?? NSImage()
                    button.title = " Collapse"
                    button.isEnabled = false
                }
            } else {
                button.isEnabled = false
            }
            
            item.view = button
            return item
            
        case TouchBarViewModel.autoLayoutButtonIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: " Auto Layout", image: NSImage(systemSymbolName: "rectangle.grid.1x2", accessibilityDescription: "Auto Layout") ?? NSImage(), target: self, action: #selector(performAutoLayout))
            
            button.bezelStyle = .rounded
            button.imagePosition = .imageLeading
            
            item.view = button
            return item
            
        case TouchBarViewModel.relationshipButtonIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: " Relationship", image: NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Create Relationships") ?? NSImage(), target: self, action: #selector(toggleRelationshipMode))
            
            button.bezelStyle = .rounded
            button.imagePosition = .imageLeading
            
            if isRelationshipMode.wrappedValue {
                button.bezelColor = NSColor.blue.withAlphaComponent(0.2)
            }
            
            item.view = button
            return item
            
        default:
            return nil
        }
    }
    
    @objc private func toggleCollapse() {
        if let selectedId = viewModel.selectedTopicId {
            viewModel.toggleCollapseState(topicId: selectedId)
            updateTouchBar()
        }
    }
    
    @objc private func performAutoLayout() {
        viewModel.performAutoLayout()
    }
    
    @objc private func toggleRelationshipMode() {
        isRelationshipMode.wrappedValue.toggle()
        updateTouchBar()
    }
} 