import SwiftUI
import AppKit


struct InfiniteCanvas: View {
   @StateObject private var viewModel = CanvasViewModel()
   @State private var offset: CGPoint = .zero
   @State private var scale: CGFloat = 1.0
   @State private var lastDragPosition: CGPoint?
   @State private var visibleRect: CGRect = .zero
   @State private var cursorPosition: CGPoint = .zero
   @State private var topicsBounds: CGRect = .zero // Track bounds of all topics
   @State private var isSidebarOpen: Bool = false // Track sidebar state
   @State private var isShowingColorPicker: Bool = false // Track color picker state
   @State private var isShowingBorderColorPicker: Bool = false // Track border color picker state
   @State private var isShowingForegroundColorPicker: Bool = false // Track foreground color picker state
   @State private var isShowingBackgroundColorPicker: Bool = false // Track background color picker state
   @State private var backgroundStyle: BackgroundStyle = .grid // Track background style
   @State private var backgroundColor: Color = Color(.windowBackgroundColor) // Track background color
   @State private var backgroundOpacity: Double = 1.0 // Track background opacity
   @State private var sidebarMode: SidebarMode = .style
   @State private var isRelationshipMode: Bool = false // Track relationship mode
   @State private var touchBarDelegate: InfiniteCanvasTouchBarDelegate?
   
   // Reference to the NSViewRepresentable for exporting
   @State private var canvasViewRef: CanvasViewRepresentable?
   
   // Constants for canvas
   private let minScale: CGFloat = 0.1
   private let maxScale: CGFloat = 5.0
   private let gridSize: CGFloat = 50
   private let minimapSize: CGFloat = 200 // Size of the minimap
   private let minimapPadding: CGFloat = 16 // Padding from the edges
   private let topBarHeight: CGFloat = 40 // Height of the top bar
   private let sidebarWidth: CGFloat = 300 // Width of the sidebar
   
   // Background style enum
   enum BackgroundStyle: String, CaseIterable, Identifiable {
       case none = "None"
       case grid = "Grid"
       case dots = "Dots"
       
       var id: String { self.rawValue }
       
       var iconName: String {
           switch self {
           case .none: return "square"
           case .grid: return "grid"
           case .dots: return "circle.grid.3x3"
           }
       }
   }
   
   // Convert screen coordinates to canvas coordinates
   private func screenToCanvasPosition(_ screenPosition: CGPoint) -> CGPoint {
       let x = (screenPosition.x - offset.x) / scale
       let y = (screenPosition.y - offset.y) / scale
       return CGPoint(x: x, y: y)
   }
   
   // Center the canvas on a specific point
   private func centerCanvasOn(_ point: CGPoint, in geometry: GeometryProxy) {
       let centerX = geometry.size.width / 2
       let centerY = geometry.size.height / 2
       
       // Calculate the new offset to center the point
       offset = CGPoint(
           x: centerX - (point.x * scale),
           y: centerY - (point.y * scale)
       )
   }
   
   // Convert minimap coordinates to canvas coordinates
   private func minimapToCanvasPosition(_ minimapPoint: CGPoint, size: CGSize) -> CGPoint {
       guard !topicsBounds.isEmpty else { return .zero }
       
       // Calculate the scale factors for the minimap
       let scaleX = topicsBounds.width / size.width
       let scaleY = topicsBounds.height / size.height
       
       // Convert minimap coordinates to canvas coordinates
       let canvasX = minimapPoint.x * scaleX + topicsBounds.minX
       let canvasY = minimapPoint.y * scaleY + topicsBounds.minY
       
       return CGPoint(x: canvasX, y: canvasY)
   }
   
   // Calculate bounds containing all topics
   private func calculateTopicsBounds() -> CGRect {
       guard !viewModel.topics.isEmpty else { return .zero }
       
       var minX = CGFloat.infinity
       var minY = CGFloat.infinity
       var maxX = -CGFloat.infinity
       var maxY = -CGFloat.infinity
       
       func updateBounds(for topic: Topic) {
           minX = min(minX, topic.position.x)
           minY = min(minY, topic.position.y)
           maxX = max(maxX, topic.position.x)
           maxY = max(maxY, topic.position.y)
           
           // Include subtopics
           for subtopic in topic.subtopics {
               updateBounds(for: subtopic)
           }
       }
       
       // Process all topics and their subtopics
       for topic in viewModel.topics {
           updateBounds(for: topic)
       }
       
       // Add padding
       let padding: CGFloat = 100
       return CGRect(
           x: minX - padding,
           y: minY - padding,
           width: (maxX - minX) + (padding * 2),
           height: (maxY - minY) + (padding * 2)
       )
   }
   
   // Add these variables to the state variables at the top of InfiniteCanvas struct

   @State private var currentTheme: ThemeSettings? = nil

   // Define a ThemeSettings struct to hold theme information
   struct ThemeSettings {
       let name: String
       let backgroundColor: Color
       let backgroundStyle: BackgroundStyle
       let topicFillColor: Color
       let topicBorderColor: Color
       let topicTextColor: Color
   }
   
