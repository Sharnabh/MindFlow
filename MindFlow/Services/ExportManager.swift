import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case pdf = "PDF"
    
    var id: String { self.rawValue }
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .pdf: return "pdf"
        }
    }
    
    var fileType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .pdf: return .pdf
        }
    }
}

enum ExportQuality: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var id: String { self.rawValue }
    
    var compressionFactor: CGFloat {
        switch self {
        case .low: return 0.3
        case .medium: return 0.7
        case .high: return 1.0
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .low: return 1.0
        case .medium: return 2.0
        case .high: return 3.0
        }
    }
}

class ExportManager {
    static let shared = ExportManager()
    
    private init() {
        // Register for the export notification
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(handleExportRequest),
                                              name: NSNotification.Name("RequestTopicsForExport"), 
                                              object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleExportRequest() {
        // Request the canvas view model to provide data for export
        NotificationCenter.default.post(name: NSNotification.Name("PrepareCanvasForExport"), object: nil)
    }
    
    // Executes when the InfiniteCanvas calls back with its prepared view
    func exportCanvas(mainWindow: NSWindow, canvasFrame: NSRect, topics: [Topic], scale: CGFloat, offset: CGPoint, backgroundColor: Color, backgroundStyle: InfiniteCanvas.BackgroundStyle, selectedTopicId: UUID?) {
        // First show the export dialog window
        let exportDialog = ExportDialogWindowController { [weak self] result in
            guard let self = self, let (format, quality) = result else { return }
            
            // Now show the save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [format.fileType]
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false
            savePanel.title = "Export Mind Map"
            savePanel.message = "Choose a location to save your exported mind map"
            savePanel.nameFieldLabel = "Export As:"
            savePanel.nameFieldStringValue = "MindMap.\(format.fileExtension)"
            
            savePanel.begin { [weak self] result in
                guard let self = self, result == .OK, let url = savePanel.url else { return }
                
                // Create a capture of the entire mind map
                self.exportMindMap(
                    topics: topics,
                    scale: scale,
                    offset: offset,
                    backgroundColor: backgroundColor,
                    backgroundStyle: backgroundStyle,
                    to: url,
                    format: format,
                    quality: quality,
                    selectedTopicId: selectedTopicId
                )
            }
        }
        
        exportDialog.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func exportMindMap(topics: [Topic], scale: CGFloat, offset: CGPoint, backgroundColor: Color, backgroundStyle: InfiniteCanvas.BackgroundStyle, to url: URL, format: ExportFormat, quality: ExportQuality, selectedTopicId: UUID?) {
        // Calculate bounds containing all topics with padding
        let topicsBounds = calculateTopicsBounds(for: topics)
        
        // Create sized image for the entire map with proper padding
        let padding: CGFloat = 100
        let width = topicsBounds.width + (padding * 2)
        let height = topicsBounds.height + (padding * 2)
        
        // Create an NSImage to draw into
        let exportScale = quality.scale
        let imageSize = NSSize(width: width * exportScale, height: height * exportScale)
        
        switch format {
        case .png, .jpeg:
            guard let image = renderToImage(
                size: imageSize,
                topics: topics,
                topicsBounds: topicsBounds,
                backgroundColor: backgroundColor,
                backgroundStyle: backgroundStyle,
                exportScale: exportScale,
                selectedTopicId: selectedTopicId
            ) else {
                showExportError(message: "Failed to render mind map image")
                return
            }
            
            // Convert to data based on format
            guard let imageData = imageToData(image: image, format: format, quality: quality) else {
                showExportError(message: "Failed to create image data")
                return
            }
            
            // Write to file
            do {
                try imageData.write(to: url)
                showExportSuccess()
            } catch {
                showExportError(message: "Failed to save image: \(error.localizedDescription)")
            }
            
        case .pdf:
            // Create PDF data
            guard let pdfData = renderToPDF(
                size: CGSize(width: width, height: height),
                topics: topics,
                topicsBounds: topicsBounds,
                backgroundColor: backgroundColor,
                backgroundStyle: backgroundStyle,
                selectedTopicId: selectedTopicId
            ) else {
                showExportError(message: "Failed to create PDF data")
                return
            }
            
            // Write to file
            do {
                try pdfData.write(to: url)
                showExportSuccess()
            } catch {
                showExportError(message: "Failed to save PDF: \(error.localizedDescription)")
            }
        }
    }
    
    private func calculateTopicsBounds(for topics: [Topic]) -> CGRect {
        guard !topics.isEmpty else { return .zero }
        
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
        for topic in topics {
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
    
    private func renderToImage(size: NSSize, topics: [Topic], topicsBounds: CGRect, backgroundColor: Color, backgroundStyle: InfiniteCanvas.BackgroundStyle, exportScale: CGFloat, selectedTopicId: UUID?) -> NSImage? {
        // Create a new image with the calculated size
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Fill the background
        let nsBackgroundColor = NSColor(backgroundColor)
        nsBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw grid if needed
        let nsContext = NSGraphicsContext.current?.cgContext
        if let context = nsContext, backgroundStyle != .none {
            drawBackground(
                in: context,
                size: size,
                style: backgroundStyle,
                topicsBounds: topicsBounds,
                exportScale: exportScale
            )
        }
        
        // Draw all topics and connections
        if let context = nsContext {
            drawTopics(
                topics: topics,
                in: context,
                topicsBounds: topicsBounds,
                exportScale: exportScale,
                selectedTopicId: selectedTopicId
            )
        }
        
        image.unlockFocus()
        return image
    }
    
    private func drawBackground(in context: CGContext, size: NSSize, style: InfiniteCanvas.BackgroundStyle, topicsBounds: CGRect, exportScale: CGFloat) {
        // Apply export scale to context
        context.saveGState()
        context.scaleBy(x: exportScale, y: exportScale)
        
        let scaledSize = CGSize(width: size.width / exportScale, height: size.height / exportScale)
        let gridSize: CGFloat = 50
        
        switch style {
        case .grid:
            // Calculate grid line ranges to cover the entire image
            let startX: CGFloat = 0
            let endX = scaledSize.width
            let startY: CGFloat = 0
            let endY = scaledSize.height
            
            // Set grid color
            context.setStrokeColor(CGColor(gray: 0.7, alpha: 0.2))
            context.setLineWidth(0.5)
            
            // Draw vertical grid lines
            for x in stride(from: startX, through: endX, by: gridSize) {
                context.move(to: CGPoint(x: x, y: startY))
                context.addLine(to: CGPoint(x: x, y: endY))
                context.strokePath()
            }
            
            // Draw horizontal grid lines
            for y in stride(from: startY, through: endY, by: gridSize) {
                context.move(to: CGPoint(x: startX, y: y))
                context.addLine(to: CGPoint(x: endX, y: y))
                context.strokePath()
            }
            
        case .dots:
            // Calculate dot positions
            let dotSize: CGFloat = 2.0
            let startX: CGFloat = 0
            let endX = scaledSize.width
            let startY: CGFloat = 0
            let endY = scaledSize.height
            
            // Set dot color
            context.setFillColor(CGColor(gray: 0.7, alpha: 0.3))
            
            // Draw dots at grid intersections
            for x in stride(from: startX, through: endX, by: gridSize) {
                for y in stride(from: startY, through: endY, by: gridSize) {
                    let dotRect = CGRect(
                        x: x - (dotSize / 2),
                        y: y - (dotSize / 2),
                        width: dotSize,
                        height: dotSize
                    )
                    context.fillEllipse(in: dotRect)
                }
            }
            
        case .none:
            break
        }
        
        context.restoreGState()
    }
    
    private func drawTopics(topics: [Topic], in context: CGContext, topicsBounds: CGRect, exportScale: CGFloat, selectedTopicId: UUID?) {
        // Apply export scale to context
        context.saveGState()
        context.scaleBy(x: exportScale, y: exportScale)
        
        // Adjust coordinates to center the content
        let padding: CGFloat = 100
        
        // Calculate if any topic has curved branch style
        let hasCurvedStyle = topics.contains { hasCurved(topic: $0) }
        
        // First, draw all topic-subtopic connection lines
        for topic in topics {
            drawTopicConnections(topic, in: context, topicsBounds: topicsBounds, padding: padding, useCurvedStyle: hasCurvedStyle)
        }
        
        // Next, draw all relationship lines between topics
        drawRelationships(for: topics, in: context, topicsBounds: topicsBounds, padding: padding)
        
        // Finally, draw all topics and their content (shapes, borders, text)
        for topic in topics {
            drawTopicShapes(
                topic,
                in: context,
                topicsBounds: topicsBounds,
                padding: padding,
                useCurvedStyle: hasCurvedStyle,
                isSelected: topic.id == selectedTopicId
            )
        }
        
        context.restoreGState()
    }
    
    private func hasCurved(topic: Topic) -> Bool {
        if topic.branchStyle == .curved {
            return true
        }
        
        for subtopic in topic.subtopics {
            if hasCurved(topic: subtopic) {
                return true
            }
        }
        
        return false
    }
    
    private func drawTopicConnections(_ topic: Topic, in context: CGContext, topicsBounds: CGRect, padding: CGFloat, useCurvedStyle: Bool) {
        // Get the adjusted position of the topic
        let position = CGPoint(
            x: topic.position.x - topicsBounds.minX + padding,
            y: topic.position.y - topicsBounds.minY + padding
        )
        
        // Draw connections to subtopics
        for subtopic in topic.subtopics {
            let subtopicPosition = CGPoint(
                x: subtopic.position.x - topicsBounds.minX + padding,
                y: subtopic.position.y - topicsBounds.minY + padding
            )
            
            // Set connection color using topic's borderColor
            let connectionColor = NSColor(topic.borderColor).cgColor
            context.setStrokeColor(connectionColor)
            context.setLineWidth(max(1.0, topic.borderWidth.rawValue * 0.5))
            
            // Draw connection line based on branch style or global curved setting
            if useCurvedStyle || topic.branchStyle == .curved {
                // Draw curved connection
                let dx = subtopicPosition.x - position.x
                let _ = subtopicPosition.y - position.y
                let midX = position.x + dx * 0.5
                
                context.move(to: position)
                context.addCurve(
                    to: subtopicPosition,
                    control1: CGPoint(x: midX, y: position.y),
                    control2: CGPoint(x: midX, y: subtopicPosition.y)
                )
                context.strokePath()
            } else {
                // Draw straight connection
                context.move(to: position)
                context.addLine(to: subtopicPosition)
                context.strokePath()
            }
            
            // Recursively draw connections for this subtopic
            drawTopicConnections(subtopic, in: context, topicsBounds: topicsBounds, padding: padding, useCurvedStyle: useCurvedStyle)
        }
    }
    
    private func drawTopicShapes(_ topic: Topic, in context: CGContext, topicsBounds: CGRect, padding: CGFloat, useCurvedStyle: Bool, isSelected: Bool = false) {
        // Get the adjusted position of the topic
        let position = CGPoint(
            x: topic.position.x - topicsBounds.minX + padding,
            y: topic.position.y - topicsBounds.minY + padding
        )
        
        // Calculate topic dimensions
        let width = calculateTopicWidth(topic)
        let height = calculateTopicHeight(topic)
        
        // Create the topic rectangle
        let rect = CGRect(x: position.x - width/2, y: position.y - height/2, width: width, height: height)
        
        // Set background color and draw shape
        context.setFillColor(NSColor(topic.backgroundColor).withAlphaComponent(CGFloat(topic.backgroundOpacity)).cgColor)
        drawShape(topic.shape, in: rect, context: context)
        
        // Set border color for selected vs non-selected state
        if isSelected {
            context.setStrokeColor(NSColor.white.cgColor) // Use white for selected topics
        } else {
            context.setStrokeColor(NSColor(topic.borderColor).withAlphaComponent(CGFloat(topic.borderOpacity)).cgColor)
        }
        
        context.setLineWidth(topic.borderWidth.rawValue)
        drawShapeBorder(topic.shape, in: rect, context: context)
        
        // Draw text
        drawText(
            topic.name,
            in: rect,
            with: NSColor(topic.foregroundColor).withAlphaComponent(CGFloat(topic.foregroundOpacity)).cgColor,
            fontSize: topic.fontSize,
            fontWeight: topic.fontWeight,
            textStyles: topic.textStyles,
            textCase: topic.textCase,
            alignment: topic.textAlignment,
            context: context
        )
        
        // Recursively draw subtopics
        for subtopic in topic.subtopics {
            drawTopicShapes(
                subtopic,
                in: context,
                topicsBounds: topicsBounds,
                padding: padding,
                useCurvedStyle: useCurvedStyle,
                isSelected: subtopic.id == topic.id // Pass selection state
            )
        }
    }
    
    private func calculateTopicWidth(_ topic: Topic) -> CGFloat {
        let lines = topic.name.components(separatedBy: "\n")
        let maxLineLength = lines.map { $0.count }.max() ?? 0
        return max(120, CGFloat(maxLineLength * 8)) + 20 // Slightly smaller padding
    }
    
    private func calculateTopicHeight(_ topic: Topic) -> CGFloat {
        let lineCount = topic.name.components(separatedBy: "\n").count
        // Use a fixed height for single-line topics, and add smaller increments for multi-line
        return lineCount <= 1 ? 40 : (40 + CGFloat((lineCount - 1) * 18))
    }
    
    private func drawShape(_ shape: Topic.Shape, in rect: CGRect, context: CGContext) {
        switch shape {
        case .rectangle:
            context.fill(rect)
        case .roundedRectangle:
            let path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            context.addPath(path)
            context.fillPath()
        case .circle:
            context.fillEllipse(in: rect)
        case .roundedSquare:
            let path = CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)
            context.addPath(path)
            context.fillPath()
        case .line:
            let lineRect = CGRect(
                x: rect.minX,
                y: rect.midY - 1,
                width: rect.width,
                height: 2
            )
            context.fill(lineRect)
        // Handle other shapes as basic rectangle for now
        default:
            context.fill(rect)
        }
    }
    
    private func drawShapeBorder(_ shape: Topic.Shape, in rect: CGRect, context: CGContext) {
        switch shape {
        case .rectangle:
            context.stroke(rect)
        case .roundedRectangle:
            let path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            context.addPath(path)
            context.strokePath()
        case .circle:
            context.strokeEllipse(in: rect)
        case .roundedSquare:
            let path = CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)
            context.addPath(path)
            context.strokePath()
        case .line:
            let lineRect = CGRect(
                x: rect.minX,
                y: rect.midY - 1,
                width: rect.width,
                height: 2
            )
            context.stroke(lineRect)
        // Handle other shapes as basic rectangle for now
        default:
            context.stroke(rect)
        }
    }
    
    private func drawRelationships(for topics: [Topic], in context: CGContext, topicsBounds: CGRect, padding: CGFloat) {
        // First create a map of topic IDs to their positions and sizes for quick lookup
        var topicPositions: [UUID: CGPoint] = [:]
        var topicRects: [UUID: CGRect] = [:]
        
        // Recursively collect positions for all topics and subtopics
        func collectPositions(for topic: Topic) {
            // Adjust position by topicsBounds and padding
            let position = CGPoint(
                x: topic.position.x - topicsBounds.minX + padding,
                y: topic.position.y - topicsBounds.minY + padding
            )
            
            // Store the position
            topicPositions[topic.id] = position
            
            // Calculate and store the rectangle
            let width = calculateTopicWidth(topic)
            let height = calculateTopicHeight(topic)
            topicRects[topic.id] = CGRect(
                x: position.x - width/2,
                y: position.y - height/2,
                width: width,
                height: height
            )
            
            // Process subtopics
            for subtopic in topic.subtopics {
                collectPositions(for: subtopic)
            }
        }
        
        // Collect all positions first
        for topic in topics {
            collectPositions(for: topic)
        }
        
        // Helper function to find edge points on a rectangle for a line from center to another point
        func findEdgePoint(from rect: CGRect, centerPoint: CGPoint, targetPoint: CGPoint) -> CGPoint {
            let rectCenter = CGPoint(x: rect.midX, y: rect.midY)
            
            // Calculate the direction vector from center to target
            let dx = targetPoint.x - rectCenter.x
            let dy = targetPoint.y - rectCenter.y
            
            // Normalize to get unit vector
            let length = sqrt(dx*dx + dy*dy)
            let unitDx = dx / length
            let unitDy = dy / length
            
            // Calculate intersection with rectangle edges
            var tMin = Double.infinity
            var intersection = rectCenter
            
            // Test intersection with each edge
            // Top edge
            if unitDy < 0 {
                let t = (rect.minY - rectCenter.y) / unitDy
                let x = rectCenter.x + t * unitDx
                if x >= rect.minX && x <= rect.maxX && t < tMin {
                    tMin = t
                    intersection = CGPoint(x: x, y: rect.minY)
                }
            }
            
            // Bottom edge
            if unitDy > 0 {
                let t = (rect.maxY - rectCenter.y) / unitDy
                let x = rectCenter.x + t * unitDx
                if x >= rect.minX && x <= rect.maxX && t < tMin {
                    tMin = t
                    intersection = CGPoint(x: x, y: rect.maxY)
                }
            }
            
            // Left edge
            if unitDx < 0 {
                let t = (rect.minX - rectCenter.x) / unitDx
                let y = rectCenter.y + t * unitDy
                if y >= rect.minY && y <= rect.maxY && t < tMin {
                    tMin = t
                    intersection = CGPoint(x: rect.minX, y: y)
                }
            }
            
            // Right edge
            if unitDx > 0 {
                let t = (rect.maxX - rectCenter.x) / unitDx
                let y = rectCenter.y + t * unitDy
                if y >= rect.minY && y <= rect.maxY && t < tMin {
                    tMin = t
                    intersection = CGPoint(x: rect.maxX, y: y)
                }
            }
            
            return intersection
        }
        
        // Now draw relationship lines
        func drawRelations(for topic: Topic) {
            // Draw relations for this topic
            for relation in topic.relations {
                guard let fromRect = topicRects[topic.id],
                      let toRect = topicRects[relation.id],
                      let fromPos = topicPositions[topic.id],
                      let toPos = topicPositions[relation.id] else {
                    continue
                }
                
                // Find edge points for the relationship line
                let fromEdge = findEdgePoint(from: fromRect, centerPoint: fromPos, targetPoint: toPos)
                let toEdge = findEdgePoint(from: toRect, centerPoint: toPos, targetPoint: fromPos)
                
                // Draw relationship line with purple color
                context.setStrokeColor(NSColor.purple.withAlphaComponent(0.8).cgColor)
                context.setLineWidth(2.0)
                
                // Draw a dashed line for relationships
                context.setLineDash(phase: 0, lengths: [6, 3])
                
                // Draw line from edge to edge instead of center to center
                context.move(to: fromEdge)
                context.addLine(to: toEdge)
                context.strokePath()
                
                // Reset line dash pattern
                context.setLineDash(phase: 0, lengths: [])
            }
            
            // Process subtopics
            for subtopic in topic.subtopics {
                drawRelations(for: subtopic)
            }
        }
        
        // Draw relations for all topics
        for topic in topics {
            drawRelations(for: topic)
        }
    }
    
    private func drawText(_ text: String, in rect: CGRect, with color: CGColor, fontSize: CGFloat, fontWeight: Font.Weight, textStyles: Set<TextStyle>, textCase: TextCase, alignment: TextAlignment, context: CGContext) {
        // Process text case
        let processedText: String
        switch textCase {
        case .uppercase:
            processedText = text.uppercased()
        case .lowercase:
            processedText = text.lowercased()
        case .capitalize:
            processedText = text.capitalized
        case .none:
            processedText = text
        }
        
        // Create font
        let fontWeightValue: NSFont.Weight
        switch fontWeight {
        case .bold: fontWeightValue = .bold
        case .semibold: fontWeightValue = .semibold
        case .medium: fontWeightValue = .medium
        case .regular: fontWeightValue = .regular
        case .light: fontWeightValue = .light
        case .thin: fontWeightValue = .thin
        case .ultraLight: fontWeightValue = .ultraLight
        case .heavy: fontWeightValue = .heavy
        default: fontWeightValue = .regular
        }
        
        let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeightValue)
        
        // Create paragraph style for alignment
        let paragraphStyle = NSMutableParagraphStyle()
        switch alignment {
        case .left:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .right:
            paragraphStyle.alignment = .right
        }
        
        // Create attributes
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: color) ?? .textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // Apply text styles
        if textStyles.contains(.underline) {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        
        if textStyles.contains(.strikethrough) {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        
        // Create text frame with padding
        let textRect = rect.insetBy(dx: 10, dy: 10)
        
        // Create attributed string
        let attributedString = NSAttributedString(string: processedText, attributes: attributes)
        
        // Save current graphics state
        context.saveGState()
        
        // Set clipping to ensure text stays within bounds
        let path = CGPath(rect: textRect, transform: nil)
        context.addPath(path)
        context.clip()
        
        // Draw the attributed string in the rect directly - this works better for both PDF and PNG
        attributedString.draw(in: textRect)
        
        // Restore graphics state
        context.restoreGState()
    }
    
    private func renderToPDF(size: CGSize, topics: [Topic], topicsBounds: CGRect, backgroundColor: Color, backgroundStyle: InfiniteCanvas.BackgroundStyle, selectedTopicId: UUID?) -> Data? {
        // Create a PDF context to draw into
        let pdfData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: size)
        
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!,
                                        mediaBox: &mediaBox,
                                        nil) else {
            return nil
        }
        
        // Start the PDF page
        pdfContext.beginPDFPage(nil)
        
        // Set up the graphics context
        let graphicsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        
        // Draw the background
        NSColor(backgroundColor).set()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw grid if needed
        if backgroundStyle != .none {
            drawBackground(
                in: pdfContext,
                size: NSSize(width: size.width, height: size.height),
                style: backgroundStyle,
                topicsBounds: topicsBounds,
                exportScale: 1.0
            )
        }
        
        // Draw all topics and connections
        drawTopics(
            topics: topics,
            in: pdfContext,
            topicsBounds: topicsBounds,
            exportScale: 1.0,
            selectedTopicId: selectedTopicId
        )
        
        // End the PDF context
        NSGraphicsContext.restoreGraphicsState()
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        return pdfData as Data
    }
    
