# Forma v2.0 - Cloud Storage Integration Roadmap

**Created:** December 2025
**Status:** Planning
**Estimated Effort:** 8-12 weeks (full multi-cloud) or 3-4 weeks (iCloud only)

---

## Executive Summary

This document outlines the execution plan for adding cloud storage integration to Forma. The current architecture is exceptionally well-prepared for this feature due to protocol-based services, Sendable value types, and the existing multi-folder pattern.

### Recommendation

**Start with iCloud Drive only for v2.0**, then add Dropbox/Google Drive in v2.1. This approach:
- Minimizes complexity (native APIs, no OAuth)
- Validates the abstraction layer
- Ships faster (3-4 weeks vs 10-12 weeks)
- Serves the majority of Mac users

---

## Difficulty Assessment

| Integration | Difficulty | Effort | Risk | Priority |
|-------------|-----------|--------|------|----------|
| **iCloud Drive** | Medium | 2-3 weeks | Low | v2.0 |
| **Dropbox** | Medium-High | 2-3 weeks | Medium | v2.1 |
| **Google Drive** | Medium-High | 2-3 weeks | Medium | v2.1 |
| **OneDrive** | High | 2-3 weeks | High | v2.2 |
| **Cross-cloud moves** | High | 2 weeks | Medium | v2.1 |

---

## Current Architecture Strengths

### Why Forma is Ready for Cloud Integration

1. **Protocol-based services** - `FileSystemServiceProtocol`, `Fileable`, `Ruleable` enable easy extension
2. **Sendable value types** - `FileMetadata` allows safe actor boundary crossing
3. **Multi-folder pattern** - `CustomFolderManager` already supports multiple source locations
4. **Security-scoped bookmarks** - `SecureBookmarkStore` pattern transfers to OAuth token storage
5. **Command pattern** - `UndoCommand` scales to multi-cloud undo operations
6. **Activity logging** - `ActivityItem` perfect for sync conflict resolution tracking

---

## Phase 1: Foundation (Week 1-2)

**Goal:** Abstract current code to support multiple providers without adding cloud functionality yet.

### New Files to Create

```
Services/Cloud/
├── CloudStorageProtocol.swift      # Abstract interface for all providers
├── CloudStorageService.swift       # Coordinator for multi-provider operations
├── LocalStorageProvider.swift      # Refactored from FileSystemService
└── Providers/
    └── (empty - populated in later phases)

Models/
├── CloudProvider.swift             # Enum: iCloud, dropbox, googleDrive, oneDrive
├── CloudDestination.swift          # Cloud-aware destination type
└── CloudFileMetadata.swift         # Protocol for cloud file metadata
```

### Protocol Design

```swift
protocol CloudStorageProtocol {
    var provider: CloudProvider { get }
    var isConnected: Bool { get }

    func connect() async throws
    func disconnect() async throws

    func scanDirectory(at path: String) async throws -> [CloudFileMetadata]
    func moveFile(from source: String, to destination: String) async throws
    func copyFile(from source: String, to destination: String) async throws
    func deleteFile(at path: String) async throws

    func downloadFile(at path: String, to localURL: URL) async throws
    func uploadFile(from localURL: URL, to path: String) async throws
}

protocol CloudFileMetadata {
    var id: String { get }
    var name: String { get }
    var path: String { get }
    var size: Int64 { get }
    var modifiedDate: Date { get }
    var isDirectory: Bool { get }
    var syncStatus: SyncStatus { get }
    var isPlaceholder: Bool { get }
    var provider: CloudProvider { get }
}

enum SyncStatus: String, Codable {
    case local          // Only exists locally
    case synced         // In sync with cloud
    case pending        // Waiting to sync
    case syncing        // Currently syncing
    case conflicted     // Conflict detected
    case error          // Sync error
}

enum CloudProvider: String, Codable, CaseIterable {
    case local
    case iCloud
    case dropbox
    case googleDrive
    case oneDrive
}
```

### Model Changes

```swift
// Extend Destination enum
enum Destination: Codable, Equatable {
    case trash
    case folder(bookmark: Data, displayName: String)
    case cloudFolder(
        provider: CloudProvider,
        cloudPath: String,
        displayName: String
    )
}

// Extend CustomFolder
@Model
class CustomFolder {
    // ... existing properties ...
    var cloudProvider: CloudProvider?
    var cloudPath: String?
}
```

---

## Phase 2: iCloud Drive (Week 3-4)

**Goal:** Full iCloud support as proof of concept.

### Why iCloud is Easiest

