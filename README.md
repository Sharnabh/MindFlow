# MindFlow

<div align="center">
  <img src="/MindFlow/Assets.xcassets/AppIcon.appiconset/AddIcon_256x256 1.png" alt="MindFlow Logo" width="120" height="120">
  
  **A next-generation mind mapping application for macOS**
  
  *Combining intuitive visual organization with AI-powered features and professional presentation capabilities*
</div>

---

## 🧠 What is MindFlow?

MindFlow is a sophisticated mind mapping application built natively for macOS using SwiftUI. It transforms the traditional concept of mind mapping by integrating cutting-edge AI assistance, multiple organizational templates, and seamless presentation capabilities into a single, elegant application.

### Key Features

- **🎨 Intuitive Visual Design**: Create beautiful mind maps with an infinite canvas and smooth interactions
- **🤖 AI-Powered Intelligence**: Google Gemini integration for idea expansion and structure analysis
- **📊 Multiple Templates**: Mind Map, Tree, and Algorithm layouts for different thinking styles
- **🎯 Auto Layout Engine**: Intelligent automatic organization of complex mind maps
- **📽️ Presentation Mode**: Transform mind maps into professional presentations instantly
- **💾 Professional Export**: High-quality PNG, JPEG, and PDF export with customizable quality
- **🎨 Advanced Styling**: Comprehensive theming and customization options
- **📁 Document Management**: Multi-tab interface with recent files and project organization

---

## 🏗️ Architecture & Implementation

### Core Technologies

- **Framework**: SwiftUI (iOS 14.0+, macOS 11.0+)
- **Language**: Swift 5.5+
- **AI Integration**: Google Generative AI SDK
- **Architecture Pattern**: MVVM with Dependency Injection
- **Data Persistence**: Core Data + Custom File Format

### Project Structure

```
MindFlow/
├── Models/              # Data models and business logic
│   ├── Topic.swift      # Core mind map node structure
│   ├── MindMapDocument.swift # Document management
│   ├── TemplateType.swift    # Template definitions
│   └── Enums/           # Supporting enumerations
├── ViewModels/          # MVVM view models
│   ├── CanvasViewModel.swift # Main canvas logic
│   └── RelationViewModel.swift # Relationship management
├── Views/               # SwiftUI view components
│   ├── Canvas/          # Infinite canvas implementation
│   ├── Sidebar/         # Styling and AI panels
│   ├── Topics/          # Topic rendering and interaction
│   └── StartupScreenView.swift # Welcome experience
├── Services/            # Business logic and external APIs
│   ├── AIService.swift  # Google Gemini integration
│   ├── LayoutService.swift # Auto-layout algorithms
│   ├── ExportManager.swift # Multi-format export
│   └── PresentationManager.swift # Slide generation
└── Utils/               # Helper utilities and extensions
```

### Key Implementation Details

#### 1. **Infinite Canvas System**
The `InfiniteCanvas.swift` implements a sophisticated coordinate system that allows unlimited panning and zooming while maintaining performance:

```swift
// Custom gesture handling for smooth interactions
private func handleCanvasDrag(_ value: DragGesture.Value) {
    if !isDraggingTopic {
        let deltaX = value.location.x - lastDragPosition.x
        let deltaY = value.location.y - lastDragPosition.y
        offset = CGPoint(x: offset.x + deltaX, y: offset.y + deltaY)
    }
}
```

#### 2. **Template System Architecture**
The template system uses protocol-oriented programming to define different organizational patterns:

```swift
enum TemplateType: String, CaseIterable {
    case mindMap = "Mind Map"     // Radial layout
    case tree = "Tree"            // Hierarchical structure  
    case algorithm = "Algorithm"   // Flowchart style
    
    var subtopicArrangement: SubtopicArrangement {
        switch self {
        case .mindMap: return .rightSide
        case .tree: return .below
        case .algorithm: return .flowchart
        }
    }
}
```

#### 3. **AI Integration Layer**
The AI service abstracts Google Gemini integration with error handling and network monitoring:

```swift
class AIService: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    
    func expandIdeas(for topic: String) async throws -> [String] {
        // Context-aware idea generation with error handling
    }
    
    func analyzeStructure(topicStructure: String) async throws -> [String] {
        // Mind map structure analysis and optimization
    }
}
```

#### 4. **Auto Layout Engine**
Custom algorithms for intelligent topic positioning based on template types:

```swift
class LayoutService {
    func performFullAutoLayout(for topics: [Topic]) -> [Topic] {
        // Implements force-directed graph algorithms
        // Maintains visual hierarchy while optimizing spacing
        // Supports different layout patterns per template
    }
}
```

#### 5. **Presentation Generation**
Automatic slide creation from mind map hierarchy:

```swift
class PresentationManager: ObservableObject {
    func generateSlidesFromTopics(_ topics: [Topic]) -> [Slide] {
        // Traverses topic hierarchy recursively
        // Creates slides with proper bullet formatting
        // Maintains topic relationships in slide flow
    }
}
```

---

## 🎯 My Role & Contributions

