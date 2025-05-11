import AppKit
import SwiftUI

// Helper class to handle true full-screen presentation mode like Keynote
class PresentationHelper {
    static let shared = PresentationHelper()
    
    private var presentationWindow: NSWindow?
    private var originalOptions: NSApplication.PresentationOptions?
    // Strong reference to presentation content to prevent deallocation while in use
    private var presentationContent: NSHostingView<PresentationContentView>?
    
    // Enters full presentation mode (like Keynote)
    func enterPresentationMode() {
        // Close any existing window first to prevent window leaks
        exitPresentationMode()
        
        // Save original options
        originalOptions = NSApp.presentationOptions
        
        // Create a new borderless window that covers the screen
        if let screen = NSScreen.main {
            let window = CustomPresentationWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            
            // Configure window properties
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            
            // Set to highest level to be above everything else
            window.level = .statusBar
            
            // Make the window fullscreen - this prevents the dimming effect
            window.collectionBehavior = [.fullScreenPrimary]
            
            // Create content view with strong reference to prevent deallocation
            let contentView = PresentationContentView()
            let hostingView = NSHostingView(rootView: contentView)
            window.contentView = hostingView
            
            // Store strong references to both window and content
            presentationWindow = window
            presentationContent = hostingView
            
            // Show the window
            window.makeKeyAndOrderFront(nil)
            
            // Apply presentation options
            let options: NSApplication.PresentationOptions = [
                .fullScreen, 
                .autoHideDock, 
                .autoHideMenuBar,
                .disableAppleMenu,
                .disableProcessSwitching
            ]
            NSApp.presentationOptions = options
            
            // Hide cursor after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                NSCursor.setHiddenUntilMouseMoves(true)
            }
        }
    }
    
    // Exits presentation mode
    func exitPresentationMode() {
        // Close the presentation window
        if let window = presentationWindow {
            window.close()
        }
        
        // Clear references in the correct order
        presentationContent = nil
        presentationWindow = nil
        
        // Restore original presentation options
        if let options = originalOptions {
            NSApp.presentationOptions = options
            originalOptions = nil
        }
        
        // Show cursor
        NSCursor.setHiddenUntilMouseMoves(false)
    }
}

// Custom NSWindow subclass that can become key window
class CustomPresentationWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // Prevent window from being released while still visible
    override func close() {
        // Only proceed with close if window exists and is loaded
        if isReleasedWhenClosed {
            isReleasedWhenClosed = false
        }
        super.close()
    }
}

// A separate SwiftUI view that hosts the presentation content
struct PresentationContentView: View {
    // Use StateObject instead of ObservedObject to ensure the manager stays alive
    @StateObject private var presentationManager = PresentationManager.shared
    
    var body: some View {
        if presentationManager.slides.isEmpty {
            // Fallback view if no slides available
            VStack {
                Text("No slides to display")
                    .font(.title)
                    .foregroundColor(.white)
                
                Button("Close") {
                    presentationManager.endPresentation()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        } else {
            // Regular presentation view
            PresentationView()
                .environmentObject(presentationManager) // Explicitly pass as environment object
                .edgesIgnoringSafeArea(.all)
        }
    }
}