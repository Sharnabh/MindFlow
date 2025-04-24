import Foundation
import Combine

/// A client for making API requests to the MindFlow backend
class APIClient {
    private var baseURL: URL
    private var webSocketURL: URL?
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    /// Initialize the API client
    /// - Parameter baseURL: The base URL for the API (default: retrieved from Info.plist)
    init(baseURL: URL? = nil, webSocketURL: URL? = nil) {
        // Use provided URL or try to get from Info.plist
        if let url = baseURL {
            self.baseURL = url
        } else if let urlString = Bundle.main.infoDictionary?["APIBaseURL"] as? String,
                  let url = URL(string: urlString) {
            self.baseURL = url
        } else {
            // Default to local development URL instead of remote
            self.baseURL = URL(string: "http://localhost:3000/api")!
        }
        
        // Set WebSocket URL if provided, otherwise default to local WebSocket
        if let wsURL = webSocketURL {
            self.webSocketURL = wsURL
        } else {
            self.webSocketURL = URL(string: "ws://localhost:3000")
        }
        
        // Configure the URL session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
        
        // Configure JSON encoder/decoder
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        // Use ISO8601 date formatting
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        
        print("API Client configured for URL: \(self.baseURL.absoluteString)")
        if let wsURL = self.webSocketURL {
            print("WebSocket URL: \(wsURL.absoluteString)")
        }
    }
    
    /// Configure the client for local development server
    func configureForLocalServer() {
        self.baseURL = URL(string: "http://localhost:3000/api")!
        self.webSocketURL = URL(string: "ws://localhost:3000")
        print("API Client configured for local development server")
    }
    
    /// Get the WebSocket URL for real-time collaboration
    func getWebSocketURL() -> URL? {
        return webSocketURL
    }
    
