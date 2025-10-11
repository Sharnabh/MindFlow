import Foundation
import CloudKit
import SwiftUI

// MARK: - CloudKit Collaboration Service
// This would extend our current iCloud implementation to support real-time collaboration

protocol CollaborationServiceProtocol {
    func shareDocument(_ document: MindMapDocument) async throws -> CKShare
    func acceptShare(from metadata: CKShare.Metadata) async throws
    func getCollaborators(for document: MindMapDocument) async throws -> [CKShare.Participant]
    func stopSharing(_ document: MindMapDocument) async throws
    func syncRealTimeChanges(for document: MindMapDocument) -> AsyncStream<CollaborationChange>
}

// Types of changes that can be synchronized
enum CollaborationChange {
    case topicAdded(Topic, by: CKRecord.ID)
    case topicUpdated(Topic, by: CKRecord.ID)
    case topicDeleted(UUID, by: CKRecord.ID)
    case topicMoved(UUID, to: CGPoint, by: CKRecord.ID)
    case relationshipAdded(from: UUID, to: UUID, by: CKRecord.ID)
    case relationshipRemoved(from: UUID, to: UUID, by: CKRecord.ID)
    case userCursor(CKRecord.ID, at: CGPoint)
    case error(String)
}

// Collaboration metadata
struct CollaborationInfo {
    let shareURL: URL
    let participants: [CKShare.Participant]
    let permissions: CKShare.ParticipantPermission
    let isOwner: Bool
}

class CollaborationService: CollaborationServiceProtocol, ObservableObject {
    static let shared = CollaborationService()
    
    @Published var activeCollaborations: [UUID: CollaborationInfo] = [:]
    @Published var liveUsers: [CKRecord.ID: UserPresence] = [:]
    
    private let container: CKContainer
    private let database: CKDatabase
    private let customZone: CKRecordZone
    private var activeSubscriptions: [UUID: CKQuerySubscription] = [:]
    private var changeStreams: [UUID: AsyncStream<CollaborationChange>.Continuation] = [:]
    private var presenceTimers: [UUID: Timer] = [:]
    private var userHeartbeats: [CKRecord.ID: Date] = [:]
    private var zoneExists: Bool = false
    private var zoneCheckInProgress: Bool = false
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.sharnabhB.MindFlow")
        database = container.privateCloudDatabase
        customZone = CKRecordZone(zoneName: "MindFlowCollaborationZone")
        