| Aspect | iCloud | Third-Party Clouds |
|--------|--------|-------------------|
| Authentication | Apple ID (automatic) | OAuth 2.0 flow required |
| File access | Local filesystem | REST API calls |
| Large files | Native | Chunked upload/download |
| Offline | Automatic | Manual queue management |
| SDK | None needed | External dependency |

### Implementation

```swift
// Services/Cloud/Providers/iCloudDriveProvider.swift
class iCloudDriveProvider: CloudStorageProtocol {
    let provider = CloudProvider.iCloud

    var iCloudContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
    }

    var isConnected: Bool {
        iCloudContainerURL != nil
    }

    func scanDirectory(at path: String) async throws -> [CloudFileMetadata] {
        guard let containerURL = iCloudContainerURL else {
            throw CloudStorageError.notConnected
        }

        let targetURL = containerURL.appendingPathComponent(path)
        let coordinator = NSFileCoordinator()

        return try await withCheckedThrowingContinuation { continuation in
            var error: NSError?
            coordinator.coordinate(readingItemAt: targetURL, error: &error) { url in
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [
                            .isRegularFileKey,
                            .fileSizeKey,
                            .contentModificationDateKey,
                            .isUbiquitousItemKey,
                            .ubiquitousItemDownloadingStatusKey
                        ]
                    )

                    let metadata = contents.compactMap { url -> iCloudFileMetadata? in
                        try? iCloudFileMetadata(url: url)
                    }

                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error = error {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### Handling .icloud Placeholder Files

```swift
struct iCloudFileMetadata: CloudFileMetadata {
    // ... standard properties ...

    var isPlaceholder: Bool {
        // Check if file is not downloaded
        let values = try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        return values?.ubiquitousItemDownloadingStatus == .notDownloaded
    }

    func triggerDownload() throws {
        try FileManager.default.startDownloadingUbiquitousItem(
            at: URL(fileURLWithPath: path)
        )
    }
}
```

### NSFileCoordinator Pattern

```swift
// RAII wrapper similar to existing SecurityScopedAccess
class CoordinatedAccess {
    private let coordinator: NSFileCoordinator
    private let url: URL
    private var isReading = false

    init(url: URL) {
        self.coordinator = NSFileCoordinator()
        self.url = url
    }

    func read<T>(_ block: (URL) throws -> T) throws -> T {
        var coordinatorError: NSError?
        var result: Result<T, Error>?

        coordinator.coordinate(readingItemAt: url, error: &coordinatorError) { coordinatedURL in
            do {
                result = .success(try block(coordinatedURL))
            } catch {
                result = .failure(error)
            }
        }

        if let error = coordinatorError {
            throw error
        }

        switch result {
        case .success(let value): return value
        case .failure(let error): throw error
        case .none: throw CloudStorageError.coordinationFailed
        }
    }
}
```

---

## Phase 3: Dropbox (Week 5-6)

**Goal:** First third-party integration, validates OAuth pattern.

### Dependencies

```swift
// Package.swift or Xcode SPM
dependencies: [
    .package(url: "https://github.com/dropbox/SwiftyDropbox", from: "10.0.0")
]
```

### OAuth Flow

```swift
// Services/Cloud/Auth/DropboxAuthManager.swift
import SwiftyDropbox

class DropboxAuthManager: ObservableObject {
    @Published var isAuthenticated = false

    func authenticate() async throws {
        // Configure with your app key
        DropboxClientsManager.setupWithAppKey("YOUR_APP_KEY")

        // Open OAuth flow
        let scopeRequest = ScopeRequest(
            scopeType: .user,
            scopes: ["files.content.read", "files.content.write"],
            includeGrantedScopes: false
        )

        DropboxClientsManager.authorizeFromControllerV2(
            NSApplication.shared,
            controller: nil,
            loadingStatusDelegate: nil,
            openURL: { url in NSWorkspace.shared.open(url) },
            scopeRequest: scopeRequest
        )
    }

    func handleRedirect(url: URL) -> Bool {
        let result = DropboxClientsManager.handleRedirectURL(url) { authResult in
            switch authResult {
            case .success(let token):
                self.storeToken(token)
                self.isAuthenticated = true
            case .cancel, .error:
                self.isAuthenticated = false
            case .none:
                break
            }
        }
        return result
    }

    private func storeToken(_ token: DropboxAccessToken) {
        // Use SecureBookmarkStore pattern for Keychain storage
        let tokenData = try? JSONEncoder().encode(token)
        SecureBookmarkStore.shared.saveToken(tokenData, for: "dropbox-oauth")
    }
}
```

### Dropbox Provider

```swift
// Services/Cloud/Providers/DropboxProvider.swift
class DropboxProvider: CloudStorageProtocol {
    let provider = CloudProvider.dropbox
    private var client: DropboxClient?

