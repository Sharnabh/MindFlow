import Foundation
import Combine

/// Service responsible for document sharing and collaboration features
class DocumentSharingService {
    private let apiClient: APIClient
    private let authService: AuthenticationService
    
    init(apiClient: APIClient, authService: AuthenticationService) {
        self.apiClient = apiClient
        self.authService = authService
    }
    
    /// Create a shareable link for a document
    /// - Parameters:
    ///   - documentId: The ID of the document to share
    ///   - accessLevel: The access level to grant via this link
    ///   - expirationDays: Optional number of days until the link expires (nil = no expiration)
    /// - Returns: A publisher that emits the share link URL or an error
    func createShareLink(documentId: String, 
                         accessLevel: DocumentAccessLevel,
                         expirationDays: Int? = 30) -> AnyPublisher<String, Error> {
        guard let currentUser = authService.currentUser else {
            return Fail(error: NSError(
                domain: "MindFlow.DocumentSharingService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )).eraseToAnyPublisher()
        }
        
        let sharingRequest = SharingRequest(
            documentId: documentId,
            accessLevel: accessLevel,
            expirationDays: expirationDays
        )
        
        return apiClient.post(
            endpoint: "documents/\(documentId)/share",
            body: sharingRequest,
            headers: ["Authorization": "Bearer \(currentUser.id)"]
        )
        .map { (response: ShareLinkResponse) -> String in
            return response.shareLink
        }
        .eraseToAnyPublisher()
    }
    
    /// Start a collaborative session for a document
    /// - Parameter documentId: The ID of the document to collaborate on
    /// - Returns: A publisher that emits the session info or an error
    func startCollaborativeSession(documentId: String) -> AnyPublisher<CollaborativeSession, Error> {
        guard let currentUser = authService.currentUser else {
            return Fail(error: NSError(
                domain: "MindFlow.DocumentSharingService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )).eraseToAnyPublisher()
        }
        
        return apiClient.post(
            endpoint: "documents/\(documentId)/collaborate/start",
            body: ["userId": currentUser.id],
            headers: ["Authorization": "Bearer \(currentUser.id)"]
        )
        .eraseToAnyPublisher()
    }
    
    /// Get a document from a share link
    /// - Parameter link: The share link URL
    /// - Returns: A publisher that emits the shared document or an error
    func getDocumentFromShareLink(link: String) -> AnyPublisher<SharedDocument, Error> {
        let linkId = extractLinkId(from: link)
        
        var headers: [String: String] = [:]
        if let currentUser = authService.currentUser {
            headers["Authorization"] = "Bearer \(currentUser.id)"
        }
        
        return apiClient.get(
            endpoint: "shared/\(linkId)",
            headers: headers
        )
        .eraseToAnyPublisher()
    }
    
    /// Invite a user to collaborate on a document
    /// - Parameters:
    ///   - email: The email address of the user to invite
    ///   - documentId: The ID of the document to share
    ///   - accessLevel: The access level to grant to the invited user
    /// - Returns: A publisher that emits a boolean success value or an error
    func inviteUserToDocument(email: String, 
                              documentId: String, 
                              accessLevel: DocumentAccessLevel) -> AnyPublisher<Bool, Error> {
        guard let currentUser = authService.currentUser else {
            return Fail(error: NSError(
                domain: "MindFlow.DocumentSharingService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )).eraseToAnyPublisher()
        }
        
        let inviteRequest = InviteRequest(
            email: email,
            documentId: documentId,
            accessLevel: accessLevel,
            invitedBy: currentUser.id
        )
        
        return apiClient.post(
            endpoint: "documents/\(documentId)/invite",
            body: inviteRequest,
            headers: ["Authorization": "Bearer \(currentUser.id)"]
        )
        .map { (_: InviteResponse) -> Bool in
            return true
        }
        .eraseToAnyPublisher()
    }
    
    /// Get the list of collaborators for a document
    /// - Parameter documentId: The ID of the document
    /// - Returns: A publisher that emits the list of collaborators or an error
    func getDocumentCollaborators(documentId: String) -> AnyPublisher<[DocumentCollaborator], Error> {
        guard let currentUser = authService.currentUser else {
            return Fail(error: NSError(
                domain: "MindFlow.DocumentSharingService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )).eraseToAnyPublisher()
        }
        
        return apiClient.get(
            endpoint: "documents/\(documentId)/collaborators",
            headers: ["Authorization": "Bearer \(currentUser.id)"]
        )
        .eraseToAnyPublisher()
    }
    
    /// Update a collaborator's access level
    /// - Parameters:
    ///   - userId: The user ID of the collaborator
    ///   - documentId: The document ID
    ///   - accessLevel: The new access level
    /// - Returns: A publisher that emits a boolean success value or an error
    func updateCollaboratorAccess(userId: String, 
                                  documentId: String, 
                                  accessLevel: DocumentAccessLevel) -> AnyPublisher<Bool, Error> {
        guard let currentUser = authService.currentUser else {
            return Fail(error: NSError(
                domain: "MindFlow.DocumentSharingService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )).eraseToAnyPublisher()
        }
        
        let updateRequest = UpdateAccessRequest(
            userId: userId,
            accessLevel: accessLevel
        )
        
        return apiClient.put(
            endpoint: "documents/\(documentId)/collaborators/\(userId)",
            body: updateRequest,
            headers: ["Authorization": "Bearer \(currentUser.id)"]
        )
        .map { (_: EmptyResponse) -> Bool in
            return true
        }
        .eraseToAnyPublisher()
    }
    
    /// Remove a collaborator from a document
    /// - Parameters:
    ///   - userId: The user ID of the collaborator to remove
    ///   - documentId: The document ID
    /// - Returns: A publisher that emits a boolean success value or an error
    func removeCollaborator(userId: String, documentId: String) -> AnyPublisher<Bool, Error> {
        guard let currentUser = authService.currentUser else {
            return Fail(error: NSError(
                domain: "MindFlow.DocumentSharingService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )).eraseToAnyPublisher()
        }
        
        return apiClient.delete(
            endpoint: "documents/\(documentId)/collaborators/\(userId)",
            headers: ["Authorization": "Bearer \(currentUser.id)"]
        )
        .map { (_: EmptyResponse) -> Bool in
            return true
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func extractLinkId(from link: String) -> String {
        // Extract the link ID from the full URL
        if let url = URL(string: link),
           let lastComponent = url.pathComponents.last {
            return lastComponent
        }
        
        // If we can't parse the URL, just return the original string
        // The server will handle invalid formats
        return link
    }
}

// MARK: - Request/Response Models

/// Request to create a share link
struct SharingRequest: Codable {
    let documentId: String
    let accessLevel: DocumentAccessLevel
    let expirationDays: Int?
}

/// Response with the share link
struct ShareLinkResponse: Codable {
    let shareLink: String
    let accessLevel: DocumentAccessLevel
    let expiration: Date?
}

/// Shared document info
struct SharedDocument: Codable {
    let id: String
    let title: String
    let creatorName: String
    let createdAt: Date
    let lastModified: Date
    let accessLevel: DocumentAccessLevel
    let topicCount: Int
    let thumbnailURL: URL?
}

/// Request to invite a user
struct InviteRequest: Codable {
    let email: String
    let documentId: String
    let accessLevel: DocumentAccessLevel
    let invitedBy: String
}

/// Response from an invite
struct InviteResponse: Codable {
    let success: Bool
    let message: String
}

/// Information about a document collaborator
struct DocumentCollaborator: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let photoURL: URL?
    let accessLevel: DocumentAccessLevel
    let joinedAt: Date
    let lastActive: Date?
    let invitedBy: String?
    let status: CollaboratorStatus
    
    enum CollaboratorStatus: String, Codable {
        case active
        case invited
        case removed
    }
}

/// Request to update a collaborator's access
struct UpdateAccessRequest: Codable {
    let userId: String
    let accessLevel: DocumentAccessLevel
}

/// Empty response for operations that don't return data
struct EmptyResponse: Codable {
    let success: Bool
} 