        // Pre-warm the zone check in the background
        Task {
            try? await ensureCustomZoneExists()
        }
    }
    
    // MARK: - Zone Management
    
    private func ensureCustomZoneExists() async throws {
        // Return immediately if we already know the zone exists
        if zoneExists {
            print("✅ Custom zone already exists (cached)")
            return
        }
        
        // Prevent multiple simultaneous zone checks
        if zoneCheckInProgress {
            print("⏳ Zone check already in progress, waiting...")
            while zoneCheckInProgress {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            return
        }
        
        zoneCheckInProgress = true
        defer { zoneCheckInProgress = false }
        
        print("🔍 Checking if custom zone exists...")
        
        do {
            let _ = try await database.recordZone(for: customZone.zoneID)
            print("✅ Custom zone already exists")
            zoneExists = true
        } catch {
            print("📝 Creating custom zone...")
            let operation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone])
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordZonesCompletionBlock = { _, _, error in
                    if let error = error {
                        print("❌ Failed to create custom zone: \(error)")
                        continuation.resume(throwing: error)
                    } else {
                        print("✅ Custom zone created successfully")
                        self.zoneExists = true
                        continuation.resume(returning: ())
                    }
                }
                database.add(operation)
            }
        }
    }
    
    // MARK: - Document Sharing
    
    func shareDocument(_ document: MindMapDocument) async throws -> CKShare {
        print("🔄 CollaborationService: Starting share process for document: \(document.filename)")
        
        // 0. Ensure custom zone exists (should be fast due to caching)
        try await ensureCustomZoneExists()
        
        // 1. Convert document to CloudKit record in custom zone
        print("📄 Creating CloudKit record from document...")
        let documentRecord = try await createCloudKitRecord(from: document, in: customZone)
        print("✅ CloudKit record created: \(documentRecord.recordID)")
        
        // 2. Create a share for the document
        print("🔗 Creating CloudKit share...")
        let share = CKShare(rootRecord: documentRecord)
        share[CKShare.SystemFieldKey.title] = document.filename
        share.publicPermission = .none // Private sharing only
        print("✅ Share created with title: \(document.filename)")
        
        // 3. Save BOTH the document record AND share in the SAME operation
        print("💾 Saving document record and share together...")
        let operation = CKModifyRecordsOperation(
            recordsToSave: [documentRecord, share],
            recordIDsToDelete: nil
        )
        
        // Set operation properties for better performance
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare, Error>) in
            operation.modifyRecordsCompletionBlock = { [weak self] savedRecords, deletedRecordIDs, error in
                if let error = error {
                    print("❌ Failed to save document and share: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Document record and share saved successfully")
                    print("🔗 Share URL: \(share.url?.absoluteString ?? "No URL")")
                    
                    // Store collaboration info
                    let collaborationInfo = CollaborationInfo(
                        shareURL: share.url!,
                        participants: share.participants,
                        permissions: .readWrite,
                        isOwner: true
                    )
                    self?.activeCollaborations[document.id] = collaborationInfo
                    print("✅ Collaboration info stored for document: \(document.id)")
                    continuation.resume(returning: share)
                }
            }
            database.add(operation)
        }
        return share
    }
    
    func acceptShare(from metadata: CKShare.Metadata) async throws {
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.acceptSharesCompletionBlock = { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
            container.add(operation)
        }
    }
    
    func getCollaborators(for document: MindMapDocument) async throws -> [CKShare.Participant] {
        // Query for the share record associated with this document in shared database
        let predicate = NSPredicate(format: "share.recordID == %@", CKRecord.ID(recordName: document.id.uuidString))
        let query = CKQuery(recordType: "Topic", predicate: predicate)
        
        let records = try await container.sharedCloudDatabase.records(matching: query)
        
        // Extract participants from share records
        var participants: [CKShare.Participant] = []
        for (_, result) in records.matchResults {
            switch result {
            case .success(let record):
                if let share = record as? CKShare {
                    participants.append(contentsOf: share.participants)
                }
            case .failure(let error):
                print("Failed to fetch collaborator record: \(error)")
            }
        }
        
        return participants
    }
    
    func stopSharing(_ document: MindMapDocument) async throws {
        // Find and delete the share record from shared database
        let predicate = NSPredicate(format: "share.recordID == %@", CKRecord.ID(recordName: document.id.uuidString))
        let query = CKQuery(recordType: "Topic", predicate: predicate)
        
        let records = try await container.sharedCloudDatabase.records(matching: query)
        var recordIDsToDelete: [CKRecord.ID] = []
        
        for (_, result) in records.matchResults {
            switch result {
            case .success(let record):
                if record is CKShare {
                    recordIDsToDelete.append(record.recordID)
                }
            case .failure(let error):
                print("Failed to fetch share record for deletion: \(error)")
            }
        }
        
        if !recordIDsToDelete.isEmpty {
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsCompletionBlock = { _, _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
                container.sharedCloudDatabase.add(operation)
            }
        }
        
        // Remove from active collaborations
        activeCollaborations.removeValue(forKey: document.id)
    }
    
    // MARK: - Real-time Synchronization
    
    func syncRealTimeChanges(for document: MindMapDocument) -> AsyncStream<CollaborationChange> {
        AsyncStream { continuation in
            // Store the continuation for this document
            changeStreams[document.id] = continuation
            
            // Set up CloudKit subscription for real-time updates in custom zone
            let subscription = CKQuerySubscription(
                recordType: "Topic",
                predicate: NSPredicate(format: "documentID == %@", document.id.uuidString),
                subscriptionID: "topic-changes-\(document.id.uuidString)",
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            // Configure the subscription
            subscription.notificationInfo = CKQuerySubscription.NotificationInfo()
            subscription.notificationInfo?.shouldSendContentAvailable = true
            subscription.notificationInfo?.shouldBadge = false
            subscription.notificationInfo?.alertBody = "Mind map updated"
            
            // Save the subscription
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
            operation.modifySubscriptionsCompletionBlock = { [weak self] savedSubscriptions, deletedSubscriptionIDs, error in
                if let error = error {
                    print("Failed to create subscription: \(error)")
                    continuation.yield(.error("Failed to set up real-time sync: \(error.localizedDescription)"))
                } else {
                    print("Successfully created subscription for document: \(document.id)")
                    self?.activeSubscriptions[document.id] = subscription
                }
            }
            
            database.add(operation)
            
            // Set up push notification handling
            setupPushNotificationHandling(for: document)
        }
    }
    
    // MARK: - User Presence
    
    func broadcastCursorPosition(_ position: CGPoint, for document: MindMapDocument) async {
        do {
            let userID = try await container.userRecordID()
            
            // Create a cursor position record in custom zone
            let cursorRecord = CKRecord(recordType: "CursorPosition", recordID: CKRecord.ID(zoneID: customZone.zoneID))
            cursorRecord["documentID"] = document.id.uuidString
            cursorRecord["userID"] = userID.recordName
            cursorRecord["positionX"] = NSNumber(value: position.x)
            cursorRecord["positionY"] = NSNumber(value: position.y)
            cursorRecord["timestamp"] = Date()
            
            // Save the cursor position
            let operation = CKModifyRecordsOperation(recordsToSave: [cursorRecord], recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsCompletionBlock = { _, _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
                database.add(operation)
            }
        } catch {
            // Only log errors that aren't related to container configuration
            if !error.localizedDescription.contains("BadContainer") && 
               !error.localizedDescription.contains("Couldn't get container configuration") {
                print("Failed to broadcast cursor position: \(error)")
            }
        }
    }
    
    func startPresenceMonitoring(for document: MindMapDocument) {
        // Set up subscription for cursor positions
        let subscription = CKQuerySubscription(
            recordType: "CursorPosition",
            predicate: NSPredicate(format: "documentID == %@", document.id.uuidString),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        subscription.notificationInfo = CKQuerySubscription.NotificationInfo()
        subscription.notificationInfo?.shouldSendContentAvailable = true
        subscription.notificationInfo?.shouldBadge = false
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        operation.modifySubscriptionsCompletionBlock = { [weak self] savedSubscriptions, deletedSubscriptionIDs, error in
            if let error = error {
                print("Failed to create cursor subscription: \(error)")
            } else {
                print("Successfully created cursor subscription for document: \(document.id)")
                self?.activeSubscriptions[document.id] = subscription
            }
        }
        
        database.add(operation)
        
        // Set up periodic cleanup of old cursor positions
        startCursorCleanup(for: document)
        
        // Start user presence monitoring
        startUserPresenceMonitoring(for: document)
    }
    
    private func startUserPresenceMonitoring(for document: MindMapDocument) {
        // Start sending periodic heartbeats
        startHeartbeat(for: document)
        
        // Start monitoring for user presence changes
        startPresenceCleanup(for: document)
    }
    
    private func startHeartbeat(for document: MindMapDocument) {
        // Send heartbeat every 30 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.sendHeartbeat(for: document)
            }
        }
        presenceTimers[document.id] = timer
    }
    
    private func sendHeartbeat(for document: MindMapDocument) async {
        do {
            let userID = try await container.userRecordID()
            
            let heartbeatRecord = CKRecord(recordType: "UserPresence", recordID: CKRecord.ID(zoneID: customZone.zoneID))
            heartbeatRecord["documentID"] = document.id.uuidString
            heartbeatRecord["userID"] = userID.recordName
            heartbeatRecord["timestamp"] = Date()
            heartbeatRecord["isActive"] = true
            
            let operation = CKModifyRecordsOperation(recordsToSave: [heartbeatRecord], recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsCompletionBlock = { _, _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
                database.add(operation)
            }
        } catch {
            // Only log errors that aren't related to container configuration
            if !error.localizedDescription.contains("BadContainer") && 
               !error.localizedDescription.contains("Couldn't get container configuration") {
                print("Failed to send heartbeat: \(error)")
            }
        }
    }
    
    private func startPresenceCleanup(for document: MindMapDocument) {
        // Clean up inactive users every minute
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.cleanupInactiveUsers(for: document)
            }
        }
    }
    
    private func cleanupInactiveUsers(for document: MindMapDocument) async {
        let cutoffDate = Date().addingTimeInterval(-120) // Remove users inactive for 2 minutes
        let predicate = NSPredicate(format: "documentID == %@ AND timestamp < %@", document.id.uuidString, cutoffDate as NSDate)
        let query = CKQuery(recordType: "UserPresence", predicate: predicate)
        
        do {
            let records = try await database.records(matching: query)
            var inactiveUserIDs: [CKRecord.ID] = []
            
            for (_, result) in records.matchResults {
                switch result {
                case .success(let record):
                    if let userIDString = record["userID"] as? String {
                        let userID = CKRecord.ID(recordName: userIDString)
                        inactiveUserIDs.append(userID)
                    }
                case .failure(let error):
                    print("Failed to fetch presence record for cleanup: \(error)")
                }
            }
            
            // Remove inactive users from live users
            await MainActor.run {
                for userID in inactiveUserIDs {
                    liveUsers.removeValue(forKey: userID)
                }
            }
            
        } catch {
            print("Failed to cleanup inactive users: \(error)")
        }
    }
    
    private func startCursorCleanup(for document: MindMapDocument) {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.cleanupOldCursorPositions(for: document)
            }
        }
    }
    
    private func cleanupOldCursorPositions(for document: MindMapDocument) async {
        let cutoffDate = Date().addingTimeInterval(-60) // Remove positions older than 1 minute
        let predicate = NSPredicate(format: "documentID == %@ AND timestamp < %@", document.id.uuidString, cutoffDate as NSDate)
        let query = CKQuery(recordType: "CursorPosition", predicate: predicate)
        
        do {
            let records = try await database.records(matching: query)
            var recordIDsToDelete: [CKRecord.ID] = []
            
            for (_, result) in records.matchResults {
                switch result {
                case .success(let record):
                    recordIDsToDelete.append(record.recordID)
                case .failure(let error):
                    print("Failed to fetch cursor record for cleanup: \(error)")
                }
            }
            
            if !recordIDsToDelete.isEmpty {
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    operation.modifyRecordsCompletionBlock = { _, _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                    database.add(operation)
                }
            }
        } catch {
            print("Failed to cleanup old cursor positions: \(error)")
        }
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(
        localChange: CollaborationChange,
        remoteChange: CollaborationChange
    ) -> CollaborationChange {
        // Implement sophisticated conflict resolution logic
        switch (localChange, remoteChange) {
        case (.topicUpdated(let localTopic, _), .topicUpdated(let remoteTopic, _)):
            return resolveTopicUpdateConflict(local: localTopic, remote: remoteTopic)
            
        case (.topicMoved(let localID, let localPos, let localUser), .topicMoved(let remoteID, let remotePos, let remoteUser)):
            return resolvePositionConflict(localID: localID, localPos: localPos, localUser: localUser,
                                        remoteID: remoteID, remotePos: remotePos, remoteUser: remoteUser)
            
        case (.topicAdded(let localTopic, let localUser), .topicAdded(let remoteTopic, let remoteUser)):
            return resolveTopicAdditionConflict(local: localTopic, localUser: localUser,
                                              remote: remoteTopic, remoteUser: remoteUser)
            
        case (.topicDeleted(let localID, let localUser), .topicUpdated(let remoteTopic, let remoteUser)):
            return resolveDeleteUpdateConflict(deletedID: localID, deletedBy: localUser,
                                             updatedTopic: remoteTopic, updatedBy: remoteUser)
            
        case (.topicUpdated(let localTopic, let localUser), .topicDeleted(let remoteID, let remoteUser)):
            return resolveUpdateDeleteConflict(updatedTopic: localTopic, updatedBy: localUser,
                                             deletedID: remoteID, deletedBy: remoteUser)
            
        default:
            // For other cases, use last-writer-wins strategy
            return remoteChange
        }
    }
    
    private func resolveTopicUpdateConflict(local: Topic, remote: Topic) -> CollaborationChange {
        // Since Topic doesn't have updatedAt, use a simple last-writer-wins strategy
        // In a real implementation, you might want to add timestamps to Topic or use other conflict resolution
        return .topicUpdated(remote, by: CKRecord.ID(recordName: "remote"))
    }
    
    private func resolvePositionConflict(localID: UUID, localPos: CGPoint, localUser: CKRecord.ID,
                                       remoteID: UUID, remotePos: CGPoint, remoteUser: CKRecord.ID) -> CollaborationChange {
        // For position conflicts, use the most recent change
        // In a real implementation, you might want to merge positions or use other strategies
        return .topicMoved(remoteID, to: remotePos, by: remoteUser)
    }
    
    private func resolveTopicAdditionConflict(local: Topic, localUser: CKRecord.ID,
                                            remote: Topic, remoteUser: CKRecord.ID) -> CollaborationChange {
        // If both users add topics with the same ID, keep both but with different IDs
        // This is a simplified approach - in reality you'd need more sophisticated merging
        return .topicAdded(remote, by: remoteUser)
    }
    
    private func resolveDeleteUpdateConflict(deletedID: UUID, deletedBy: CKRecord.ID,
                                           updatedTopic: Topic, updatedBy: CKRecord.ID) -> CollaborationChange {
        // If one user deletes while another updates, prefer the update
        // This prevents accidental data loss
        return .topicUpdated(updatedTopic, by: updatedBy)
    }
    
    private func resolveUpdateDeleteConflict(updatedTopic: Topic, updatedBy: CKRecord.ID,
                                           deletedID: UUID, deletedBy: CKRecord.ID) -> CollaborationChange {
        // If one user updates while another deletes, prefer the update
        // This prevents accidental data loss
        return .topicUpdated(updatedTopic, by: updatedBy)
    }
    
    // MARK: - Helper Methods
    
    private func setupPushNotificationHandling(for document: MindMapDocument) {
        // Note: CloudKit push notifications are typically handled through the app delegate
        // For this implementation, we'll rely on CloudKit subscriptions and polling
        // In a real app, you would set up push notifications in the app delegate
        print("Push notification handling setup for document: \(document.id)")
    }
    
    private func handleCloudKitNotification(_ notification: Notification, for document: MindMapDocument) {
        guard let userInfo = notification.userInfo,
              let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return
        }
        
        switch notification.notificationType {
        case .query:
            if let queryNotification = notification as? CKQueryNotification {
                handleQueryNotification(queryNotification, for: document)
            }
        default:
            break
        }
    }
    
    private func handleQueryNotification(_ notification: CKQueryNotification, for document: MindMapDocument) {
        guard let recordID = notification.recordID else {
            return
        }
        
        Task {
            do {
                // Fetch the updated record
                let record = try await database.record(for: recordID)
                
                // Check if this is a cursor position update
                if record.recordType == "CursorPosition" {
                    await handleCursorPositionUpdate(record)
                } else {
                    // Handle topic changes
                    guard let continuation = changeStreams[document.id] else {
                        return
                    }
                    
                    let change = try await parseChangeFromRecord(record, notificationType: notification.queryNotificationReason)
                    
                    // Check for conflicts and resolve them
                    let resolvedChange = await resolveChangeConflicts(change, for: document)
                    continuation.yield(resolvedChange)
                }
                
            } catch {
                if let continuation = changeStreams[document.id] {
                    continuation.yield(.error("Failed to process change: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func resolveChangeConflicts(_ change: CollaborationChange, for document: MindMapDocument) async -> CollaborationChange {
        // In a real implementation, you would check for existing local changes
        // and resolve conflicts before applying the remote change
        // For now, we'll return the change as-is
        return change
    }
    
    private func handleCursorPositionUpdate(_ record: CKRecord) async {
        guard let userIDString = record["userID"] as? String,
              let positionX = record["positionX"] as? NSNumber,
              let positionY = record["positionY"] as? NSNumber,
              let timestamp = record["timestamp"] as? Date else {
            return
        }
        
        let userID = CKRecord.ID(recordName: userIDString)
        
        // Only show cursor if it's from another user and recent
        do {
            let currentUserID = try await container.userRecordID()
            guard userID != currentUserID,
                  timestamp.timeIntervalSinceNow > -60 else { // Within last minute
                return
            }
        } catch {
            return
        }
        
        let position = CGPoint(x: positionX.doubleValue, y: positionY.doubleValue)
        let presence = UserPresence(
            userID: userID,
            displayName: "User \(userIDString.prefix(8))",
            cursorPosition: position,
            lastSeen: timestamp,
            color: .blue // Could be assigned based on userID
        )
        
        await MainActor.run {
            liveUsers[userID] = presence
        }
    }
    
    private func parseChangeFromRecord(_ record: CKRecord, notificationType: CKQueryNotification.Reason) async throws -> CollaborationChange {
        guard let documentIDString = record["documentID"] as? String,
              let documentID = UUID(uuidString: documentIDString),
              let userID = record.creatorUserRecordID else {
            throw CollaborationError.shareNotFound
        }
        
        switch notificationType {
        case .recordCreated:
            // Parse topic from record
            let topic = try parseTopicFromRecord(record)
            return .topicAdded(topic, by: userID)
            
        case .recordUpdated:
            let topic = try parseTopicFromRecord(record)
            return .topicUpdated(topic, by: userID)
            
        case .recordDeleted:
            guard let topicIDString = record.recordID.recordName as String?,
                  let topicID = UUID(uuidString: topicIDString) else {
                throw CollaborationError.shareNotFound
            }
            return .topicDeleted(topicID, by: userID)
            
        @unknown default:
            throw CollaborationError.shareNotFound
        }
    }
    
    private func parseTopicFromRecord(_ record: CKRecord) throws -> Topic {
        // This would need to be implemented based on your Topic structure
        // For now, returning a placeholder
        guard let topicData = record["topicData"] as? Data else {
            throw CollaborationError.shareNotFound
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(Topic.self, from: topicData)
    }
    
    private func createCloudKitRecord(from document: MindMapDocument, in zone: CKRecordZone? = nil) async throws -> CKRecord {
        let recordID: CKRecord.ID
        if let zone = zone {
            recordID = CKRecord.ID(recordName: document.id.uuidString, zoneID: zone.zoneID)
        } else {
            recordID = CKRecord.ID(recordName: document.id.uuidString)
        }
        
        let record = CKRecord(recordType: "MindMapDocument", recordID: recordID)
        record["filename"] = document.filename
        record["topics"] = try JSONEncoder().encode(document.topics)
        record["lastModified"] = Date()
        return record
    }
    
    // MARK: - Debug Methods
    
    func listActiveSubscriptions() async {
        print("Active CloudKit Subscriptions (from local tracking):")
        if activeSubscriptions.isEmpty {
            print("- No active subscriptions tracked locally")
        } else {
            for (documentID, subscription) in activeSubscriptions {
                print("- Document \(documentID): \(subscription.recordType) - \(subscription.predicate)")
            }
        }
        
        print("Active change streams:")
        if changeStreams.isEmpty {
            print("- No active change streams")
        } else {
            for (documentID, _) in changeStreams {
                print("- Document \(documentID): Change stream active")
            }
        }
    }
    
    // MARK: - Cleanup
    
    func stopRealTimeSync(for document: MindMapDocument) {
        // Remove subscription
        if let subscription = activeSubscriptions[document.id] {
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: nil, subscriptionIDsToDelete: [subscription.subscriptionID])
            database.add(operation)
            activeSubscriptions.removeValue(forKey: document.id)
        }
        
        // Close change stream
        changeStreams[document.id]?.finish()
        changeStreams.removeValue(forKey: document.id)
        
        // Stop presence monitoring
        presenceTimers[document.id]?.invalidate()
        presenceTimers.removeValue(forKey: document.id)
        
        // Clear live users for this document
        liveUsers.removeAll()
    }
}

// MARK: - User Presence
struct UserPresence {
    let userID: CKRecord.ID
    let displayName: String
    let cursorPosition: CGPoint?
    let lastSeen: Date
    let color: Color
}

// MARK: - CloudKit Extensions
extension CKShare.Participant {
    var displayName: String {
        return userIdentity.nameComponents?.formatted() ?? "Unknown User"
    }
}

// MARK: - Error Handling
enum CollaborationError: LocalizedError {
    case notAuthorized
    case networkUnavailable
    case shareNotFound
    case conflictResolutionFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Not authorized to access shared document"
        case .networkUnavailable:
            return "Network connection required for collaboration"
        case .shareNotFound:
            return "Shared document not found"
        case .conflictResolutionFailed:
            return "Failed to resolve editing conflicts"
        }
    }
}
