import Foundation
import Combine

/// Represents the current state of the collaboration WebSocket connection
enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(Error)
}

/// Service responsible for managing real-time collaboration via WebSockets
class CollaborationService: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var collaborators: [Collaborator] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var cancellables = Set<AnyCancellable>()
    
    private var documentId: String?
    private var authToken: String?
    private var serverURL: URL?
    
    init() {
        // Load server URL from configuration
        if let serverURLString = Bundle.main.infoDictionary?["CollaborationServerURL"] as? String,
           let url = URL(string: serverURLString) {
            self.serverURL = url
            print("Using configured server URL: \(serverURLString)")
        } else {
            // Default URL for development
            self.serverURL = URL(string: "ws://localhost:3000")
            print("Using default development server URL: ws://localhost:3000")
        }
    }
    
    /// Connects to a collaborative document session
    func connect(to documentId: String, authToken: String) {
        self.documentId = documentId
        self.authToken = authToken
        self.connectionState = .connecting
        
        // Get WebSocket URL from APIClient
        if let serverURL = DependencyContainer.shared.makeAPIClient().getWebSocketURL() {
            // Build the connection URL - FIXED: remove /documents/ path segment which is causing 404
            let urlString = "\(serverURL.absoluteString)"
            if let url = URL(string: urlString) {
                // Close existing connection if it exists
                webSocketTask?.cancel(with: .goingAway, reason: nil)
                
                // Create session if needed
                if session == nil {
                    session = URLSession(configuration: .default)
                }
                
                // In development mode, use different authentication
                #if DEBUG
                print("Creating WebSocket connection to \(url) with userId: \(authToken)")
                
                // Add userId and documentId as query parameters in development mode
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = [
                    URLQueryItem(name: "userId", value: authToken),
                    URLQueryItem(name: "documentId", value: documentId)
                ]
                let urlWithAuth = components?.url ?? url
                
                webSocketTask = session?.webSocketTask(with: urlWithAuth)
                #else
                // For production, use Bearer token auth
                var request = URLRequest(url: url)
                request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                webSocketTask = session?.webSocketTask(with: request)
                #endif
                
                // Set up receive message handling
                receiveMessage()
                
                // Connect to the server
                webSocketTask?.resume()
                
                // After connection is established, send a message to join the document
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.sendJoinDocumentMessage(documentId)
                }
                
                // Ping to keep connection alive
                startPingTimer()
            } else {
                let error = NSError(
                    domain: "MindFlow.CollaborationService",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid WebSocket URL constructed"]
                )
                self.connectionState = .failed(error)
            }
        } else {
            let error = NSError(
                domain: "MindFlow.CollaborationService",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Missing WebSocket server URL"]
            )
            self.connectionState = .failed(error)
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingMessage(text)
                case .data(let data):
                    self.handleIncomingData(data)
                @unknown default:
                    print("Unknown message type received")
                }
                
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.connectionState = .failed(error)
                }
                self.attemptReconnect()
            }
        }
    }
    
    private func handleIncomingMessage(_ text: String) {
        // Parse the message
        if let data = text.data(using: .utf8) {
            do {
                let message = try JSONDecoder().decode(CollaborationMessage.self, from: data)
                processMessage(message)
            } catch {
                print("Error decoding message: \(error)")
            }
        }
    }
    
    private func handleIncomingData(_ data: Data) {
        do {
            let message = try JSONDecoder().decode(CollaborationMessage.self, from: data)
            processMessage(message)
        } catch {
            print("Error decoding message data: \(error)")
        }
    }
    
    private func processMessage(_ message: CollaborationMessage) {
        DispatchQueue.main.async {
            switch message.type {
            case .topicChange:
                if let change = message.payload as? TopicChange {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RemoteTopicChange"),
                        object: nil,
                        userInfo: ["change": change]
                    )
                }
                
            case .userJoined:
                if let user = message.payload as? Collaborator {
                    self.collaborators.append(user)
                }
                
            case .userLeft:
                if let userId = message.payload as? String {
                    self.collaborators.removeAll { $0.id == userId }
                }
                
            case .error:
                if let errorMessage = message.payload as? String {
                    print("Server error: \(errorMessage)")
                }
                
            case .connectionEstablished:
                self.connectionState = .connected
                self.reconnectAttempts = 0
            }
        }
    }
    
    /// Sends a topic change to all collaborators
    func sendChange(_ change: TopicChange) {
        guard let currentUser = DependencyContainer.shared.makeAuthService().currentUser else {
            print("Cannot send change: No authenticated user")
            return
        }
        
        let message = CollaborationMessage(
            type: .topicChange,
            senderId: currentUser.id,
            timestamp: Date(),
            payload: change
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(message)
            
            webSocketTask?.send(.data(data)) { error in
                if let error = error {
                    print("Error sending message: \(error)")
                }
            }
        } catch {
            print("Error encoding message: \(error)")
        }
    }
    
    private func startPingTimer() {
        // Cancel existing timer if any
        reconnectTimer?.invalidate()
        
        // Create a new timer
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.ping()
        }
    }
    
    private func ping() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("Ping failed: \(error)")
                self?.attemptReconnect()
            }
        }
    }
    
    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            DispatchQueue.main.async {
                self.connectionState = .failed(NSError(
                    domain: "MindFlow.CollaborationService", 
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Max reconnection attempts reached"]
                ))
            }
            return
        }
        
        DispatchQueue.main.async {
            self.connectionState = .reconnecting
        }
        reconnectAttempts += 1
        
        // Use exponential backoff for reconnection
        let delay = pow(2.0, Double(reconnectAttempts)) * 1.0
        
        // Cancel existing timer
        reconnectTimer?.invalidate()
        
        // Create a new timer for a single reconnection attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect(to: self?.documentId ?? "", authToken: self?.authToken ?? "")
        }
    }
    
    /// Disconnects from the current collaborative session
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
        reconnectTimer?.invalidate()
        reconnectAttempts = 0
    }
    
    /// Send a message to join a specific document
    private func sendJoinDocumentMessage(_ documentId: String) {
        guard let currentUser = DependencyContainer.shared.makeAuthService().currentUser else {
            print("Cannot join document: No authenticated user")
            return
        }
        
        // Create a join document message for Socket.io
        do {
            // Send as a string message for Socket.io
            webSocketTask?.send(.string(documentId)) { error in
                if let error = error {
                    print("Error sending join document message: \(error)")
                } else {
                    print("Join document message sent for document: \(documentId)")
                }
            }
        } catch {
            print("Error preparing join document message: \(error)")
        }
    }
    
    deinit {
        disconnect()
    }
} 