    /// Make a GET request
    /// - Parameters:
    ///   - endpoint: The API endpoint (path after base URL)
    ///   - queryItems: Optional query parameters
    ///   - headers: Optional HTTP headers
    /// - Returns: A publisher that emits the decoded response or an error
    func get<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:]
    ) -> AnyPublisher<T, Error> {
        return request(
            endpoint: endpoint,
            method: "GET",
            queryItems: queryItems,
            headers: headers
        )
    }
    
    /// Make a POST request with dictionary
    /// - Parameters:
    ///   - endpoint: The API endpoint (path after base URL)
    ///   - body: The request body as a dictionary (more flexible than strict types)
    ///   - headers: Optional HTTP headers
    /// - Returns: A publisher that emits the decoded response or an error
    func post<T: Decodable>(
        endpoint: String,
        body: [String: Any],
        headers: [String: String] = [:]
    ) -> AnyPublisher<T, Error> {
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
            return request(
                endpoint: endpoint,
                method: "POST",
                headers: headers,
                body: bodyData
            )
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    /// Make a POST request returning a dictionary (for flexible response handling)
    /// - Parameters:
    ///   - endpoint: The API endpoint (path after base URL)
    ///   - body: The request body (dictionary format)
    ///   - headers: Optional HTTP headers
    /// - Returns: A publisher that emits a dictionary response or an error
    func post(
        endpoint: String,
        body: [String: Any],
        headers: [String: String] = [:]
    ) -> AnyPublisher<[String: Any], Error> {
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
            return requestDictionary(
                endpoint: endpoint,
                method: "POST",
                headers: headers,
                body: bodyData
            )
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    /// Make a GET request returning an array (for flexible response handling)
    /// - Parameters:
    ///   - endpoint: The API endpoint (path after base URL)
    ///   - queryItems: Optional query parameters
    ///   - headers: Optional HTTP headers
    /// - Returns: A publisher that emits an array response or an error
    func get(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:]
    ) -> AnyPublisher<[Any], Error> {
        return requestArray(
            endpoint: endpoint,
            method: "GET",
            queryItems: queryItems,
            headers: headers
        )
    }
    
    /// Make a PUT request
    /// - Parameters:
    ///   - endpoint: The API endpoint (path after base URL)
    ///   - body: The request body (will be JSON encoded)
    ///   - headers: Optional HTTP headers
    /// - Returns: A publisher that emits the decoded response or an error
    func put<T: Decodable, U: Encodable>(
        endpoint: String,
        body: U,
        headers: [String: String] = [:]
    ) -> AnyPublisher<T, Error> {
        do {
            let bodyData = try encoder.encode(body)
            return request(
                endpoint: endpoint,
                method: "PUT",
                headers: headers,
                body: bodyData
            )
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    /// Make a DELETE request
    /// - Parameters:
    ///   - endpoint: The API endpoint (path after base URL)
    ///   - headers: Optional HTTP headers
    /// - Returns: A publisher that emits the decoded response or an error
    func delete<T: Decodable>(
        endpoint: String,
        headers: [String: String] = [:]
    ) -> AnyPublisher<T, Error> {
        return request(
            endpoint: endpoint,
            method: "DELETE",
            headers: headers
        )
    }
    
    /// Make a network request with the specified parameters
    /// - Parameters:
    ///   - endpoint: The API endpoint (path after base URL)
    ///   - method: The HTTP method (GET, POST, etc.)
    ///   - queryItems: Optional query parameters
    ///   - headers: Optional HTTP headers
    ///   - body: Optional request body
    /// - Returns: A publisher that emits the decoded response or an error
    private func request<T: Decodable>(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        body: Data? = nil
    ) -> AnyPublisher<T, Error> {
        // Build the URL
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if it exists
        if let body = body {
            request.httpBody = body
        }
        
        // Make the request
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Try to parse error message from response
                    if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        throw RESTAPIError.serverError(
                            statusCode: httpResponse.statusCode,
                            message: errorResponse.message
                        )
                    } else {
                        throw RESTAPIError.serverError(
                            statusCode: httpResponse.statusCode,
                            message: "HTTP Error \(httpResponse.statusCode)"
                        )
                    }
                }
                
                return data
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { error -> Error in
                if let urlError = error as? URLError {
                    return RESTAPIError.networkError(urlError)
                } else if let apiError = error as? RESTAPIError {
                    return apiError
                } else if error is DecodingError {
                    return RESTAPIError.decodingError(error)
                } else {
                    return RESTAPIError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Make a network request and return the response as a dictionary
    /// - Parameters:
    ///   - endpoint: The API endpoint (path after base URL)
    ///   - method: The HTTP method (GET, POST, etc.)
    ///   - queryItems: Optional query parameters
    ///   - headers: Optional HTTP headers
    ///   - body: Optional request body
    /// - Returns: A publisher that emits a dictionary response or an error
    private func requestDictionary(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        body: Data? = nil
    ) -> AnyPublisher<[String: Any], Error> {
        // Build the URL
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if it exists
        if let body = body {
            request.httpBody = body
        }
        
        // Make the request
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Try to parse error message from response
                    if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        throw RESTAPIError.serverError(
                            statusCode: httpResponse.statusCode,
                            message: errorResponse.message
                        )
                    } else {
                        throw RESTAPIError.serverError(
                            statusCode: httpResponse.statusCode,
                            message: "HTTP Error \(httpResponse.statusCode)"
                        )
                    }
                }
                
                return data
            }
            .tryMap { data -> [String: Any] in
                guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw RESTAPIError.decodingError(
                        NSError(domain: "MindFlow.APIClient", code: 3, 
                        userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format"])
                    )
                }
                return jsonObject
            }
            .mapError { error -> Error in
                if let urlError = error as? URLError {
                    return RESTAPIError.networkError(urlError)
                } else if let apiError = error as? RESTAPIError {
                    return apiError
                } else {
                    return RESTAPIError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Make a network request and return the response as an array
    /// - Parameters:
    ///   - endpoint: The API endpoint (path after base URL)
    ///   - method: The HTTP method (GET, POST, etc.)
    ///   - queryItems: Optional query parameters
    ///   - headers: Optional HTTP headers
    ///   - body: Optional request body
    /// - Returns: A publisher that emits an array response or an error
    private func requestArray(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        body: Data? = nil
    ) -> AnyPublisher<[Any], Error> {
        // Build the URL
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if it exists
        if let body = body {
            request.httpBody = body
        }
        
        // Make the request
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Try to parse error message from response
                    if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        throw RESTAPIError.serverError(
                            statusCode: httpResponse.statusCode,
                            message: errorResponse.message
                        )
                    } else {
                        throw RESTAPIError.serverError(
                            statusCode: httpResponse.statusCode,
                            message: "HTTP Error \(httpResponse.statusCode)"
                        )
                    }
                }
                
                return data
            }
            .tryMap { data -> [Any] in
                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                    throw RESTAPIError.decodingError(
                        NSError(domain: "MindFlow.APIClient", code: 3, 
                        userInfo: [NSLocalizedDescriptionKey: "Invalid JSON array response format"])
                    )
                }
                return jsonArray
            }
            .mapError { error -> Error in
                if let urlError = error as? URLError {
                    return RESTAPIError.networkError(urlError)
                } else if let apiError = error as? RESTAPIError {
                    return apiError
                } else {
                    return RESTAPIError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
}

/// Custom API errors
enum RESTAPIError: Error, LocalizedError {
    case networkError(URLError)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let urlError):
            return "Network error: \(urlError.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

/// Standard error response from the API
struct APIErrorResponse: Codable {
    let error: Bool
    let message: String
} 