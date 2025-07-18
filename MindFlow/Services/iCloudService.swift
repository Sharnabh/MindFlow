import Foundation
import CoreServices
import UniformTypeIdentifiers
import SwiftUI

// Protocol for iCloud operations
protocol iCloudServiceProtocol {
    func setupiCloud() async throws
    func saveToiCloud(document: MindMapDocument) async throws -> URL
    func loadFromiCloud(url: URL) async throws -> [Topic]
    func getiCloudDocuments() async throws -> [URL]
    func deleteiCloudDocument(at url: URL) async throws
    func checkiCloudAvailability() -> Bool
    func monitorDocumentStatus(at url: URL) -> AsyncStream<iCloudDocumentStatus>
}

// iCloud document status
enum iCloudDocumentStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case uploading(progress: Double)
    case conflict
    case error(String)
}

// Main iCloud service implementation
class iCloudService: iCloudServiceProtocol, ObservableObject {
    static let shared = iCloudService()
    
    @Published var isAvailable: Bool = false
    @Published var documents: [URL] = []
    @Published var syncStatus: [URL: iCloudDocumentStatus] = [:]
    
    private var ubiquityContainerURL: URL?
    private var documentsQuery: NSMetadataQuery?
    
    private init() {
        setupiCloudMonitoring()
    }
    
    // MARK: - Setup and Configuration
    
    func setupiCloud() async throws {
        // Check if iCloud is available
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            print("iCloud container not available")
            throw iCloudError.notAvailable
        }
        
        print("iCloud container URL: \(containerURL)")
        ubiquityContainerURL = containerURL
        
        // Create Documents directory if it doesn't exist
        let documentsURL = containerURL.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        print("iCloud Documents directory created/verified at: \(documentsURL)")
        
        await MainActor.run {
            isAvailable = true
        }
        
        // Start monitoring documents
        try await startDocumentQuery()
        print("iCloud setup completed successfully")
    }
    
    private func setupiCloudMonitoring() {
        // Check iCloud availability periodically
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.updateiCloudAvailability()
            }
        }
    }
    
    @MainActor
    private func updateiCloudAvailability() {
        let wasAvailable = isAvailable
        isAvailable = checkiCloudAvailability()
        
        if isAvailable && !wasAvailable {
            // iCloud became available
            Task {
                try? await setupiCloud()
            }
        }
    }
    
    // MARK: - iCloud Operations
    
    func checkiCloudAvailability() -> Bool {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }
    
    func saveToiCloud(document: MindMapDocument) async throws -> URL {
        guard let containerURL = ubiquityContainerURL else {
            print("iCloud container not available for saving")
            throw iCloudError.notAvailable
        }
        
        let documentsURL = containerURL.appendingPathComponent("Documents")
        let fileURL = documentsURL.appendingPathComponent(document.filename)
        print("Saving document to iCloud: \(fileURL)")
        
        // Update sync status
        await MainActor.run {
            syncStatus[fileURL] = .uploading(progress: 0.0)
        }
        
        do {
            // Encode topics
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document.topics)
            
            // Write to iCloud
            try data.write(to: fileURL)
            print("Successfully saved document to iCloud: \(document.filename)")
            
            // Mark as uploaded
            await MainActor.run {
                syncStatus[fileURL] = .downloaded
            }
            
            return fileURL
        } catch {
            print("Failed to save document to iCloud: \(error)")
            await MainActor.run {
                syncStatus[fileURL] = .error(error.localizedDescription)
            }
            throw error
        }
    }
    
    func loadFromiCloud(url: URL) async throws -> [Topic] {
        // Check if file needs to be downloaded
        var resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus
        
        if downloadStatus != .current {
            // Start download
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
            
            // Wait for download to complete
            try await waitForDownload(url: url)
        }
        
        // Read the file
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([Topic].self, from: data)
    }
    
    private func waitForDownload(url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    if resourceValues.ubiquitousItemDownloadingStatus == .current {
                        timer.invalidate()
                        continuation.resume()
                    }
                } catch {
                    timer.invalidate()
                    continuation.resume(throwing: error)
                }
            }
            
            // Timeout after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                timer.invalidate()
                continuation.resume(throwing: iCloudError.downloadTimeout)
            }
        }
    }
    
    func getiCloudDocuments() async throws -> [URL] {
        guard let containerURL = ubiquityContainerURL else {
            throw iCloudError.notAvailable
        }
        
        let documentsURL = containerURL.appendingPathComponent("Documents")
        let contents = try FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.nameKey, .ubiquitousItemDownloadingStatusKey],
            options: .skipsHiddenFiles
        )
        
        return contents.filter { url in
            url.pathExtension == "mindflow"
        }
    }
    
    func deleteiCloudDocument(at url: URL) async throws {
        try FileManager.default.removeItem(at: url)
        
        await MainActor.run {
            syncStatus.removeValue(forKey: url)
            documents.removeAll { $0 == url }
        }
    }
    
    // MARK: - Document Monitoring
    
    private func startDocumentQuery() async throws {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.mindflow'", NSMetadataItemFSNameKey)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        
        query.start()
        documentsQuery = query
    }
    
    @objc private func queryDidUpdate() {
        guard let query = documentsQuery else { return }
        
        query.disableUpdates()
        
        var newDocuments: [URL] = []
        var newSyncStatus: [URL: iCloudDocumentStatus] = [:]
        
        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                continue
            }
            
            newDocuments.append(url)
            
            // Determine sync status using correct NSMetadata attributes
            // Check if the file is downloaded locally
            if let isDownloaded = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                switch isDownloaded {
                case "Downloaded":
                    newSyncStatus[url] = .downloaded
                case "Downloading":
                    // Try to get download progress if available
                    let progress = (item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.doubleValue ?? 0.0
                    newSyncStatus[url] = .downloading(progress: progress / 100.0)
                case "NotDownloaded":
                    newSyncStatus[url] = .notDownloaded
                default:
                    // Default to downloaded if we can see the item
                    newSyncStatus[url] = .downloaded
                }
            } else {
                // Fallback: if we can query the item, assume it's available
                newSyncStatus[url] = .downloaded
            }
        }
        
        query.enableUpdates()
        
        DispatchQueue.main.async {
            self.documents = newDocuments
            self.syncStatus.merge(newSyncStatus) { _, new in new }
        }
    }
    
    func monitorDocumentStatus(at url: URL) -> AsyncStream<iCloudDocumentStatus> {
        AsyncStream { continuation in
            // Initial status
            continuation.yield(syncStatus[url] ?? .notDownloaded)
            
            // Monitor changes
            let observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidUpdate,
                object: documentsQuery,
                queue: .main
            ) { _ in
                if let status = self.syncStatus[url] {
                    continuation.yield(status)
                }
            }
            
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    deinit {
        documentsQuery?.stop()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Error Handling

enum iCloudError: LocalizedError {
    case notAvailable
    case downloadTimeout
    case uploadFailed
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud is not available. Please check your iCloud settings."
        case .downloadTimeout:
            return "Download from iCloud timed out."
        case .uploadFailed:
            return "Failed to upload to iCloud."
        case .accessDenied:
            return "Access to iCloud was denied."
        }
    }
}
