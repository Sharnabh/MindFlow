import Foundation
import Combine

/// Service to track changes to topics for collaborative editing
class TopicChangeTracker {
    /// The collaboration service for sending changes
    private let collaborationService: CollaborationService
    
    /// The authentication service
    private let authService: AuthenticationService
    
    /// The document ID for the current session
    private var documentId: String?
    
    /// The current document version
    private var currentVersion: Int = 0
    
    /// Queue for pending changes
    private var pendingChanges: [TopicChange] = []
    
    /// Offline change queue
    private var offlineChanges: [TopicChange] = []
    
    /// The current user profile
    private var userProfile: UserProfile?
    
    /// The current topic ID being tracked
    private var topicId: UUID?
    
    /// The current topic being tracked
    private var topic: Topic?
    
    /// Flag to indicate if the service is syncing changes
    private var isSyncing: Bool = false
    
    /// Flag to indicate if the device is offline
    private var isOffline: Bool = false
    
    /// Publisher for connection state
    private var connectionStatePublisher: AnyCancellable?
    
    /// Initializes the change tracker
    /// - Parameters:
    ///   - collaborationService: The collaboration service
    ///   - authService: The authentication service
    init(collaborationService: CollaborationService, authService: AuthenticationService) {
        self.collaborationService = collaborationService
        self.authService = authService
        
        // Register for remote change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: NSNotification.Name("RemoteTopicChange"),
            object: nil
        )
        
