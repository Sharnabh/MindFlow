# MindFlow Collaboration Implementation

This document outlines the collaboration system implemented in MindFlow, detailing the current state, architecture decisions, and next steps.

## Phase 1 Implementation

### Core Components

1. **Data Models** (`CollaborationModels.swift`)
   - Message types for WebSocket communication
   - Collaborator and session models
   - Topic change tracking with versioning
   - Access control models

2. **WebSocket Service** (`CollaborationService.swift`)
   - Real-time WebSocket connection management
   - Connection state handling and reconnection logic
   - Message parsing and sending
   - Change propagation via notifications

3. **Document Sharing** (`DocumentSharingService.swift`)
   - API for document sharing
   - Link generation for sharing
   - Collaborator management
   - Access control implementation

4. **Change Tracking** (`TopicChangeTracker.swift`)
   - Tracking changes to topics
   - Queuing and sending changes
   - Remote change management
   - Version management for conflict resolution

5. **UI Components**
   - `CollaboratorIndicator.swift` for displaying active collaborators
   - `ShareView.swift` for document sharing interface

6. **Topic Service Integration** (`TopicService.swift`)
   - Integration with `TopicChangeTracker`
   - Remote change application
   - Local change tracking

7. **Offline Support**
   - Network status monitoring (`NetworkMonitor.swift`)
   - Offline change queuing
   - Sync upon reconnection
   - Persistent storage of offline changes

8. **Conflict Resolution**
   - Last-writer-wins strategy based on version numbers
   - Version persistence across app restarts

### Current Capabilities

- Connect to a collaboration server via WebSockets
- Track local changes in real-time
- Send changes to connected collaborators
- Receive and apply remote changes
- Work offline with change queuing
- Persist version information
- Share documents via links
- Manage collaborator access levels
- Display active collaborators with their indicators

## Next Steps for Phase 2

### Server Implementation

1. **Document Storage Service**
   - Implement the server-side storage for documents
   - History versioning with timestamps
   - Secure authentication for document access

2. **WebSocket Server**
   - Implement the server-side WebSocket handler
   - Message broadcasting to connected clients
   - Connection management and security

3. **User Management**
   - Server-side user permissions
   - Access control enforcement
   - Invitation system implementation

### Client Enhancements

1. **Cursor Tracking**
   - Real-time cursor position sharing
   - Visual cursor representation for collaborators
   - Cursor animations and labeling

2. **Advanced Conflict Resolution**
   - Operational transformation for concurrent edits
   - Conflict detection and resolution UI
   - Merge tools for conflicting changes

3. **Presence Awareness**
   - User online/offline status
   - "Currently viewing" indicators
   - User activity tracking

4. **Document History**
   - Version history browsing
   - Change tracking with attribution
   - Restore previous versions

5. **Permissions Refinement**
   - More granular permission controls
   - Section-based permissions
   - Time-limited access

## Integration Instructions

### Enabling Collaboration on a Document

```swift
// Get the services
let topicService = DependencyContainer.shared.makeCanvasViewModel().topicService
let documentSharingService = DependencyContainer.shared.makeDocumentSharingService()

// Enable collaboration on a document
topicService.enableCollaboration(documentId: "your-document-id")

// Create a share link for collaboration
documentSharingService.createShareLink(
    documentId: "your-document-id",
    accessLevel: .edit,
    expirationDays: 7
).sink(
    receiveCompletion: { completion in
        if case .failure(let error) = completion {
            print("Error creating share link: \(error)")
        }
    },
    receiveValue: { shareLink in
        print("Share link: \(shareLink)")
    }
).store(in: &cancellables)
```

### Disabling Collaboration

```swift
// Get the services
let topicService = DependencyContainer.shared.makeCanvasViewModel().topicService

// Disable collaboration
topicService.disableCollaboration()
```

## Technical Decisions

1. **WebSocket Protocol**: Chosen for its real-time capabilities and lower overhead compared to HTTP polling.

2. **Version-based Conflict Resolution**: Using simple version numbers initially for conflict resolution, with the ability to upgrade to operational transformation in the future.

3. **Offline Support**: Designed with offline-first capability to ensure users can continue working without an internet connection.

4. **Stateful Services**: Using stateful services to manage connection and document state, with dependency injection for testability.

5. **Notification-based Communication**: Using NotificationCenter for inter-service communication to maintain loose coupling. 