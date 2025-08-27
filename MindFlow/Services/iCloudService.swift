import Foundation
import CoreServices
import UniformTypeIdentifiers
import SwiftUI
#if os(macOS)
import AppKit
#endif

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
    private let containerIdentifier = "iCloud.com.sharnabhB.MindFlow"
    
    private init() {
        setupiCloudMonitoring()
    }
    
    // MARK: - Setup and Configuration
    
    func setupiCloud() async throws {
        // Resolve the iCloud container (prefer explicit identifier, fallback to nil)
        let fm = FileManager.default
        let containerURL = fm.url(forUbiquityContainerIdentifier: containerIdentifier)
            ?? fm.url(forUbiquityContainerIdentifier: nil)
        guard let containerURL else {
            print("iCloud container not available for identifier: \(containerIdentifier)")
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
        
        // Start monitoring documents with error handling
        do {
            try await startDocumentQuery()
            print("iCloud setup completed successfully")
        } catch {
            print("iCloud setup completed with limited monitoring due to: \(error)")
            // Basic iCloud functionality will still work even if monitoring fails
        }
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
    let fm = FileManager.default
    return fm.url(forUbiquityContainerIdentifier: containerIdentifier) != nil ||
           fm.url(forUbiquityContainerIdentifier: nil) != nil
    }
    
    func saveToiCloud(document: MindMapDocument) async throws -> URL {
        guard let containerURL = ubiquityContainerURL else {
            print("iCloud container not available for saving")
            throw iCloudError.notAvailable
        }
        
        let documentsURL = containerURL.appendingPathComponent("Documents")
        // Ensure the file has the correct extension so it shows up in queries and Finder
        let ensuredFilename: String = {
            let lower = document.filename.lowercased()
            return lower.hasSuffix(".mindflow") ? document.filename : document.filename + ".mindflow"
        }()
        let fileURL = documentsURL.appendingPathComponent(ensuredFilename)
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
            
            // Write to a temporary local file first
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let tempURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mindflow")
            try data.write(to: tempURL, options: .atomic)
            
            // If a file already exists at destination, remove it to avoid setUbiquitous failure
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            // Move into iCloud using setUbiquitous for proper iCloud indexing and visibility
            try FileManager.default.setUbiquitous(true, itemAt: tempURL, destinationURL: fileURL)
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
    
    // Expose the iCloud Documents URL for UI helpers
    func icloudDocumentsURL() -> URL? {
        guard let containerURL = ubiquityContainerURL else { return nil }
        return containerURL.appendingPathComponent("Documents")
    }
    
    // Convenience to reveal the iCloud folder in Finder on macOS
    #if os(macOS)
    @MainActor
    func revealICloudDocumentsInFinder() {
        guard let url = icloudDocumentsURL() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    #endif
    
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
        // Ensure directory exists
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        
        // Try direct listing first
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.nameKey, .ubiquitousItemDownloadingStatusKey],
                options: .skipsHiddenFiles
            )
            let files = contents.filter { $0.pathExtension == "mindflow" }
            await MainActor.run { self.documents = files }
            return files
        } catch {
            print("Direct iCloud listing failed: \(error). Falling back to metadata query snapshot.")
            // Fallback to current query snapshot if available
            if let query = documentsQuery {
                var urls: [URL] = []
                for i in 0..<query.resultCount {
                    if let item = query.result(at: i) as? NSMetadataItem,
                       let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                       url.pathExtension == "mindflow" {
                        urls.append(url)
                    }
                }
                await MainActor.run { self.documents = urls }
                return urls
            }
            throw error
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        
        // Start query with error handling
        do {
            query.start()
            documentsQuery = query
            print("Started iCloud document monitoring")
        } catch {
            print("Warning: Could not start iCloud document monitoring: \(error)")
            // Continue without monitoring - basic iCloud functionality will still work
        }
    }
    
    @objc private func queryDidFinishGathering() {
        print("iCloud document query finished initial gathering")
        queryDidUpdate()
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
            
            // Simplified sync status detection to avoid permission issues
            do {
                // Try to access the file to determine if it's available
                let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    newSyncStatus[url] = .downloaded
                } else {
                    newSyncStatus[url] = .notDownloaded
                }
            } catch {
                // If we can't read the resource values, assume it needs download
                print("Warning: Could not read resource values for \(url.lastPathComponent): \(error)")
                newSyncStatus[url] = .notDownloaded
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