    var isConnected: Bool { client != nil }

    func connect() async throws {
        guard let tokenData = SecureBookmarkStore.shared.loadToken(for: "dropbox-oauth"),
              let token = try? JSONDecoder().decode(DropboxAccessToken.self, from: tokenData)
        else {
            throw CloudStorageError.notAuthenticated
        }

        client = DropboxClient(accessToken: token.accessToken)
    }

    func scanDirectory(at path: String) async throws -> [CloudFileMetadata] {
        guard let client = client else {
            throw CloudStorageError.notConnected
        }

        let response = try await client.files.listFolder(path: path).response()

        return response.entries.compactMap { entry -> DropboxFileMetadata? in
            guard let file = entry as? Files.FileMetadata else { return nil }
            return DropboxFileMetadata(from: file)
        }
    }

    func moveFile(from source: String, to destination: String) async throws {
        guard let client = client else {
            throw CloudStorageError.notConnected
        }

        _ = try await client.files.moveV2(
            fromPath: source,
            toPath: destination
        ).response()
    }
}
```

### Placeholder File Detection (Smart Sync)

```swift
struct DropboxFileMetadata: CloudFileMetadata {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let modifiedDate: Date
    let isDirectory: Bool
    let provider = CloudProvider.dropbox

    // Dropbox Smart Sync: check if file is "online only"
    var isPlaceholder: Bool {
        // On macOS, Dropbox creates extended attributes for smart sync
        let url = URL(fileURLWithPath: path)
        let attrs = try? url.resourceValues(forKeys: [.isUbiquitousItemKey])

        // If file exists locally but is very small, might be placeholder
        if let localSize = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64,
           localSize < size {
            return true
        }
        return false
    }
}
```

---

## Phase 4: Google Drive (Week 7-8)

**Goal:** Second third-party, validates abstraction works across providers.

### Dependencies

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/googleapis/google-api-swift-client", from: "0.1.0"),
    .package(url: "https://github.com/openid/AppAuth-iOS", from: "1.6.0")
]
```

### Key Differences from Dropbox

| Aspect | Dropbox | Google Drive |
|--------|---------|--------------|
| File IDs | Paths (`/folder/file.txt`) | Opaque IDs (`1BxiMVs0XRA5nFMdKvBd`) |
| Folder structure | Hierarchical | Files can have multiple parents |
| Native files | All downloadable | Google Docs need export |
| Scopes | Simpler | More granular |

### Google Drive Provider

```swift
// Services/Cloud/Providers/GoogleDriveProvider.swift
class GoogleDriveProvider: CloudStorageProtocol {
    let provider = CloudProvider.googleDrive
    private var service: GTLRDriveService?

    func scanDirectory(at path: String) async throws -> [CloudFileMetadata] {
        guard let service = service else {
            throw CloudStorageError.notConnected
        }

        // Google Drive uses folder IDs, not paths
        let folderId = try await resolveFolderId(for: path)

        let query = GTLRDriveQuery_FilesList.query()
        query.q = "'\(folderId)' in parents and trashed = false"
        query.fields = "files(id, name, size, modifiedTime, mimeType)"

        let result = try await service.execute(query)

        return result.files?.compactMap { file in
            GoogleDriveFileMetadata(from: file)
        } ?? []
    }

    // Handle Google Docs (not real files)
    private func isGoogleNativeFile(_ mimeType: String) -> Bool {
        mimeType.hasPrefix("application/vnd.google-apps.")
    }
}
```

---

## Phase 5: Cross-Cloud Operations (Week 9-10)

**Goal:** Enable moving files between different cloud providers.

### Operation Types

```
Source → Destination → Method
─────────────────────────────────────────
Local → Cloud       → Upload + delete local
Cloud → Local       → Download + delete remote
Cloud → Same Cloud  → Provider's move API
Cloud → Diff Cloud  → Download → Upload → Delete source
```

### Extended UndoCommand

```swift
struct CloudMoveCommand: UndoCommand {
    let sourceProvider: CloudProvider
    let sourcePath: String
    let destinationProvider: CloudProvider
    let destinationPath: String
    let timestamp: Date

    // For cross-cloud undo, we need to store the file temporarily
    var cachedFileURL: URL?

    func undo() async throws {
        if sourceProvider == destinationProvider {
            // Same provider - use native move
            let provider = CloudStorageService.shared.provider(for: sourceProvider)
            try await provider.moveFile(from: destinationPath, to: sourcePath)
        } else {
            // Cross-cloud - download from destination, upload to source
            let destProvider = CloudStorageService.shared.provider(for: destinationProvider)
            let srcProvider = CloudStorageService.shared.provider(for: sourceProvider)

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)

            try await destProvider.downloadFile(at: destinationPath, to: tempURL)
            try await srcProvider.uploadFile(from: tempURL, to: sourcePath)
            try await destProvider.deleteFile(at: destinationPath)

            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}
```