        // Register for network status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkStatusChange),
            name: NSNotification.Name("NetworkStatusChanged"),
            object: nil
        )
        
        // Subscribe to connection state changes
        connectionStatePublisher = collaborationService.$connectionState
            .sink { [weak self] state in
                switch state {
                case .connected:
                    self?.isOffline = false
                    self?.processPendingChanges()
                    // After reconnecting, process any changes made while offline
                    self?.syncOfflineChanges()
                case .disconnected, .failed:
                    self?.isOffline = true
                default:
                    break
                }
            }
    }
    
    /// Start tracking changes for a document
    /// - Parameter documentId: The document ID
    func startTracking(for documentId: String) {
        self.documentId = documentId
        
        // Load the initial document version from UserDefaults or use 1 as default
        self.currentVersion = UserDefaults.standard.integer(forKey: "document_version_\(documentId)") 
        if self.currentVersion == 0 {
            self.currentVersion = 1
            saveCurrentVersion()
        }
        
        // Load any offline changes from storage
        loadOfflineChanges()
        
        // Connect to the collaboration service
        if let currentUser = authService.currentUser {
            let authToken = currentUser.id ?? ""
            if !authToken.isEmpty {
                collaborationService.connect(to: documentId, authToken: authToken)
            } else {
                print("Warning: Cannot connect to collaboration service without auth token")
            }
        }
    }
    
    /// Stop tracking changes
    func stopTracking() {
        // Save any pending changes to offline storage before stopping
        if !pendingChanges.isEmpty {
            offlineChanges.append(contentsOf: pendingChanges)
            saveOfflineChanges()
        }
        
        documentId = nil
        collaborationService.disconnect()
    }
    
    /// Save the current version to UserDefaults
    private func saveCurrentVersion() {
        if let documentId = documentId {
            UserDefaults.standard.set(currentVersion, forKey: "document_version_\(documentId)")
        }
    }
    
    /// Save the offline changes to UserDefaults
    private func saveOfflineChanges() {
        guard let documentId = documentId else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(offlineChanges)
            UserDefaults.standard.set(data, forKey: "offline_changes_\(documentId)")
        } catch {
            print("Error saving offline changes: \(error)")
        }
    }
    
    /// Load offline changes from UserDefaults
    private func loadOfflineChanges() {
        guard let documentId = documentId else { return }
        
        if let data = UserDefaults.standard.data(forKey: "offline_changes_\(documentId)") {
            do {
                let decoder = JSONDecoder()
                offlineChanges = try decoder.decode([TopicChange].self, from: data)
            } catch {
                print("Error loading offline changes: \(error)")
                offlineChanges = []
            }
        } else {
            offlineChanges = []
        }
    }
    
    /// Clear offline changes from UserDefaults
    private func clearOfflineChanges() {
        guard let documentId = documentId else { return }
        UserDefaults.standard.removeObject(forKey: "offline_changes_\(documentId)")
        offlineChanges = []
    }
    
    /// Sync changes made while offline
    private func syncOfflineChanges() {
        guard !offlineChanges.isEmpty, !isSyncing else { return }
        
        // Move offline changes to pending changes
        pendingChanges.append(contentsOf: offlineChanges)
        offlineChanges = []
        clearOfflineChanges()
        
        // Process all pending changes
        processPendingChanges()
    }
    
    /// Track a topic creation
    /// - Parameter topic: The created topic
    func trackTopicCreation(_ topic: Topic) {
        guard let userId = authService.currentUser?.id,
              let documentId = documentId else { return }
        
        // Create a dictionary with all topic properties
        var properties: [String: Any] = [
            "id": topic.id.uuidString,
            "name": topic.name,
            "position": [
                "x": topic.position.x,
                "y": topic.position.y
            ],
            "color": topic.backgroundColor.hexString ?? "#FFFFFF",
            "templateType": topic.templateType.rawValue
        ]
        
        // Add optional properties
        if let parentId = topic.parentId {
            properties["parentId"] = parentId.uuidString
        }
        
        if let notes = topic.note?.content {
            properties["notes"] = notes
        }
        
        if let icon = topic.metadata?["icon"] as? String {
            properties["icon"] = icon
        }
        
        let change = TopicChange(
            topicId: topic.id.uuidString,
            userId: userId,
            changeType: .create,
            properties: properties,
            version: currentVersion + 1
        )
        
        queueChange(change)
    }
    
    /// Track a topic update
    /// - Parameters:
    ///   - topic: The updated topic
    ///   - changedProperties: The properties that were changed
    func trackTopicUpdate(_ topic: Topic, changedProperties: [String: Any]) {
        guard let userId = authService.currentUser?.id,
              let documentId = documentId else { return }
        
        let change = TopicChange(
            topicId: topic.id.uuidString,
            userId: userId,
            changeType: .update,
            properties: changedProperties,
            version: currentVersion + 1
        )
        
        queueChange(change)
    }
    
    /// Track a topic deletion
    /// - Parameter topicId: The ID of the deleted topic
    func trackTopicDeletion(_ topicId: String) {
        guard let userId = authService.currentUser?.id,
              let documentId = documentId else { return }
        
        let change = TopicChange(
            topicId: topicId,
            userId: userId,
            changeType: .delete,
            properties: [:],
            version: currentVersion + 1
        )
        
        queueChange(change)
    }
    
    /// Track a topic movement
    /// - Parameters:
    ///   - topicId: The ID of the moved topic
    ///   - newPosition: The new position
    func trackTopicMovement(_ topicId: String, newPosition: CGPoint) {
        guard let userId = authService.currentUser?.id,
              let documentId = documentId else { return }
        
        let properties: [String: Any] = [
            "position": [
                "x": newPosition.x,
                "y": newPosition.y
            ]
        ]
        
        let change = TopicChange(
            topicId: topicId,
            userId: userId,
            changeType: .move,
            properties: properties,
            version: currentVersion + 1
        )
        
        queueChange(change)
    }
    
    /// Track a connection between topics
    /// - Parameters:
    ///   - parentId: The parent topic ID
    ///   - childId: The child topic ID
    func trackTopicConnection(_ parentId: String, childId: String) {
        guard let userId = authService.currentUser?.id,
              let documentId = documentId else { return }
        
        let properties: [String: Any] = [
            "parentId": parentId,
            "childId": childId
        ]
        
        let change = TopicChange(
            topicId: childId,
            userId: userId,
            changeType: .connect,
            properties: properties,
            version: currentVersion + 1
        )
        
        queueChange(change)
    }
    
    /// Track a disconnection between topics
    /// - Parameters:
    ///   - parentId: The parent topic ID
    ///   - childId: The child topic ID
    func trackTopicDisconnection(_ parentId: String, childId: String) {
        guard let userId = authService.currentUser?.id,
              let documentId = documentId else { return }
        
        let properties: [String: Any] = [
            "parentId": parentId,
            "childId": childId
        ]
        
        let change = TopicChange(
            topicId: childId,
            userId: userId,
            changeType: .disconnect,
            properties: properties,
            version: currentVersion + 1
        )
        
        queueChange(change)
    }
    
    /// Track changes to a topic
    /// - Parameters:
    ///   - topic: The topic to track changes for
    ///   - currentUserProfile: The current user profile
    func trackChangesToTopic(_ topic: Topic, currentUserProfile: UserProfile) {
        self.userProfile = currentUserProfile
        self.topicId = topic.id
        self.topic = topic
        // Document ID should be derived from the topic's metadata or passed separately
        if let docId = topic.metadata?["documentId"] as? String {
            self.documentId = docId
        }
        
        // Store the user ID for this session
        let userId = currentUserProfile.id
        if !userId.isEmpty {
            // Set the user ID for local change tracking
            print("Setting user ID for change tracking: \(userId)")
        } else {
            print("Warning: No user ID available in current user profile")
        }
        
        // Load the initial document version from UserDefaults or use 1 as default
        if let documentId = self.documentId {
            self.currentVersion = UserDefaults.standard.integer(forKey: "document_version_\(documentId)") 
            if self.currentVersion == 0 {
                self.currentVersion = 1
                saveCurrentVersion()
            }
            
            // Load any offline changes from storage
            loadOfflineChanges()
            
            // Connect to the collaboration service
            let authToken = currentUserProfile.id
            if !authToken.isEmpty {
                collaborationService.connect(to: documentId, authToken: authToken)
            } else {
                print("Warning: Cannot connect to collaboration service without auth token")
            }
        } else {
            print("Warning: No document ID available for the topic")
        }
    }
    
    /// Update the local change queue
    private func updateLocalChangeQueue() {
        guard let topic = self.topic, let userId = userProfile?.id else { return }
        // ... existing code ...
    }
    
    // MARK: - Private Methods
    
    /// Queue a change for sending
    /// - Parameter change: The change to queue
    private func queueChange(_ change: TopicChange) {
        // If online, add to pending changes
        if !isOffline {
            pendingChanges.append(change)
            
            // If connected, process changes
            if case .connected = collaborationService.connectionState {
                processPendingChanges()
            }
        } else {
            // If offline, add to offline changes and save to storage
            offlineChanges.append(change)
            saveOfflineChanges()
        }
    }
    
    /// Process any pending changes
    private func processPendingChanges() {
        guard !isSyncing && !pendingChanges.isEmpty else { return }
        
        isSyncing = true
        
        // Process all pending changes
        let changes = pendingChanges
        pendingChanges.removeAll()
        
        // Send each change
        for change in changes {
            collaborationService.sendChange(change)
            
            // Update the current version
            currentVersion = change.version
            saveCurrentVersion()
        }
        
        isSyncing = false
        
        // Check if more changes accumulated during processing
        if !pendingChanges.isEmpty {
            processPendingChanges()
        }
    }
    
    /// Handle a remote change
    /// - Parameter notification: The notification containing the change
    @objc private func handleRemoteChange(_ notification: Notification) {
        guard let change = notification.userInfo?["change"] as? TopicChange else {
            return
        }
        
        // Apply conflict resolution strategy (last-writer-wins)
        if change.version > currentVersion {
            // Update the current version since this is a newer change
            currentVersion = change.version
            saveCurrentVersion()
            
            // Notify the topic service about the remote change
            NotificationCenter.default.post(
                name: NSNotification.Name("ApplyRemoteTopicChange"),
                object: nil,
                userInfo: ["change": change]
            )
        }
    }
    
    /// Handle network status changes
    @objc private func handleNetworkStatusChange(_ notification: Notification) {
        guard let isOnline = notification.userInfo?["isOnline"] as? Bool else {
            return
        }
        
        // Update the offline flag
        isOffline = !isOnline
        
        if isOnline && !offlineChanges.isEmpty {
            syncOfflineChanges()
        }
    }
} 
