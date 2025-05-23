import Foundation
import SwiftUI

// Protocol defining layout operations
protocol LayoutServiceProtocol {
    // Layout algorithms
    func performAutoLayout(for topics: [Topic]) -> [Topic]
    func performFullAutoLayout(for topics: [Topic]) -> [Topic]
    func layoutSubtopicTree(in topic: inout Topic)
    
    // Topic size calculation
    func getTopicSize(for topic: Topic) -> CGSize
    func calculateSubtreeHeight(for topic: Topic) -> CGFloat
    
    // Branch style management
    func updateGlobalBranchStyle(in topics: [Topic], to style: Topic.BranchStyle) -> [Topic]
}

// Main implementation of the LayoutService
class LayoutService: LayoutServiceProtocol {
    // Constants for layout parameters
    private let horizontalSpacing: CGFloat = 250 // Space between parent and child
    private let verticalSpacing: CGFloat = 100   // Space between siblings
    private let baseMainTopicSpacing: CGFloat = 350 // Space between main topics
    private let minTopicWidth: CGFloat = 150     // Minimum topic width
    private let topicHeight: CGFloat = 60        // Default topic height
    
    // MARK: - Public Layout Methods
    
    func performAutoLayout(for topics: [Topic]) -> [Topic] {
        var updatedTopics = topics
        
        // If there's only one main topic, position it in the center
        let numMainTopics = updatedTopics.count
        if numMainTopics == 1 {
            var firstTopic = updatedTopics[0]
            firstTopic.position = CGPoint(x: 400, y: 300) // Center position
            
            // Position all subtopics in a tree layout
            if !firstTopic.subtopics.isEmpty {
                layoutSubtopicTree(in: &firstTopic)
            }
            
            updatedTopics[0] = firstTopic
        } else {
            // For multiple main topics, only auto-layout their subtopics
            for i in 0..<numMainTopics {
                var topic = updatedTopics[i]
                if !topic.subtopics.isEmpty {
                    layoutSubtopicTree(in: &topic)
                }
                updatedTopics[i] = topic
            }
        }
        
        // Ensure consistent branch styles
        return updateGlobalBranchStyle(in: updatedTopics, to: updatedTopics.isEmpty ? .default : updatedTopics[0].branchStyle)
    }
    
    func performFullAutoLayout(for topics: [Topic]) -> [Topic] {
        var updatedTopics = topics
        let numMainTopics = updatedTopics.count
        
        if numMainTopics > 0 {
            // Calculate total width needed for all main topics
            var totalWidth: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            // First pass: calculate dimensions
            for topic in updatedTopics {
                let topicSize = getTopicSize(for: topic)
                totalWidth += topicSize.width
                maxHeight = max(maxHeight, topicSize.height)
            }
            
            // Add spacing between topics
            totalWidth += baseMainTopicSpacing * CGFloat(numMainTopics - 1)
            
            // Calculate starting X position (centered)
            let startX = 400 - totalWidth / 2
            var currentX = startX
            
            // Second pass: position topics
            for i in 0..<numMainTopics {
                var topic = updatedTopics[i]
                let topicSize = getTopicSize(for: topic)
                
                // Position the main topic
                topic.position = CGPoint(
                    x: currentX + topicSize.width / 2,
                    y: 300 // Center vertically
                )
                
                // Position all subtopics in a tree layout
                if !topic.subtopics.isEmpty {
                    layoutSubtopicTree(in: &topic)
                }
                
                updatedTopics[i] = topic
                currentX += topicSize.width + baseMainTopicSpacing
            }
        }
        
        // Ensure consistent branch styles
        return updateGlobalBranchStyle(in: updatedTopics, to: updatedTopics.isEmpty ? .default : updatedTopics[0].branchStyle)
    }
    