### Bandwidth & Progress

```swift
struct CloudTransferProgress: Sendable {
    let totalBytes: Int64
    let transferredBytes: Int64
    let currentFile: String
    let speed: Double // bytes per second

    var percentComplete: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }

    var estimatedTimeRemaining: TimeInterval? {
        guard speed > 0 else { return nil }
        let remaining = totalBytes - transferredBytes
        return TimeInterval(remaining) / speed
    }
}
```

---

## Phase 6: OneDrive (Optional, Week 11)

**Goal:** Complete the quad of major cloud providers.

### Why It's Hardest

1. **Microsoft Graph API** - More complex authentication
2. **Business vs Personal** - Different endpoints and behaviors
3. **Files On-Demand** - Unique placeholder system on macOS
4. **Conflict handling** - Different from other providers

### OneDrive-Specific Challenges

```swift
// Files On-Demand detection
func isOneDrivePlaceholder(at url: URL) -> Bool {
    // OneDrive uses extended attributes
    let attrs = try? url.resourceValues(forKeys: [
        URLResourceKey(rawValue: "NSURLIsCloudPlaceholderItemKey")
    ])
    return attrs?.allValues["NSURLIsCloudPlaceholderItemKey"] as? Bool ?? false
}
```

---

## Key Decisions Required

### 1. Sync Strategy

```swift
enum CloudSyncStrategy: String, Codable, CaseIterable {
    case onDemand       // Only scan when user requests
    case periodic       // Background scan every N minutes
    case realTime       // File presenters watch for changes
}

// Recommended: Start with onDemand, add realTime in v2.1
```

### 2. Placeholder Handling

```swift
enum PlaceholderPolicy: String, Codable {
    case showAsPending       // Show in list, download when organizing
    case hideUntilDownloaded // Filter out placeholders
    case downloadDuringScan  // Auto-download during scan (slow!)
}

// Recommended: showAsPending - transparent to user
```

### 3. Conflict Resolution

```swift
enum ConflictResolution: String, Codable {
    case keepLocal      // Local version wins
    case keepCloud      // Cloud version wins
    case keepBoth       // Rename local with suffix
    case askUser        // Show modal dialog
}

// Recommended: askUser for transparency
```

### 4. Offline Behavior

```swift
enum OfflinePolicy: String, Codable {
    case queueOperations    // Queue moves, execute when online
    case blockOperations    // Disable cloud moves when offline
    case localFallback      // Move to local staging folder
}

// Recommended: queueOperations with visual indicator
```

---

## UI Changes Required

### Settings View

```swift
// New section in SettingsView
Section("Cloud Storage") {
    CloudConnectionRow(provider: .iCloud, isConnected: vm.iCloudConnected)
    CloudConnectionRow(provider: .dropbox, isConnected: vm.dropboxConnected)
    CloudConnectionRow(provider: .googleDrive, isConnected: vm.googleDriveConnected)
    CloudConnectionRow(provider: .oneDrive, isConnected: vm.oneDriveConnected)
}
```

### Sidebar

```swift
// Add cloud sources to sidebar
Section("Cloud Storage") {
    if vm.iCloudConnected {
        FolderRow(name: "iCloud Drive", icon: "icloud", provider: .iCloud)
    }
    if vm.dropboxConnected {
        FolderRow(name: "Dropbox", icon: "dropbox", provider: .dropbox)
    }
    // ...
}
```

### Conflict Resolution Sheet

```swift
struct ConflictResolutionSheet: View {
    let conflicts: [FileConflict]
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            Text("Sync Conflicts Detected")
                .font(.headline)

            ForEach(conflicts) { conflict in
                ConflictRow(conflict: conflict)
            }

            HStack {
                Button("Keep All Local") { resolveAll(.keepLocal) }
                Button("Keep All Cloud") { resolveAll(.keepCloud) }
                Button("Review Each") { showDetailedReview() }
            }
        }
    }
}
```

---

## Security Considerations

### Token Storage