   var body: some View {
       GeometryReader { geometry in
           ZStack(alignment: .top) {
               // Background layer with grid and topics
               ZStack {
                   // Background layer
                   Canvas { context, size in
                       // Draw background
                       context.fill(
                           Path(CGRect(origin: .zero, size: size)),
                           with: .color(backgroundColor.opacity(backgroundOpacity))
                       )
                       
                       // Calculate visible area in canvas coordinates
                       let visibleArea = CGRect(
                           x: -offset.x / scale,
                           y: -offset.y / scale,
                           width: size.width / scale,
                           height: size.height / scale
                       )
                       
                       // Calculate grid bounds with padding
                       let padding = max(size.width, size.height) / scale
                       let gridBounds = visibleArea.insetBy(dx: -padding, dy: -padding)
                       
                       // Apply canvas transformations
                       context.translateBy(x: offset.x, y: offset.y)
                       context.scaleBy(x: scale, y: scale)
                       
                       // Draw the selected background style
                       switch backgroundStyle {
                       case .none:
                           // No grid or pattern
                           break
                           
                       case .grid:
                           // Calculate grid line ranges
                           let startX = floor(gridBounds.minX / gridSize) * gridSize
                           let endX = ceil(gridBounds.maxX / gridSize) * gridSize
                           let startY = floor(gridBounds.minY / gridSize) * gridSize
                           let endY = ceil(gridBounds.maxY / gridSize) * gridSize
                           
                           // Draw vertical grid lines
                           for x in stride(from: startX, through: endX, by: gridSize) {
                               context.stroke(
                                   Path { path in
                                       path.move(to: CGPoint(x: x, y: startY))
                                       path.addLine(to: CGPoint(x: x, y: endY))
                                   },
                                   with: .color(.gray.opacity(0.2)),
                                   lineWidth: 0.5 / scale
                               )
                           }
                           
                           // Draw horizontal grid lines
                           for y in stride(from: startY, through: endY, by: gridSize) {
                               context.stroke(
                                   Path { path in
                                       path.move(to: CGPoint(x: startX, y: y))
                                       path.addLine(to: CGPoint(x: endX, y: y))
                                   },
                                   with: .color(.gray.opacity(0.2)),
                                   lineWidth: 0.5 / scale
                               )
                           }
                           
                       case .dots:
                           // Calculate dot positions
                           let dotSize: CGFloat = 2.0 / scale
                           let startX = floor(gridBounds.minX / gridSize) * gridSize
                           let endX = ceil(gridBounds.maxX / gridSize) * gridSize
                           let startY = floor(gridBounds.minY / gridSize) * gridSize
                           let endY = ceil(gridBounds.maxY / gridSize) * gridSize
                           
                           // Draw dots at grid intersections
                           for x in stride(from: startX, through: endX, by: gridSize) {
                               for y in stride(from: startY, through: endY, by: gridSize) {
                                   let dotRect = CGRect(
                                       x: x - (dotSize / 2),
                                       y: y - (dotSize / 2),
                                       width: dotSize,
                                       height: dotSize
                                   )
                                   context.fill(
                                       Path(ellipseIn: dotRect),
                                       with: .color(.gray.opacity(0.3))
                                   )
                               }
                           }
                       }
                   }
                   
                   // Topics layer
                   TopicsCanvasView(viewModel: viewModel, isRelationshipMode: $isRelationshipMode)
                       .scaleEffect(scale)
                       .offset(x: offset.x, y: offset.y)
               }
               .padding(.top, topBarHeight) // Add padding for the top bar
               .background(
                   // Add a representable that gives us access to the underlying NSView
                   CanvasViewRepresentable(onViewCreated: { view in
                       self.canvasViewRef = view
                   })
               )
               
               // Top bar
               Rectangle()
                   .fill(Color(.windowBackgroundColor))
                   .frame(height: topBarHeight)
                   .overlay(
                       HStack(spacing: 0) {
                           Text("MindFlow")
                               .foregroundColor(.primary)
                               .padding(.horizontal)
                           
                           Spacer()
                           
                           // Group all central buttons together in the middle
                           HStack(spacing: 12) {
                               // Auto layout button
                               Button(action: {
                                   viewModel.performAutoLayout()
                               }) {
                                   HStack(spacing: 4) {
                                       Image(systemName: "rectangle.grid.1x2")
                                           .font(.system(size: 14))
                                       Text("Auto Layout")
                                           .font(.system(size: 13))
                                   }
                                   .padding(.vertical, 6)
                                   .padding(.horizontal, 10)
                                   .background(
                                       RoundedRectangle(cornerRadius: 6)
                                           .fill(Color.gray.opacity(0.15))
                                   )
                               }
                               .buttonStyle(PlainButtonStyle())
                               .help("Automatically arrange topics with perfect spacing")
                               
                               // Collapse button - enabled when a topic with children is selected
                               Button(action: {
                                   if let selectedId = viewModel.selectedTopicId {
                                       viewModel.toggleCollapseState(topicId: selectedId)
                                   }
                               }) {
                                   HStack(spacing: 4) {
                                       let isCollapsed = viewModel.selectedTopicId.flatMap(viewModel.isTopicCollapsed) ?? false
                                       let totalDescendants = viewModel.selectedTopicId.flatMap { id in 
                                           if let topic = viewModel.getTopicById(id) {
                                               return viewModel.countAllDescendants(for: topic)
                                           }
                                           return 0
                                       } ?? 0
                                       
                                       Image(systemName: isCollapsed ? "chevron.down.circle" : "chevron.right.circle")
                                           .foregroundColor(totalDescendants > 0 ? .primary : .gray)
                                           .font(.system(size: 14))
                                       
                                       Text(isCollapsed ? "Expand" : "Collapse")
                                           .font(.system(size: 13))
                                           .foregroundColor(totalDescendants > 0 ? .primary : .gray)
                                   }
                                   .padding(.vertical, 6)
                                   .padding(.horizontal, 10)
                                   .background(
                                       RoundedRectangle(cornerRadius: 6)
                                           .fill(Color.gray.opacity(0.15))
                                   )
                               }
                               .buttonStyle(PlainButtonStyle())
                               .disabled(viewModel.selectedTopicId == nil || 
                                        (viewModel.selectedTopicId.flatMap { id in 
                                            viewModel.getTopicById(id)
                                        }.flatMap { topic in 
                                            viewModel.countAllDescendants(for: topic)
                                        } ?? 0) == 0)
                               .help("Collapse or expand the selected topic")
                               
                               // Relationship button
                               Button(action: {
                                   isRelationshipMode.toggle()
                               }) {
                                   HStack(spacing: 4) {
                                       Image(systemName: "arrow.triangle.branch")
                                           .foregroundColor(isRelationshipMode ? .blue : .primary)
                                           .font(.system(size: 14))
                                       
                                       Text("Relationship")
                                           .font(.system(size: 13))
                                           .foregroundColor(isRelationshipMode ? .blue : .primary)
                                   }
                                   .padding(.vertical, 6)
                                   .padding(.horizontal, 10)
                                   .background(
                                       RoundedRectangle(cornerRadius: 6)
                                           .fill(isRelationshipMode ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                                   )
                               }
                               .buttonStyle(PlainButtonStyle())
                               .help("Create relationships between topics")
                           }
                           
                           Spacer()
                           
                           // Sidebar toggle button
                           Button(action: {
                               withAnimation(.easeInOut(duration: 0.3)) {
                                   isSidebarOpen.toggle()
                               }
                           }) {
                               Image(systemName: isSidebarOpen ? "sidebar.right" : "sidebar.right")
                                   .foregroundColor(.primary)
                                   .font(.system(size: 14, weight: .regular))
                                   .frame(width: 28, height: topBarHeight)
                                   .contentShape(Rectangle())
                           }
                           .buttonStyle(.plain)
                           .background(Color(.windowBackgroundColor))
                           .focusable(false) // Prevent the button from receiving focus
                       }
                   )
                   .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                   .zIndex(1) // Ensure top bar stays above other content
               
               // Minimap overlay with conditional position
               MinimapView(
                   topics: viewModel.topics,
                   visibleRect: CGRect(
                       x: -offset.x / scale,
                       y: -offset.y / scale,
                       width: geometry.size.width / scale,
                       height: geometry.size.height / scale
                   ),
                   topicsBounds: topicsBounds,
                   size: CGSize(width: minimapSize, height: minimapSize),
                   onTapLocation: { minimapPoint in
                       let canvasPoint = minimapToCanvasPosition(minimapPoint, size: CGSize(width: minimapSize, height: minimapSize))
                       centerCanvasOn(canvasPoint, in: geometry)
                   }
               )
               .frame(width: minimapSize, height: minimapSize)
               .background(
                   ZStack {
                       RoundedRectangle(cornerRadius: 8)
                           .fill(backgroundColor.opacity(backgroundOpacity))
                           .blur(radius: 1)
                       
                       RoundedRectangle(cornerRadius: 8)
                           .fill(backgroundColor.opacity(backgroundOpacity * 0.8))
                       
                       // Subtle inner glow
                       RoundedRectangle(cornerRadius: 8)
                           .stroke(Color.white.opacity(0.3), lineWidth: 1)
                           .padding(1)
                   }
               )
               .cornerRadius(8)
               .overlay(
                   RoundedRectangle(cornerRadius: 8)
                       .stroke(Color.gray.opacity(0.6), lineWidth: 2.5)
               )
               .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
               .padding(minimapPadding)
               .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
               .padding(.top, topBarHeight + minimapPadding) // Add padding to position below top bar
               .padding(.trailing, isSidebarOpen ? sidebarWidth + minimapPadding : minimapPadding)
               
               // Sidebar
               if isSidebarOpen {
                   VStack(spacing: 0) {
                       Rectangle()
                           .fill(Color.clear)
                           .frame(height: topBarHeight)
                       
                       HStack(spacing: 0) {
                           Spacer()
                           Rectangle()
                               .fill(Color(.windowBackgroundColor))
                               .frame(width: sidebarWidth)
                               .overlay(
                                   VStack(spacing: 16) {
                                       // Sidebar header with segmented control
                                       Picker("", selection: $sidebarMode) {
                                           Text("Style").tag(SidebarMode.style)
                                           Text("Map").tag(SidebarMode.map)
                                       }
                                       .pickerStyle(.segmented)
                                       .padding(.horizontal)
                                       .padding(.top, 12)
                                       
                                       Divider()
                                           .padding(.horizontal)
                                       
                                       if sidebarMode == .style {
                                           // Remove Canvas Background Style section from here
                                           
                                           // Topic styling - only shown when a topic is selected
                                           if let selectedTopic = viewModel.getSelectedTopic() {
                                               // Topic Style header
                                               Text("Topic Style")
                                                   .foregroundColor(.primary)
                                                   .font(.headline)
                                                   .frame(maxWidth: .infinity, alignment: .leading)
                                                   .padding(.top, 12)
                                                   .padding(.horizontal)
                                               
                                               Divider()
                                                   .padding(.horizontal)
                                               
                                               // Shape selector
                                               ShapeSelector(
                                                   selectedShape: selectedTopic.shape,
                                                   onShapeSelected: { shape in
                                                       viewModel.updateTopicShape(selectedTopic.id, shape: shape)
                                                   }
                                               )
                                               
                                               // Fill control
                                               HStack(spacing: 8) {
                                                   Text("Fill")
                                                       .foregroundColor(.primary)
                                                       .font(.system(size: 13))
                                                   
                                                   Spacer()
                                                   
                                                   Button(action: {
                                                       isShowingColorPicker.toggle()
                                                   }) {
                                                       RoundedRectangle(cornerRadius: 2)
                                                           .fill(selectedTopic.backgroundColor)
                                                           .frame(width: 50, height: 28)
                                                           .overlay(
                                                               RoundedRectangle(cornerRadius: 2)
                                                                   .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                           )
                                                   }
                                                   .buttonStyle(PlainButtonStyle())
                                                   .popover(isPresented: $isShowingColorPicker, arrowEdge: .bottom) {
                                                       ColorPickerView(
                                                           selectedColor: Binding(
                                                               get: { selectedTopic.backgroundColor },
                                                               set: { newColor in
                                                                   viewModel.updateTopicBackgroundColor(selectedTopic.id, color: newColor)
                                                               }
                                                           ),
                                                           opacity: Binding(
                                                               get: { selectedTopic.backgroundOpacity },
                                                               set: { newOpacity in
                                                                   viewModel.updateTopicBackgroundOpacity(selectedTopic.id, opacity: newOpacity)
                                                               }
                                                           )
                                                       )
                                                   }
                                               }
                                                       .padding(.horizontal)
                                               
                                               // Border control
                                               HStack(spacing: 8) {
                                                   Text("Border")
                                                       .foregroundColor(.primary)
                                                       .font(.system(size: 13))
                                                   
                                                   Spacer()
                                                   
                                                   Button(action: {
                                                       isShowingBorderColorPicker.toggle()
                                                   }) {
                                                       RoundedRectangle(cornerRadius: 2)
                                                           .fill(selectedTopic.borderColor)
                                                           .frame(width: 50, height: 28)
                                                           .overlay(
                                                               RoundedRectangle(cornerRadius: 2)
                                                                   .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                           )
                                                   }
                                                   .buttonStyle(PlainButtonStyle())
                                                   .popover(isPresented: $isShowingBorderColorPicker, arrowEdge: .bottom) {
                                                       ColorPickerView(
                                                           selectedColor: Binding(
                                                               get: { selectedTopic.borderColor },
                                                               set: { newColor in
                                                                   viewModel.updateTopicBorderColor(selectedTopic.id, color: newColor)
                                                               }
                                                           ),
                                                           opacity: Binding(
                                                               get: { selectedTopic.borderOpacity },
                                                               set: { newOpacity in
                                                                   viewModel.updateTopicBorderOpacity(selectedTopic.id, opacity: newOpacity)
                                                               }
                                                           )
                                                       )
                                                   }
                                               }
                                               .padding(.horizontal)
                                               
                                               // Border width control
                                               HStack(spacing: 8) {
                                                   Text("Border Width")
                                                       .foregroundColor(.primary)
                                                       .font(.system(size: 13))
                                                   
                                                   Spacer()
                                                   
                                                   Menu {
                                                       ForEach(Topic.BorderWidth.allCases, id: \.self) { width in
                                                           Button(action: {
                                                               viewModel.updateTopicBorderWidth(selectedTopic.id, width: width)
                                                           }) {
                                                               HStack {
                                                                   if selectedTopic.borderWidth == width {
                                                                       Image(systemName: "checkmark")
                                                                           .frame(width: 16, alignment: .center)
                                                                   } else {
                                                                       Color.clear
                                                                           .frame(width: 16)
                                                                   }
                                                                   Text(width.displayName)
                                                                   Spacer()
                                                               }
                                                               .contentShape(Rectangle())
                                                           }
                                                       }
                                                   } label: {
                                                       HStack {
                                                           Text(selectedTopic.borderWidth.displayName)
                                                               .foregroundColor(.white)
                                                       }
                                                       .padding(.horizontal, 8)
                                                       .padding(.vertical, 6)
                                                       .frame(width: 100)
                                                       .background(Color.black.opacity(0.6))
                                                       .cornerRadius(6)
                                                   }
                                               }
                                               .padding(.horizontal)
                                           } else {
                                               Text("Select a topic to edit its properties")
                                                   .foregroundColor(.secondary)
                                                   .padding()
                                           }
                                           
                                           // Spacer(minLength: 0)
                                           
                                           // Text section
                                           VStack(spacing: 16) {
                                               // Section header
                                               Text("Text")
                                                   .foregroundColor(.primary)
                                                   .font(.headline)
                                                   .frame(maxWidth: .infinity, alignment: .leading)
                                                   .padding(.top, 12)
                                                   .padding(.horizontal)
                                               
                                               Divider()
                                                   .padding(.horizontal)
                                               
                                               // Row 1: Font style and size
                                               HStack(spacing: 8) {
                                                   Menu {
                                                       ForEach(["Apple SD Gothic", "System", "Helvetica", "Arial", "Times New Roman"], id: \.self) { font in
                                                           Button(action: {
                                                               if let selectedTopic = viewModel.getSelectedTopic() {
                                                                   viewModel.updateTopicFont(selectedTopic.id, font: font)
                                                               }
                                                           }) {
                                                               Text(font)
                                                           }
                                                       }
                                                   } label: {
                                                       HStack {
                                                           Text(viewModel.getSelectedTopic()?.font ?? "System")
                                                               .lineLimit(1)
                                                               .truncationMode(.tail)
                                                           Spacer()
                                                           Image(systemName: "chevron.down")
                                                               .font(.system(size: 10))
                                                       }
                                                       .padding(.horizontal, 8)
                                                       .padding(.vertical, 6)
                                                       .frame(width: 120)
                                                       .background(Color(.darkGray))
                                                       .cornerRadius(6)
                                                   }
                                                   
                                                   Menu {
                                                       ForEach([8, 10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64], id: \.self) { size in
                                                           Button(action: {
                                                               if let selectedTopic = viewModel.getSelectedTopic() {
                                                                   viewModel.updateTopicFontSize(selectedTopic.id, size: CGFloat(size))
                                                               }
                                                           }) {
                                                               Text("\(size)")
                                                           }
                                                       }
                                                   } label: {
                                                       HStack {
                                                           Text("\(Int(viewModel.getSelectedTopic()?.fontSize ?? 16))")
                                                           Spacer()
                                                           Image(systemName: "chevron.down")
                                                               .font(.system(size: 10))
                                                       }
                                                       .padding(.horizontal, 8)
                                                       .padding(.vertical, 6)
                                                       .frame(width: 60)
                                                       .background(Color(.darkGray))
                                                       .cornerRadius(6)
                                                   }
                                               }
                                               .padding(.horizontal)
                                               
                                               // Row 2: Font weight and foreground color
                                               HStack(spacing: 8) {
                                                   Menu {
                                                       ForEach(Font.Weight.allCases, id: \.self) { weight in
                                                           Button(action: {
                                                               if let selectedTopic = viewModel.getSelectedTopic() {
                                                                   viewModel.updateTopicFontWeight(selectedTopic.id, weight: weight)
                                                               }
                                                           }) {
                                                               Text(weight.displayName)
                                                           }
                                                       }
                                                   } label: {
                                                       HStack {
                                                           Text(viewModel.getSelectedTopic()?.fontWeight.displayName ?? "Medium")
                                                           Spacer()
                                                           Image(systemName: "chevron.down")
                                                               .font(.system(size: 10))
                                                       }
                                                       .padding(.horizontal, 8)
                                                       .padding(.vertical, 6)
                                                       .frame(width: 120)
                                                       .background(Color(.darkGray))
                                                       .cornerRadius(6)
                                                   }
                                                   
                                                   Button(action: {
                                                       isShowingForegroundColorPicker.toggle()
                                                   }) {
                                                       RoundedRectangle(cornerRadius: 2)
                                                           .fill(viewModel.getSelectedTopic()?.foregroundColor ?? .white)
                                                           .frame(width: 50, height: 28)
                                                           .overlay(
                                                               RoundedRectangle(cornerRadius: 2)
                                                                   .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                           )
                                                   }
                                                   .buttonStyle(PlainButtonStyle())
                                                   .popover(isPresented: $isShowingForegroundColorPicker, arrowEdge: .bottom) {
                                                       if let selectedTopic = viewModel.getSelectedTopic() {
                                                           ColorPickerView(
                                                               selectedColor: Binding(
                                                                   get: { selectedTopic.foregroundColor },
                                                                   set: { newColor in
                                                                       viewModel.updateTopicForegroundColor(selectedTopic.id, color: newColor)
                                                                   }
                                                               ),
                                                               opacity: Binding(
                                                                   get: { selectedTopic.foregroundOpacity },
                                                                   set: { newOpacity in
                                                                       viewModel.updateTopicForegroundOpacity(selectedTopic.id, opacity: newOpacity)
                                                                   }
                                                               )
                                                           )
                                                       }
                                                   }
                                               }
                                               .padding(.horizontal)
                                               
                                               // Row 3: Text style controls
                                               HStack(spacing: 0) {
                                                   ForEach(TextStyle.allCases, id: \.self) { style in
                                                       Button(action: {
                                                           if let selectedTopic = viewModel.getSelectedTopic() {
                                                               let isEnabled = !(selectedTopic.textStyles.contains(style))
                                                               viewModel.updateTopicTextStyle(selectedTopic.id, style: style, isEnabled: isEnabled)
                                                           }
                                                       }) {
                                                           Image(systemName: style.iconName)
                                                               .foregroundColor(.white)
                                                               .frame(maxWidth: .infinity, minHeight: 28)
                                                               .background(viewModel.getSelectedTopic()?.textStyles.contains(style) ?? false ? Color.gray.opacity(0.3) : Color.clear)
                                                               .contentShape(Rectangle())
                                                       }
                                                       .buttonStyle(.plain)
                                                       
                                                       if style != .underline {
                                                           Divider()
                                                               .frame(height: 16)
                                                               .background(Color.black.opacity(0.2))
                                                       }
                                                   }
                                                   
                                                   Divider()
                                                       .frame(height: 16)
                                                       .background(Color.black.opacity(0.2))
                                                   
                                                   Button(action: {
                                                       if let selectedTopic = viewModel.getSelectedTopic() {
                                                           let nextCase = TextCase.allCases.first { $0 != selectedTopic.textCase } ?? .none
                                                           viewModel.updateTopicTextCase(selectedTopic.id, textCase: nextCase)
                                                       }
                                                   }) {
                                                       Image(systemName: "textformat")
                                                           .foregroundColor(.white)
                                                           .frame(maxWidth: .infinity, minHeight: 28)
                                                           .contentShape(Rectangle())
                                                   }
                                                   .buttonStyle(.plain)
                                               }
                                               .padding(.vertical, 2)
                                               .padding(.horizontal, 4)
                                               .background(Color(.darkGray))
                                               .cornerRadius(6)
                                               .padding(.horizontal)
                                               
                                               // Row 4: Text alignment
                                               Picker("", selection: Binding(
                                                   get: { viewModel.getSelectedTopic()?.textAlignment ?? .center },
                                                   set: { alignment in
                                                       if let selectedTopic = viewModel.getSelectedTopic() {
                                                           viewModel.updateTopicTextAlignment(selectedTopic.id, alignment: alignment)
                                                       }
                                                   }
                                               )) {
                                                   ForEach(TextAlignment.allCases, id: \.self) { alignment in
                                                       Image(systemName: alignment.iconName)
                                                           .tag(alignment)
                                                   }
                                               }
                                               .pickerStyle(.segmented)
                                               .padding(.horizontal)
                                           }
                                           
                                           // Branch Style section
                                           VStack(spacing: 16) {
                                               // Section header
                                               Text("Branch Style")
                                                   .foregroundColor(.primary)
                                                   .font(.headline)
                                                   .frame(maxWidth: .infinity, alignment: .leading)
                                                   .padding(.top, 12)
                                                   .padding(.horizontal)
                                               
                                               // Add description to clarify this is a global setting
                                               Text("Branch style applies to all connections on the canvas")
                                                   .foregroundColor(.secondary)
                                                   .font(.system(size: 12))
                                                   .frame(maxWidth: .infinity, alignment: .leading)
                                                   .padding(.horizontal)
                                               
                                               Divider()
                                                   .padding(.horizontal)
                                               
                                               // Branch style dropdown
                                               if let selectedTopic = viewModel.getSelectedTopic() {
                                                   HStack(spacing: 8) {
                                                       Menu {
                                                           ForEach(Topic.BranchStyle.allCases, id: \.self) { style in
                                                               Button(action: {
                                                                   // Use null UUID to indicate we want to update all topics
                                                                   viewModel.updateTopicBranchStyle(nil, style: style)
                                                               }) {
                                                                   HStack {
                                                                       // Check the current global style by looking at the selected topic
                                                                       if selectedTopic.branchStyle == style {
                                                                           Image(systemName: "checkmark")
                                                                               .frame(width: 16, alignment: .center)
                                                                       } else {
                                                                           Color.clear
                                                                               .frame(width: 16)
                                                                       }
                                                                       Text(style.displayName)
                                                                       Spacer()
                                                                   }
                                                                   .contentShape(Rectangle())
                                                               }
                                                           }
                                                       } label: {
                                                           HStack {
                                                               Text(selectedTopic.branchStyle.displayName)
                                                                   .foregroundColor(.white)
                                                               Spacer()
                                                               Image(systemName: "chevron.down")
                                                                   .font(.system(size: 10))
                                                           }
                                                           .padding(.horizontal, 8)
                                                           .padding(.vertical, 6)
                                                           .frame(width: 120)
                                                           .background(Color(.darkGray))
                                                           .cornerRadius(6)
                                                       }
                                                       
                                                       // Add a visual indicator showing the style affects all connections
                                                       Image(systemName: "arrow.triangle.2.circlepath")
                                                           .foregroundColor(.secondary)
                                                           .font(.system(size: 16))
                                                           .help("Changes all connections on the canvas")
                                                   }
                                                   .padding(.horizontal)
                                               }
                                           }
                                           
                                           Spacer(minLength: 20)
                                       } else {
                                           ScrollView {
                                           // Map view content
                                               VStack(spacing: 16) {
                                                   Text("Map View")
                                                       .foregroundColor(.primary)
                                                       .font(.headline)
                                                       .frame(maxWidth: .infinity, alignment: .leading)
                                                       .padding(.top, 12)
                                                       .padding(.horizontal)
                                                   
                                                   Divider()
                                                       .padding(.horizontal)
                                                   
                                                   // Canvas Background Style section moved here
                                                   // Section header
                                                   Text("Canvas Background")
                                                       .foregroundColor(.primary)
                                                       .font(.headline)
                                                       .frame(maxWidth: .infinity, alignment: .leading)
                                                       .padding(.top, 12)
                                                       .padding(.horizontal)
                                                   
                                                   Divider()
                                                       .padding(.horizontal)
                                                   
                                                   // Background style selector
                                                   HStack(spacing: 8) {
                                                       Text("Style")
                                                           .foregroundColor(.primary)
                                                           .font(.system(size: 13))
                                                       
                                                       Spacer()
                                                       
                                                       Picker("", selection: $backgroundStyle) {
                                                           ForEach(BackgroundStyle.allCases) { style in
                                                               HStack {
                                                                   Image(systemName: style.iconName)
                                                                       .font(.system(size: 14))
                                                                   Text(style.rawValue)
                                                               }
                                                               .tag(style)
                                                           }
                                                       }
                                                       .pickerStyle(MenuPickerStyle())
                                                       .frame(width: 120)
                                                   }
                                                   .padding(.horizontal)
                                                   
                                                   // Background color control
                                                   HStack(spacing: 8) {
                                                       Text("Color")
                                                           .foregroundColor(.primary)
                                                           .font(.system(size: 13))
                                                       
                                                       Spacer()
                                                       
                                                       Button(action: {
                                                           isShowingBackgroundColorPicker.toggle()
                                                       }) {
                                                           RoundedRectangle(cornerRadius: 2)
                                                               .fill(backgroundColor)
                                                               .frame(width: 50, height: 28)
                                                               .overlay(
                                                                   RoundedRectangle(cornerRadius: 2)
                                                                       .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                               )
                                                       }
                                                       .buttonStyle(PlainButtonStyle())
                                                       .popover(isPresented: $isShowingBackgroundColorPicker, arrowEdge: .bottom) {
                                                           ColorPickerView(
                                                               selectedColor: $backgroundColor,
                                                               opacity: $backgroundOpacity
                                                           )
                                                       }
                                                   }
                                                   .padding(.horizontal)
                                                   
                                                   Divider()
                                                       .padding(.horizontal)
                                                   
                                                   // Original Map View content - changed from placeholder
                                                   Text("Auto Layout Settings")
                                                       .foregroundColor(.primary)
                                                       .font(.headline)
                                                       .frame(maxWidth: .infinity, alignment: .leading)
                                                       .padding(.top, 12)
                                                       .padding(.horizontal)
                                                   
                                                   Divider()
                                                       .padding(.horizontal)
                                                   
                                                   // Add Theme section here
                                                   Text("Theme")
                                                       .foregroundColor(.primary)
                                                       .font(.headline)
                                                       .frame(maxWidth: .infinity, alignment: .leading)
                                                       .padding(.top, 12)
                                                       .padding(.horizontal)
                                                   
                                                   Divider()
                                                       .padding(.horizontal)
                                                   
                                                   // Theme selector grid
                                                   LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                                       // Nature theme - greens and earth tones
                                                       ThemeButton(
                                                           name: "Nature",
                                                           primaryColor: Color(red: 0.4, green: 0.65, blue: 0.4),
                                                           secondaryColor: Color(red: 0.85, green: 0.9, blue: 0.85),
                                                           accentColor: Color(red: 0.35, green: 0.55, blue: 0.35),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.9, green: 0.95, blue: 0.9),
                                                                   backgroundStyle: .grid,
                                                                   topicFillColor: Color(red: 0.75, green: 0.85, blue: 0.75),
                                                                   topicBorderColor: Color(red: 0.4, green: 0.65, blue: 0.4),
                                                                   topicTextColor: Color(red: 0.15, green: 0.3, blue: 0.15),
                                                                   themeName: "Nature"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Ocean theme - blues and cool tones
                                                       ThemeButton(
                                                           name: "Ocean",
                                                           primaryColor: Color(red: 0.15, green: 0.5, blue: 0.7),
                                                           secondaryColor: Color(red: 0.85, green: 0.9, blue: 0.95),
                                                           accentColor: Color(red: 0.1, green: 0.4, blue: 0.6),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.9, green: 0.95, blue: 1.0),
                                                                   backgroundStyle: .dots,
                                                                   topicFillColor: Color(red: 0.8, green: 0.9, blue: 0.95),
                                                                   topicBorderColor: Color(red: 0.15, green: 0.5, blue: 0.7),
                                                                   topicTextColor: Color(red: 0.1, green: 0.3, blue: 0.5),
                                                                   themeName: "Ocean"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Sunset theme - warm oranges and reds
                                                       ThemeButton(
                                                           name: "Sunset",
                                                           primaryColor: Color(red: 0.9, green: 0.5, blue: 0.3),
                                                           secondaryColor: Color(red: 1.0, green: 0.95, blue: 0.9),
                                                           accentColor: Color(red: 0.8, green: 0.4, blue: 0.2),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.98, green: 0.95, blue: 0.9),
                                                                   backgroundStyle: .grid,
                                                                   topicFillColor: Color(red: 1.0, green: 0.9, blue: 0.85),
                                                                   topicBorderColor: Color(red: 0.9, green: 0.5, blue: 0.3),
                                                                   topicTextColor: Color(red: 0.6, green: 0.3, blue: 0.1),
                                                                   themeName: "Sunset"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Lavender theme - purples and lilacs
                                                       ThemeButton(
                                                           name: "Lavender",
                                                           primaryColor: Color(red: 0.55, green: 0.45, blue: 0.7),
                                                           secondaryColor: Color(red: 0.95, green: 0.9, blue: 1.0),
                                                           accentColor: Color(red: 0.45, green: 0.35, blue: 0.6),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.96, green: 0.94, blue: 0.98),
                                                                   backgroundStyle: .dots,
                                                                   topicFillColor: Color(red: 0.9, green: 0.85, blue: 0.95),
                                                                   topicBorderColor: Color(red: 0.55, green: 0.45, blue: 0.7),
                                                                   topicTextColor: Color(red: 0.4, green: 0.3, blue: 0.5),
                                                                   themeName: "Lavender"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Minimal theme - grayscale with subtle colors
                                                       ThemeButton(
                                                           name: "Minimal",
                                                           primaryColor: Color(red: 0.3, green: 0.3, blue: 0.3),
                                                           secondaryColor: Color(red: 0.95, green: 0.95, blue: 0.95),
                                                           accentColor: Color(red: 0.2, green: 0.2, blue: 0.2),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.97, green: 0.97, blue: 0.97),
                                                                   backgroundStyle: .grid,
                                                                   topicFillColor: Color.white,
                                                                   topicBorderColor: Color(red: 0.3, green: 0.3, blue: 0.3),
                                                                   topicTextColor: Color(red: 0.2, green: 0.2, blue: 0.2),
                                                                   themeName: "Minimal"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Dark theme - dark background with vibrant accents
                                                       ThemeButton(
                                                           name: "Dark",
                                                           primaryColor: Color(red: 0.2, green: 0.7, blue: 0.9),
                                                           secondaryColor: Color(red: 0.15, green: 0.15, blue: 0.15),
                                                           accentColor: Color(red: 0.1, green: 0.6, blue: 0.8),
                                                           isDark: true,
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.14),
                                                                   backgroundStyle: .grid,
                                                                   topicFillColor: Color(red: 0.18, green: 0.18, blue: 0.2),
                                                                   topicBorderColor: Color(red: 0.2, green: 0.7, blue: 0.9),
                                                                   topicTextColor: Color.white,
                                                                   themeName: "Dark"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Corporate theme - professional blues for business
                                                       ThemeButton(
                                                           name: "Corporate",
                                                           primaryColor: Color(red: 0.11, green: 0.23, blue: 0.39),
                                                           secondaryColor: Color(red: 0.95, green: 0.95, blue: 0.97),
                                                           accentColor: Color(red: 0.15, green: 0.31, blue: 0.55),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.95, green: 0.96, blue: 0.98),
                                                                   backgroundStyle: .grid,
                                                                   topicFillColor: Color(red: 0.11, green: 0.23, blue: 0.39),
                                                                   topicBorderColor: Color(red: 0.15, green: 0.31, blue: 0.55),
                                                                   topicTextColor: Color.white,
                                                                   themeName: "Corporate"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Tech theme - inspired by modern tech interfaces
                                                       ThemeButton(
                                                           name: "Tech",
                                                           primaryColor: Color(red: 0.0, green: 0.45, blue: 0.78),
                                                           secondaryColor: Color(red: 0.96, green: 0.96, blue: 0.96),
                                                           accentColor: Color(red: 0.0, green: 0.33, blue: 0.57),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.96, green: 0.96, blue: 0.96),
                                                                   backgroundStyle: .dots,
                                                                   topicFillColor: Color(red: 0.0, green: 0.45, blue: 0.78),
                                                                   topicBorderColor: Color(red: 0.0, green: 0.33, blue: 0.57),
                                                                   topicTextColor: Color.white,
                                                                   themeName: "Tech"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Energy theme - vibrant and dynamic
                                                       ThemeButton(
                                                           name: "Energy",
                                                           primaryColor: Color(red: 0.83, green: 0.28, blue: 0.15),
                                                           secondaryColor: Color(red: 0.98, green: 0.94, blue: 0.88),
                                                           accentColor: Color(red: 0.95, green: 0.77, blue: 0.06),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.98, green: 0.94, blue: 0.88),
                                                                   backgroundStyle: .grid,
                                                                   topicFillColor: Color(red: 0.83, green: 0.28, blue: 0.15),
                                                                   topicBorderColor: Color(red: 0.95, green: 0.77, blue: 0.06),
                                                                   topicTextColor: Color.white,
                                                                   themeName: "Energy"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Finance theme - elegant and trustworthy
                                                       ThemeButton(
                                                           name: "Finance",
                                                           primaryColor: Color(red: 0.13, green: 0.28, blue: 0.33),
                                                           secondaryColor: Color(red: 0.93, green: 0.94, blue: 0.94),
                                                           accentColor: Color(red: 0.19, green: 0.59, blue: 0.53),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.93, green: 0.94, blue: 0.94),
                                                                   backgroundStyle: .grid,
                                                                   topicFillColor: Color(red: 0.13, green: 0.28, blue: 0.33),
                                                                   topicBorderColor: Color(red: 0.19, green: 0.59, blue: 0.53),
                                                                   topicTextColor: Color.white,
                                                                   themeName: "Finance"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Innovation theme - modern and forward-thinking
                                                       ThemeButton(
                                                           name: "Innovation",
                                                           primaryColor: Color(red: 0.10, green: 0.74, blue: 0.61),
                                                           secondaryColor: Color(red: 0.95, green: 0.97, blue: 0.97),
                                                           accentColor: Color(red: 0.13, green: 0.55, blue: 0.45),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.95, green: 0.97, blue: 0.97),
                                                                   backgroundStyle: .dots,
                                                                   topicFillColor: Color(red: 0.10, green: 0.74, blue: 0.61),
                                                                   topicBorderColor: Color(red: 0.13, green: 0.55, blue: 0.45),
                                                                   topicTextColor: Color.white,
                                                                   themeName: "Innovation"
                                                               )
                                                           }
                                                       )
                                                       
                                                       // Creative theme - balanced and sophisticated
                                                       ThemeButton(
                                                           name: "Creative",
                                                           primaryColor: Color(red: 0.52, green: 0.27, blue: 0.48),
                                                           secondaryColor: Color(red: 0.96, green: 0.94, blue: 0.98),
                                                           accentColor: Color(red: 0.9, green: 0.56, blue: 0.36),
                                                           onSelect: {
                                                               applyTheme(
                                                                   backgroundColor: Color(red: 0.96, green: 0.94, blue: 0.98),
                                                                   backgroundStyle: .dots,
                                                                   topicFillColor: Color(red: 0.52, green: 0.27, blue: 0.48),
                                                                   topicBorderColor: Color(red: 0.9, green: 0.56, blue: 0.36),
                                                                   topicTextColor: Color.white,
                                                                   themeName: "Creative"
                                                               )
                                                           }
                                                       )
                                                   }
                                                   .padding(.horizontal)
                                               }
                                           }
                                       }
                                       
                                       Spacer(minLength: 20)
                                   }
                               )
                               .shadow(color: .black.opacity(0.1), radius: 2, x: -1, y: 0)
                       }
                   }
               }
           }
           .gesture(
               SimultaneousGesture(
                   MagnificationGesture()
                       .onChanged { value in
                           // Add dampening factor to reduce zoom sensitivity
                           let dampening: CGFloat = 0.5
                           let zoomDelta = (value - 1) * dampening
                           let newScale = scale * (1 + zoomDelta)
                           scale = min(maxScale, max(minScale, newScale))
                       },
                   DragGesture(minimumDistance: 0)
                       .onChanged { value in
                           let currentPosition = value.location
                           
                           if let lastPosition = lastDragPosition {
                               let delta = CGPoint(
                                   x: currentPosition.x - lastPosition.x,
                                   y: currentPosition.y - lastPosition.y
                               )
                               offset = CGPoint(
                                   x: offset.x + delta.x,
                                   y: offset.y + delta.y
                               )
                           }
                           
                           lastDragPosition = currentPosition
                       }
                       .onEnded { _ in
                           lastDragPosition = nil
                       }
               )
           )
           .onChange(of: viewModel.topics) { oldValue, newValue in
               topicsBounds = calculateTopicsBounds()
           }
           .onChange(of: viewModel.selectedTopicId) { oldValue, newValue in
               // Update the touch bar when selection changes
               touchBarDelegate?.updateTouchBar()
           }
           .onChange(of: isRelationshipMode) { oldValue, newValue in
               // Update the touch bar when relationship mode changes
               touchBarDelegate?.updateTouchBar()
           }
           .onAppear {
               KeyboardMonitor.shared.keyHandler = { event in
                   if let window = NSApp.keyWindow {
                       let mouseLocation = NSEvent.mouseLocation
                       let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                       if let view = window.contentView {
                           let viewPoint = view.convert(windowPoint, from: nil)
                           cursorPosition = viewPoint
                           let canvasPosition = screenToCanvasPosition(cursorPosition)
                           viewModel.handleKeyPress(event, at: canvasPosition)
                       }
                   }
               }
               KeyboardMonitor.shared.startMonitoring()
               
               // Initialize Touch Bar Delegate
               touchBarDelegate = InfiniteCanvasTouchBarDelegate(viewModel: viewModel, isRelationshipMode: $isRelationshipMode)
               
               // Add observer for undo command (Cmd+Z)
               NotificationCenter.default.addObserver(forName: NSNotification.Name("UndoRequested"), object: nil, queue: .main) { _ in
                   viewModel.undo()
               }
               
               // Add observer for redo command (Cmd+Shift+Z)
               NotificationCenter.default.addObserver(forName: NSNotification.Name("RedoRequested"), object: nil, queue: .main) { _ in
                   viewModel.redo()
               }
               
               // Set up touch bar delegate
               touchBarDelegate = InfiniteCanvasTouchBarDelegate(
                   viewModel: viewModel,
                   isRelationshipMode: $isRelationshipMode
               )
               
               // Register for export notification
               NotificationCenter.default.addObserver(forName: NSNotification.Name("ExportMindMap"), object: nil, queue: .main) { _ in
                   self.handleExportRequest()
               }
               
               NotificationCenter.default.addObserver(forName: NSNotification.Name("PrepareCanvasForExport"), object: nil, queue: .main) { _ in
                   self.prepareCanvasForExport()
               }
           }
           .onDisappear {
               KeyboardMonitor.shared.stopMonitoring()
               
               // Remove observers
               NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UndoRequested"), object: nil)
               NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RedoRequested"), object: nil)
           }
       }
       .ignoresSafeArea()
   }
   
   // MARK: - Export Functionality
   
   private func handleExportRequest() {
       // Notify that we want to export the mind map
       NotificationCenter.default.post(name: NSNotification.Name("RequestTopicsForExport"), object: nil)
   }
   
   private func prepareCanvasForExport() {
       // Instead of directly using the NSView reference which doesn't capture the canvas content,
       // we'll pass all the necessary data to render a complete representation of the mind map
       guard let mainWindow = NSApp.mainWindow else {
           showExportError(message: "Could not access the application window")
           return
       }
       
       // Pass all the necessary data to render a complete representation
       ExportManager.shared.exportCanvas(
           mainWindow: mainWindow,
           canvasFrame: mainWindow.contentView?.frame ?? .zero,
           topics: viewModel.topics,
           scale: scale,
           offset: offset,
           backgroundColor: backgroundColor,
           backgroundStyle: backgroundStyle,
           selectedTopicId: viewModel.selectedTopicId
       )
   }
   
   private func showExportError(message: String) {
       DispatchQueue.main.async {
           let alert = NSAlert()
           alert.messageText = "Export Failed"
           alert.informativeText = message
           alert.alertStyle = .critical
           alert.addButton(withTitle: "OK")
           alert.runModal()
       }
   }
}


