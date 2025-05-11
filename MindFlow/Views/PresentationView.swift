import SwiftUI
import AppKit

struct PresentationView: View {
    // Use EnvironmentObject to ensure proper lifecycle management
    @EnvironmentObject var presentationManager: PresentationManager
    @State private var isShowingControls: Bool = false
    @State private var lastControlsActivity = Date()
    @State private var timer: Timer? = nil
    @Environment(\.presentationMode) var presentationMode
    
    // Store the original key handler for KeyboardMonitor
    @State private var originalKeyboardMonitorKeyHandler: ((NSEvent) -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            if !presentationManager.slides.isEmpty && presentationManager.currentSlideIndex < presentationManager.slides.count {
                // Current slide - with bounds check to prevent crashes
                SlideView(slide: presentationManager.slides[presentationManager.currentSlideIndex])
                    .transition(presentationManager.slideTransition)
                    .animation(.easeInOut(duration: 0.5), value: presentationManager.currentSlideIndex)
            }
            
            // Controls overlay
            VStack {
                // Close button at top
                HStack {
                    Spacer()
                    Button(action: {
                        presentationManager.endPresentation()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.7))
                            .padding()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // Navigation controls at bottom
                if isShowingControls {
                    HStack {
                        Button(action: {
                            presentationManager.previousSlide()
                            resetControlsTimer()
                        }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(presentationManager.currentSlideIndex == 0)
                        
                        Spacer()
                        
                        // Slide counter
                        Text("\(presentationManager.currentSlideIndex + 1) / \(presentationManager.slides.count)")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 14))
                        
                        Spacer()
                        
                        Button(action: {
                            presentationManager.nextSlide()
                            resetControlsTimer()
                        }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(presentationManager.currentSlideIndex == presentationManager.slides.count - 1)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: isShowingControls)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { gesture in
                    if gesture.translation.width > 50 {
                        presentationManager.previousSlide()
                    } else if gesture.translation.width < -50 {
                        presentationManager.nextSlide()
                    }
                    resetControlsTimer()
                }
        )
        .gesture(
            TapGesture()
                .onEnded { _ in
                    toggleControls()
                    resetControlsTimer()
                }
        )
        .onAppear {
            // setupKeyboardShortcuts() // Replaced by takeExclusiveKeyboardControl
            takeExclusiveKeyboardControl()
            startControlsTimer()
            
            // Removed: PresentationHelper.shared.enterPresentationMode()
            // This is handled by the PresentationManager when the presentation sequence starts,
            // before this view appears within the dedicated presentation window.
        }
        .onDisappear {
            releaseExclusiveKeyboardControl()
            // Clean up all resources when view disappears
            timer?.invalidate()
            timer = nil
            
            // Remove keyboard observers
            // This will remove any observers PresentationView registered on itself using selectors.
            // If PresentationView used addObserver(forName:object:queue:using:), those tokens would need specific removal.
            NotificationCenter.default.removeObserver(self)
            
            // Removed: PresentationHelper.shared.exitPresentationMode()
            // This is handled by the PresentationManager when endPresentation() is called.
        }
        .background(HostingWindowFinder { window in
            // Window configuration for presentation mode is now primarily handled by
            // PresentationHelper.shared.enterPresentationMode() (called in .onAppear)
            // and PresentationHelper.shared.exitPresentationMode() (called in .onDisappear).
            // This callback no longer directly manipulates window properties like level,
            // styleMask, or frame to prevent redundant updates and potential layout feedback loops.
            if let _ = window {
                // The window instance is available here if PresentationHelper
                // were to be refactored to accept it directly.
                // For now, we assume PresentationHelper targets the correct window globally.
            }
        })
    }
    
    private func takeExclusiveKeyboardControl() {
        // Store the current global key handler from KeyboardMonitor
        self.originalKeyboardMonitorKeyHandler = KeyboardMonitor.shared.keyHandler
        // Set PresentationView's key event handler as the global one
        KeyboardMonitor.shared.keyHandler = { event in
            // self here is a value-captured copy of the PresentationView struct
            self.handleKeyEvent(event)
        }
        // PresentationView will no longer observe the .keyDown notification for slide navigation
        // to prevent double handling.
    }
    
    private func releaseExclusiveKeyboardControl() {
        // Restore the original global key handler
        KeyboardMonitor.shared.keyHandler = self.originalKeyboardMonitorKeyHandler
        self.originalKeyboardMonitorKeyHandler = nil // Clear the stored handler
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Check for ESC key
        if event.keyCode == 53 { // ESC key
            presentationManager.endPresentation()
        }
        
        // Arrow keys navigation
        if event.keyCode == 124 { // Right arrow
            presentationManager.nextSlide()
            resetControlsTimer()
        } else if event.keyCode == 123 { // Left arrow
            presentationManager.previousSlide()
            resetControlsTimer()
        } else if event.keyCode == 49 { // Spacebar
            presentationManager.nextSlide()
            resetControlsTimer()
        }
    }
    
    private func toggleControls() {
        isShowingControls.toggle()
    }
    
    private func startControlsTimer() {
        // Cancel any existing timer first
        timer?.invalidate()
        
        // Create a new timer
        // Removed [weak self] as PresentationView is a struct.
        // A copy of self is captured by the closure.
        // The timer is invalidated in onDisappear, which is important for cleanup.
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in 
            if Date().timeIntervalSince(self.lastControlsActivity) > 3.0 && self.isShowingControls {
                withAnimation {
                    self.isShowingControls = false
                }
            }
        }
    }
    
    private func resetControlsTimer() {
        lastControlsActivity = Date()
        withAnimation {
            isShowingControls = true
        }
    }
}

// Helper to find hosting window
struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct SlideView: View {
    let slide: Slide
    
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            // Slide heading
            Text(slide.heading)
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 60)
            
            // Bullet points
            VStack(alignment: .leading, spacing: 20) {
                ForEach(slide.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 16) {
                        Text("•")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 20, alignment: .center)
                        
                        Text(bullet)
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .animation(.easeInOut.delay(Double(slide.bullets.firstIndex(of: bullet) ?? 0) * 0.15), value: bullet)
                }
            }
            
            Spacer()
        }
        .padding(60)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}