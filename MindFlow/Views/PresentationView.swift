import SwiftUI
import AppKit // For NSEvent and NSViewRepresentable

// Ensure Slide, PresentationManager, PresentationSettings, and KeyboardMonitor are accessible.
// If they are in different modules, you might need to add import statements for those modules.
// For this example, we assume they are in the same target.

struct PresentationView: View {
    @EnvironmentObject var presentationManager: PresentationManager
    @State private var isShowingControls: Bool = false
    @State private var lastControlsActivity = Date()
    @State private var timer: Timer? = nil
    @State private var originalKeyboardMonitorKeyHandler: ((NSEvent) -> Void)? = nil

    var body: some View {
        ZStack {
            // Background uses PresentationSettings
            presentationManager.settings.backgroundColor.color
                .edgesIgnoringSafeArea(.all)

            if !presentationManager.slides.isEmpty &&
               presentationManager.currentSlideIndex >= 0 &&
               presentationManager.currentSlideIndex < presentationManager.slides.count {
                SlideView(slide: presentationManager.slides[presentationManager.currentSlideIndex])
                    .environmentObject(presentationManager) // Pass for settings access in SlideView
                    .transition(presentationManager.slideTransition)
                    .animation(.easeInOut(duration: 0.5), value: presentationManager.currentSlideIndex)
            } else if !presentationManager.slides.isEmpty {
                Text("Error: Invalid slide index.")
                    .foregroundColor(presentationManager.settings.fontColor.color)
                    .font(.custom(presentationManager.settings.fontName, size: presentationManager.settings.headingFontSize))
            } else {
                Text("No slides to present.")
                    .foregroundColor(presentationManager.settings.fontColor.color)
                    .font(.custom(presentationManager.settings.fontName, size: presentationManager.settings.headingFontSize))
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        presentationManager.endPresentation()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(presentationManager.settings.fontColor.color.opacity(0.7))
                            .padding()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
                if isShowingControls && !presentationManager.slides.isEmpty {
                    HStack {
                        Button(action: {
                            presentationManager.previousSlide()
                            resetControlsTimer()
                        }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(presentationManager.settings.fontColor.color.opacity(0.7))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(presentationManager.currentSlideIndex == 0)
                        Spacer()
                        Text("\(presentationManager.currentSlideIndex + 1) / \(presentationManager.slides.count)")
                            .foregroundColor(presentationManager.settings.fontColor.color.opacity(0.7))
                            .font(.custom(presentationManager.settings.fontName, size: 14))
                        Spacer()
                        Button(action: {
                            presentationManager.nextSlide()
                            resetControlsTimer()
                        }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(presentationManager.settings.fontColor.color.opacity(0.7))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(presentationManager.currentSlideIndex >= presentationManager.slides.count - 1)
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
                    if !presentationManager.slides.isEmpty {
                        if gesture.translation.width > 50 {
                            presentationManager.previousSlide()
                        } else if gesture.translation.width < -50 {
                            presentationManager.nextSlide()
                        }
                        resetControlsTimer()
                    }
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
            takeExclusiveKeyboardControl()
            startControlsTimer()
        }
        .onDisappear {
            releaseExclusiveKeyboardControl()
            timer?.invalidate()
            timer = nil
            NotificationCenter.default.removeObserver(self)
        }
        .background(HostingWindowFinder { _ in })
    }

    private func takeExclusiveKeyboardControl() {
        self.originalKeyboardMonitorKeyHandler = KeyboardMonitor.shared.keyHandler
        KeyboardMonitor.shared.keyHandler = { event in
            self.handleKeyEvent(event)
        }
    }

    private func releaseExclusiveKeyboardControl() {
        if self.originalKeyboardMonitorKeyHandler != nil {
            KeyboardMonitor.shared.keyHandler = self.originalKeyboardMonitorKeyHandler
            self.originalKeyboardMonitorKeyHandler = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard !presentationManager.slides.isEmpty else { return }
        switch event.keyCode {
        case 53: // ESC
            presentationManager.endPresentation()
        case 124, 49: // Right arrow or Spacebar
            presentationManager.nextSlide()
            resetControlsTimer()
        case 123: // Left arrow
            presentationManager.previousSlide()
            resetControlsTimer()
        default: break
        }
    }

    private func toggleControls() {
        if !presentationManager.slides.isEmpty { isShowingControls.toggle() }
    }

    private func startControlsTimer() {
        timer?.invalidate()
        guard !presentationManager.slides.isEmpty else { return }
        // PresentationView is a struct, so [weak self] is not applicable here.
        // The closure will capture a copy of `self`.
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _timer in
            // To interact with the @State properties, we need to ensure `self` refers to the current state.
            // However, direct use of `self` inside a repeating timer for a struct can be tricky
            // if the struct instance that started the timer is replaced.
            // For this pattern to be more robust with structs, you might need to manage the timer
            // from an ObservableObject or pass necessary state to the timer's context if possible.
            // Given the current structure, this might lead to the timer operating on an outdated copy of `self`.
            // A common approach is to have the timer managed by an ObservableObject that this View observes.
            
            // For now, let's assume this simplified version for brevity, but be aware of potential issues:
            if Date().timeIntervalSince(self.lastControlsActivity) > 3.0 && self.isShowingControls {
                withAnimation {
                    self.isShowingControls = false
                }
            }
        }
    }

    private func resetControlsTimer() {
        lastControlsActivity = Date()
        if !isShowingControls && !presentationManager.slides.isEmpty {
            withAnimation {
                isShowingControls = true
            }
        }
    }
}

struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.callback(view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct SlideView: View {
    let slide: Slide
    @EnvironmentObject var presentationManager: PresentationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            Text(slide.heading)
                .font(.custom(presentationManager.settings.fontName, size: presentationManager.settings.headingFontSize).weight(.bold))
                .foregroundColor(presentationManager.settings.fontColor.color)
                .padding(.top, 60)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(slide.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 16) {
                        Text(presentationManager.settings.bulletStyle.rawValue)
                            .font(.custom(presentationManager.settings.fontName, size: presentationManager.settings.fontSize))
                            .foregroundColor(presentationManager.settings.fontColor.color)
                            .frame(minWidth: presentationManager.settings.fontSize * 1.2, alignment: .center)
                        Text(bullet)
                            .font(.custom(presentationManager.settings.fontName, size: presentationManager.settings.fontSize))
                            .foregroundColor(presentationManager.settings.fontColor.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .animation(.easeInOut(duration: 0.2).delay(Double(slide.bullets.firstIndex(of: bullet) ?? 0) * 0.05), value: presentationManager.currentSlideIndex)
                }
            }
            Spacer()
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}