// Add this extension in the InfiniteCanvas struct - just before the body property
// MARK: - Theme Management
extension InfiniteCanvas {
   func applyTheme(
       backgroundColor: Color, 
       backgroundStyle: BackgroundStyle, 
       topicFillColor: Color, 
       topicBorderColor: Color,
       topicTextColor: Color,
       themeName: String = ""
   ) {
       // Update canvas background
       self.backgroundColor = backgroundColor
       self.backgroundStyle = backgroundStyle
       
       // Store theme settings for new topics
       self.currentTheme = ThemeSettings(
           name: themeName,
           backgroundColor: backgroundColor,
           backgroundStyle: backgroundStyle,
           topicFillColor: topicFillColor,
           topicBorderColor: topicBorderColor,
           topicTextColor: topicTextColor
       )
       
       // Update all topics with the theme colors
       for topicId in viewModel.getAllTopicIds() {
           // Update fill color
           viewModel.updateTopicBackgroundColor(topicId, color: topicFillColor)
           
           // Update border color
           viewModel.updateTopicBorderColor(topicId, color: topicBorderColor)
           
           // Update text color
           viewModel.updateTopicForegroundColor(topicId, color: topicTextColor)
       }
       
       // Update the theme in the ViewModel
       viewModel.setCurrentTheme(
           topicFillColor: topicFillColor,
           topicBorderColor: topicBorderColor,
           topicTextColor: topicTextColor
       )
   }
}

#Preview {
   InfiniteCanvas()
} 