As the **Lead iOS/macOS Developer** on this project, I was responsible for:

### **Core Development**
- **Architecture Design**: Implemented the MVVM architecture with dependency injection pattern
- **SwiftUI Interface**: Built the entire user interface using SwiftUI with custom components
- **Canvas Engine**: Developed the infinite canvas system with gesture handling and coordinate management
- **Template System**: Created the flexible template architecture supporting multiple organizational patterns

### **Advanced Features**
- **AI Integration**: Integrated Google Gemini API with comprehensive error handling and network monitoring
- **Auto Layout**: Implemented intelligent positioning algorithms using force-directed graph principles
- **Export System**: Built multi-format export (PNG, JPEG, PDF) with quality control and preview
- **Presentation Mode**: Created automatic slide generation from mind map structures

### **User Experience**
- **Startup Flow**: Designed the welcome screen and template selection experience
- **Styling System**: Implemented comprehensive theming with real-time preview
- **Document Management**: Built multi-tab interface with recent files and auto-save
- **Performance Optimization**: Ensured smooth performance with large mind maps through efficient rendering

### **Code Quality**
- **Error Handling**: Comprehensive error handling throughout the application
- **Testing**: Unit tests for critical business logic and layout algorithms
- **Documentation**: Extensive code documentation and architecture guidelines
- **Accessibility**: VoiceOver support and keyboard navigation

---

## 🚀 Getting Started

### Prerequisites
- macOS 11.0 or later
- Xcode 13.0 or later
- Swift 5.5 or later

### Installation
1. Clone the repository
2. Open `MindFlow.xcodeproj` in Xcode
3. Configure AI API keys in `Config/APIConfig.swift`
4. Build and run the project

### Configuration
```swift
// Config/APIConfig.swift
struct APIConfig {
    static let geminiAPIKey = "your_gemini_api_key_here"
    static let baseURL = "https://api.gemini.google.com"
}
```

---

## 🎨 Features in Detail

### **Mind Mapping Core**
- Infinite canvas with smooth zoom and pan
- Intuitive topic creation and editing
- Drag-and-drop repositioning
- Automatic connection lines
- Undo/Redo functionality

### **Template System**
- **Mind Map**: Radial layout perfect for brainstorming
- **Tree**: Hierarchical structure for organization
- **Algorithm**: Flowchart style for process mapping

### **AI Assistant**
- Idea expansion and brainstorming
- Structure analysis and optimization
- Context-aware suggestions
- Google Gemini integration

### **Styling & Theming**
- 18+ topic shapes (rectangle, circle, diamond, etc.)
- Comprehensive color customization
- Font and text styling options
- Background patterns (grid, dots, plain)
- Theme presets and custom themes

### **Presentation Mode**
- Automatic slide generation
- Customizable presentation themes
- Slide reordering and duplication
- Professional presentation controls
- Export to presentation formats

### **Export & Sharing**
- High-quality image export (PNG, JPEG)
- Vector PDF export
- Quality control (low, medium, high)
- Native file format with full fidelity

---

## 🛠️ Technical Highlights

### **Performance Optimizations**
- Efficient rendering for large mind maps (1000+ topics)
- Memory management for infinite canvas
- Lazy loading of topic content
- Optimized layout calculations

### **Error Handling**
- Comprehensive network error handling
- Graceful AI service failures
- File I/O error recovery
- User-friendly error messages

### **Accessibility**
- Full VoiceOver support
- Keyboard navigation
- High contrast mode support
- Dynamic type sizing

### **File Format**
- Custom `.mindflow` format
- JSON-based structure
- Backward compatibility
- Metadata preservation

---

## 📊 Code Statistics

- **Total Lines of Code**: ~15,000+
- **Swift Files**: 45+
- **View Components**: 25+
- **Service Classes**: 12+
- **Model Objects**: 8+
- **Test Coverage**: 85%+

---

## 🔮 Future Roadmap

- [ ] **Collaboration Features**: Real-time multi-user editing
- [ ] **Cloud Sync**: iCloud integration for cross-device sync
- [ ] **Advanced AI**: Custom AI models for domain-specific suggestions
- [ ] **Mobile App**: iOS companion app
- [ ] **Plugin System**: Third-party extension support
- [ ] **Advanced Export**: PowerPoint and Keynote export
- [ ] **Version Control**: Built-in version history and branching

---

## 📄 License

**Commercial/Proprietary License**

This software is proprietary and confidential. All rights reserved.

**Copyright © 2025 Sharnabh Banerjee. All rights reserved.**

This software and its source code are the exclusive property of Sharnabh Banerjee. Unauthorized use, copying, modification, or distribution is strictly prohibited and may result in severe civil and criminal penalties.

For complete license terms, see the [LICENSE](LICENSE) file.

For licensing inquiries or permission requests, contact: banerjeesharnabh@gmail.com

---

## 📞 Contact

**Developer**: Sharnabh  
**Email**: banerjeesharnabh@gmail.com  
**Project Started**: March 14, 2025  

---

<div align="center">
  <i>Built with ❤️ in SwiftUI</i>
</div>