```swift
// Extend SecureBookmarkStore for cloud tokens
extension SecureBookmarkStore {
    func saveCloudToken(_ token: Data, for provider: CloudProvider) throws {
        let key = "cloud-token-\(provider.rawValue)"
        try save(token, forKey: key)
    }

    func loadCloudToken(for provider: CloudProvider) -> Data? {
        let key = "cloud-token-\(provider.rawValue)"
        return load(forKey: key)
    }

    func deleteCloudToken(for provider: CloudProvider) throws {
        let key = "cloud-token-\(provider.rawValue)"
        try delete(forKey: key)
    }
}
```

### Token Refresh

```swift
// Proactive token refresh to prevent mid-operation failures
class TokenRefreshManager {
    func refreshIfNeeded(for provider: CloudProvider) async throws {
        guard let token = loadToken(for: provider) else { return }

        // Refresh if expiring within 5 minutes
        if token.expiresAt < Date().addingTimeInterval(300) {
            let newToken = try await refreshToken(token, provider: provider)
            try saveToken(newToken, for: provider)
        }
    }
}
```

### Permissions Model

```swift
// Cloud-specific permissions
struct CloudPermissions {
    let canRead: Bool
    let canWrite: Bool
    let canDelete: Bool
    let canShare: Bool

    static func from(scopes: [String], provider: CloudProvider) -> CloudPermissions {
        // Map OAuth scopes to permissions
        switch provider {
        case .dropbox:
            return CloudPermissions(
                canRead: scopes.contains("files.content.read"),
                canWrite: scopes.contains("files.content.write"),
                canDelete: scopes.contains("files.content.write"),
                canShare: scopes.contains("sharing.write")
            )
        // ...
        }
    }
}
```

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| OAuth token expiry mid-operation | Medium | High | Proactive refresh, retry logic |
| Rate limiting (Dropbox/Google) | High | Medium | Exponential backoff, request queue |
| Large file transfer failures | Medium | High | Chunked transfer, resume support |
| Sync conflicts | Medium | Medium | Clear UI, activity log, user choice |
| API breaking changes | Low | High | Abstract behind protocol, version checks |
| Network interruption | High | Medium | Offline queue, retry on reconnect |

---

## Testing Strategy

### Unit Tests

```swift
// Mock providers for testing
class MockCloudProvider: CloudStorageProtocol {
    var files: [String: CloudFileMetadata] = [:]
    var shouldFail = false
    var latency: TimeInterval = 0

    func scanDirectory(at path: String) async throws -> [CloudFileMetadata] {
        if shouldFail { throw CloudStorageError.networkError }
        try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
        return files.values.filter { $0.path.hasPrefix(path) }
    }
}
```

### Integration Tests

```swift
// Test cross-cloud operations
func testCrossCloudMove() async throws {
    let dropbox = MockCloudProvider()
    let googleDrive = MockCloudProvider()

    dropbox.files["test.txt"] = MockFileMetadata(name: "test.txt")

    let service = CloudStorageService(providers: [dropbox, googleDrive])
    try await service.moveFile(
        from: CloudPath(provider: .dropbox, path: "test.txt"),
        to: CloudPath(provider: .googleDrive, path: "test.txt")
    )

    XCTAssertNil(dropbox.files["test.txt"])
    XCTAssertNotNil(googleDrive.files["test.txt"])
}
```

---

## Timeline Summary

### v2.0 (iCloud Only) - 3-4 Weeks

| Week | Milestone |
|------|-----------|
| 1 | CloudStorageProtocol foundation, LocalStorageProvider refactor |
| 2 | iCloudDriveProvider implementation |
| 3 | UI integration (sidebar, settings, destination picker) |
| 4 | Testing, conflict resolution, polish |

### v2.1 (Multi-Cloud) - 6-8 Additional Weeks

| Week | Milestone |
|------|-----------|
| 5-6 | Dropbox integration + OAuth |
| 7-8 | Google Drive integration |
| 9-10 | Cross-cloud operations |
| 11 | OneDrive (optional) |
| 12 | Polish, documentation, release |

---

## Open Questions

1. **Subscription model?** Should cloud integration be a premium feature?
2. **Which clouds first?** iCloud is easiest, but Dropbox might have higher demand
3. **Conflict UI complexity?** Simple keep-local/keep-cloud vs detailed diff view
4. **Offline queue visibility?** Show pending operations or hide complexity?
5. **Bandwidth controls?** Should users be able to throttle cloud transfers?

---

## References

- [Apple File Coordination](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
- [Dropbox Swift SDK](https://github.com/dropbox/SwiftyDropbox)
- [Google Drive API](https://developers.google.com/drive/api/guides/about-sdk)
- [Microsoft Graph API](https://docs.microsoft.com/en-us/graph/api/resources/onedrive)
- [Forma Security Docs](../Security/README.md)
- [Forma Architecture](../Architecture/ARCHITECTURE.md)