    func layoutSubtopicTree(in topic: inout Topic) {
        layoutSubtopicTreeImproved(in: &topic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }
    
    // MARK: - Topic Size Calculation
    
    func getTopicSize(for topic: Topic) -> CGSize {
        // Estimate width based on text length (this is a simplification)
        let estimatedWidth = max(minTopicWidth, CGFloat(topic.name.count) * 10)
        
        // Calculate height based on content
        let height = topicHeight
        
        return CGSize(width: estimatedWidth, height: height)
    }
    
    func calculateSubtreeHeight(for topic: Topic) -> CGFloat {
        let topicSize = getTopicSize(for: topic)
        let actualTopicHeight = topicSize.height
        
        if topic.subtopics.isEmpty {
            return actualTopicHeight
        }
        
        // For Tree template, subtopics are arranged horizontally, not vertically
        if topic.templateType == .tree {
            // Find the tallest subtree in the tree layout
            var maxSubtreeHeight: CGFloat = 0
            var totalWidth: CGFloat = 0
            
            for subtopic in topic.subtopics {
                let subtreeHeight = calculateSubtreeHeight(for: subtopic)
                maxSubtreeHeight = max(maxSubtreeHeight, subtreeHeight)
                totalWidth += getTopicSize(for: subtopic).width
            }
            
            // Add spacing between topics
            if topic.subtopics.count > 1 {
                totalWidth += verticalSpacing * CGFloat(topic.subtopics.count - 1)
            }
            
            // Return the height of the parent + spacing + height of tallest child
            return actualTopicHeight + horizontalSpacing + maxSubtreeHeight
        } else {
            // Default Mind Map behavior - calculate vertical stacking height
            var totalHeight: CGFloat = 0
            for (index, subtopic) in topic.subtopics.enumerated() {
                let subtreeHeight = calculateSubtreeHeight(for: subtopic)
                totalHeight += subtreeHeight
                
                // Add spacing after each subtopic except the last one
                if index < topic.subtopics.count - 1 {
                    totalHeight += verticalSpacing
                }
            }
            
            return max(actualTopicHeight, totalHeight)
        }
    }
    
    // MARK: - Branch Style Management
    
    func updateGlobalBranchStyle(in topics: [Topic], to style: Topic.BranchStyle) -> [Topic] {
        var updatedTopics = topics
        
        // Apply the branch style to all topics
        for i in 0..<updatedTopics.count {
            var mainTopic = updatedTopics[i]
            updateBranchStyleRecursively(in: &mainTopic, to: style)
            updatedTopics[i] = mainTopic
        }
        
        return updatedTopics
    }
    
    // MARK: - Private Helper Methods
    
    // Improved layout algorithm for subtopic trees
    private func layoutSubtopicTreeImproved(in topic: inout Topic, horizontalSpacing: CGFloat, verticalSpacing: CGFloat) {
        let numSubtopics = topic.subtopics.count
        if numSubtopics == 0 { return }
        
        // Get the template type to determine layout direction
        let templateType = topic.templateType
        
        if templateType == .tree {
            // TREE TEMPLATE: Position subtopics in a horizontal row below the parent
            
            // First, calculate the total width needed for all subtopics at this level
            var totalWidth: CGFloat = 0
            var subtopicWidths: [CGFloat] = []
            
            // First pass: calculate subtopic's required width considering their own subtrees
            for i in 0..<numSubtopics {
                var subtopic = topic.subtopics[i]
                
                if subtopic.subtopics.isEmpty {
                    // Simple case: just the topic's own width
                    let topicWidth = getTopicSize(for: subtopic).width
                    subtopicWidths.append(topicWidth)
                    totalWidth += topicWidth
                } else {
                    // Complex case: need to calculate width required for subtree
                    // Temporarily layout the subtree to calculate its width requirements
                    layoutSubtopicTreeImproved(in: &subtopic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
                    
                    // Calculate width needed for this subtopic's subtree
                    let subtreeWidth = calculateSubtreeWidth(for: subtopic)
                    subtopicWidths.append(max(getTopicSize(for: subtopic).width, subtreeWidth))
                    totalWidth += max(getTopicSize(for: subtopic).width, subtreeWidth)
                    
                    // Save the updated subtopic (we'll position it again later)
                    topic.subtopics[i] = subtopic
                }
            }
            
            // Add spacing between subtopics
            totalWidth += verticalSpacing * CGFloat(numSubtopics - 1)
            
            // Calculate the starting X position (centered under parent)
            let startX = topic.position.x - totalWidth / 2
            var currentX = startX
            
            // Second pass: position each subtopic with enough space for its subtree
            for i in 0..<numSubtopics {
                var subtopic = topic.subtopics[i]
                let allocatedWidth = subtopicWidths[i]
                
                // Position below the parent, centered within its allocated width
                let subtopicCenterX = currentX + allocatedWidth / 2
                subtopic.position = CGPoint(
                    x: subtopicCenterX,
                    y: topic.position.y + horizontalSpacing
                )
                
                // Recursively layout this subtopic's subtopics again to ensure they're properly centered
                if !subtopic.subtopics.isEmpty {
                    layoutSubtopicTreeImproved(in: &subtopic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
                }
                
                // Save the updated subtopic
                topic.subtopics[i] = subtopic
                
                // Move to the next position
                currentX += allocatedWidth + verticalSpacing
            }
        } else {
            // MIND MAP TEMPLATE (DEFAULT): Position subtopics in a vertical column to the right
            
            // Calculate subtree heights for each subtopic
            var subtreeHeights: [CGFloat] = []
            var totalHeight: CGFloat = 0
            
            for subtopic in topic.subtopics {
                let height = calculateSubtreeHeight(for: subtopic)
                subtreeHeights.append(height)
                totalHeight += height
            }
            
            // Add spacing between subtopics
            totalHeight += verticalSpacing * CGFloat(numSubtopics - 1)
            
            // Calculate the starting Y position
            let startY = topic.position.y + totalHeight / 2
            var currentY = startY
            
            // Position each subtopic
            for i in 0..<numSubtopics {
                var subtopic = topic.subtopics[i]
                let subtreeHeight = subtreeHeights[i]
                
                // Position relative to the parent
                currentY -= subtreeHeight / 2
                subtopic.position = CGPoint(
                    x: topic.position.x + horizontalSpacing,
                    y: currentY
                )
                currentY -= subtreeHeight / 2
                
                // Recursively layout this subtopic's subtopics
                if !subtopic.subtopics.isEmpty {
                    layoutSubtopicTreeImproved(in: &subtopic, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
                }
                
                // Save the updated subtopic
                topic.subtopics[i] = subtopic
                
                // Add spacing for the next subtopic
                if i < numSubtopics - 1 {
                    currentY -= verticalSpacing
                }
            }
        }
    }
    
    // Calculate the width required for a topic's subtree in tree template
    private func calculateSubtreeWidth(for topic: Topic) -> CGFloat {
        if topic.subtopics.isEmpty {
            return getTopicSize(for: topic).width
        }
        
        var totalWidth: CGFloat = 0
        
        // Sum the widths of all subtopics
        for subtopic in topic.subtopics {
            // For each subtopic, use its own width or its subtree width, whichever is larger
            let subtopicWidth = getTopicSize(for: subtopic).width
            let subtreeWidth = calculateSubtreeWidth(for: subtopic)
            totalWidth += max(subtopicWidth, subtreeWidth)
        }
        
        // Add spacing between subtopics
        if topic.subtopics.count > 1 {
            totalWidth += verticalSpacing * CGFloat(topic.subtopics.count - 1)
        }
        
        return totalWidth
    }
    
    // Update the branch style for a topic and all its subtopics
    private func updateBranchStyleRecursively(in topic: inout Topic, to style: Topic.BranchStyle) {
        // Update branch style but preserve template type
        topic.branchStyle = style
        
        for i in 0..<topic.subtopics.count {
            var subtopic = topic.subtopics[i]
            updateBranchStyleRecursively(in: &subtopic, to: style)
            topic.subtopics[i] = subtopic
        }
    }
} 