    private func imageToData(image: NSImage, format: ExportFormat, quality: ExportQuality) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        
        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality.compressionFactor])
        case .pdf:
            // This should not happen as PDF uses a different export path
            return nil
        }
    }
    
    private func showExportSuccess() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Export Successful"
            alert.informativeText = "Your mind map has been exported successfully."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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

// Add new classes for export dialog
struct ExportDialogView: View {
    @State private var selectedFormat: ExportFormat = .png
    @State private var selectedQuality: ExportQuality = .high
    @Binding var isPresented: Bool
    let onExport: (ExportFormat, ExportQuality) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Mind Map")
                .font(.headline)
                .padding(.top)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Format:")
                    .fontWeight(.medium)
                
                Picker("", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue)
                            .tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                Text("Quality:")
                    .fontWeight(.medium)
                    .padding(.top, 8)
                
                Picker("", selection: $selectedQuality) {
                    ForEach(ExportQuality.allCases) { quality in
                        Text(quality.rawValue)
                            .tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                // Quality explanation
                HStack {
                    Spacer()
                    VStack(alignment: .trailing) {
                        switch selectedQuality {
                        case .low:
                            Text("Smaller file size, lower quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .medium:
                            Text("Balanced file size and quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .high:
                            Text("Larger file size, highest quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Export") {
                    onExport(selectedFormat, selectedQuality)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 350)
        .background(Color(.windowBackgroundColor))
    }
}

class ExportDialogWindowController: NSWindowController, NSWindowDelegate {
    var completion: ((ExportFormat, ExportQuality)?) -> Void = { _ in }
    
    convenience init(completion: @escaping ((ExportFormat, ExportQuality)?) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Export Mind Map"
        window.center()
        
        self.init(window: window)
        self.completion = completion
        window.delegate = self
        
        let viewModel = ExportDialogViewModel()
        let contentView = NSHostingView(rootView: ExportDialogContent(viewModel: viewModel) {
            format, quality in
            self.completion((format, quality))
            self.close()
        })
        window.contentView = contentView
    }
    
    func windowWillClose(_ notification: Notification) {
        // If window closes without selection, call completion with nil
        completion(nil)
    }
}

class ExportDialogViewModel: ObservableObject {
    @Published var selectedFormat: ExportFormat = .png
    @Published var selectedQuality: ExportQuality = .high
}

struct ExportDialogContent: View {
    @ObservedObject var viewModel: ExportDialogViewModel
    var onExport: (ExportFormat, ExportQuality) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Mind Map")
                .font(.headline)
                .padding(.top)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Format:")
                    .fontWeight(.medium)
                
                Picker("", selection: $viewModel.selectedFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue)
                            .tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                Text("Quality:")
                    .fontWeight(.medium)
                    .padding(.top, 8)
                
                Picker("", selection: $viewModel.selectedQuality) {
                    ForEach(ExportQuality.allCases) { quality in
                        Text(quality.rawValue)
                            .tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                // Quality explanation
                HStack {
                    Spacer()
                    VStack(alignment: .trailing) {
                        switch viewModel.selectedQuality {
                        case .low:
                            Text("Smaller file size, lower quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .medium:
                            Text("Balanced file size and quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .high:
                            Text("Larger file size, highest quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Export") {
                    onExport(viewModel.selectedFormat, viewModel.selectedQuality)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 350)
        .background(Color(.windowBackgroundColor))
    }
}

// Remove the old createExportPanel method as it's no longer needed
private func getExportFormat(for fileExtension: String) -> ExportFormat {
    switch fileExtension.lowercased() {
    case "jpg", "jpeg":
        return .jpeg
    case "pdf":
        return .pdf
    default:
        return .png
    }
} 
