import AppKit
import CryptoKit
import Darwin
import QuickLookThumbnailing

// MARK: - Debug Logging Helper (temporary)

private func debugLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] \(message)\n"
    let logPath = "/tmp/thumbnail_debug.log"

    if let data = logMessage.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data)
        }
    }
    // Also print to stdout
    print(message)
}

// MARK: - Thumbnail Cache Error

enum ThumbnailCacheError: Error {
    case cacheDirUnavailable
    case invalidPath
    case imageConversionFailed
    case imageEncodingFailed
    case securityScopeUnavailable
}

// MARK: - Thumbnail Service

actor ThumbnailService {
    static let shared = ThumbnailService()

    // MARK: - Configuration

    private let maxDiskCacheSize: Int64 = 100_000_000 // 100 MB
    private let maxCacheAgeDays: Int = 30

    // Two-tier caching: Memory (fast) + Disk (persistent)
    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default

    // MARK: - Security-Scoped Access

    /// Mapping of standard folder names to their bookmark keys (matches FileOperationsService)
    private static let sourceFolderBookmarks: [String: String] = [
        "Desktop": "DesktopFolderBookmark",
        "Downloads": "DownloadsFolderBookmark",
        "Documents": "DocumentsFolderBookmark",
        "Pictures": "PicturesFolderBookmark",
        "Music": "MusicFolderBookmark"
    ]

    private init() {
        debugLog("🚀 ThumbnailService: Initializing...")
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB (reduced since disk cache exists)

        // Async cleanup on init
        Task {
            await performStartupMaintenance()
        }
        debugLog("🚀 ThumbnailService: Initialized successfully")
    }

    // MARK: - Security Scope Helpers

    /// Determines which monitored folder a file belongs to and returns the bookmark key
    private nonisolated func findMonitoredFolderBookmarkKey(for path: String) -> String? {
        // Get real home directory (bypassing sandbox container path)
        let realHome: String
        if let pw = getpwuid(getuid()) {
            realHome = String(cString: pw.pointee.pw_dir)
        } else {
            realHome = NSHomeDirectory()
        }

        // Check each monitored folder
        for (folderName, bookmarkKey) in Self.sourceFolderBookmarks {
            let folderPath = "\(realHome)/\(folderName)"
            if path.hasPrefix(folderPath + "/") || path == folderPath {
                return bookmarkKey
            }
        }

        return nil
    }

    /// Establishes security-scoped access for a file's parent monitored folder
    /// Returns the folder URL if access was established, nil otherwise
    private func establishSecurityScope(for path: String) -> URL? {
        guard let bookmarkKey = findMonitoredFolderBookmarkKey(for: path) else {
            debugLog("🔴 ThumbnailService: No bookmark key found for path: \(path)")
            return nil
        }

        debugLog("🟡 ThumbnailService: Found bookmark key '\(bookmarkKey)' for path: \(path)")

        // Load bookmark from secure Keychain storage
        guard let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) else {
            debugLog("🔴 ThumbnailService: No bookmark data found for key: \(bookmarkKey)")
            return nil
        }

        debugLog("🟡 ThumbnailService: Loaded bookmark data (\(bookmarkData.count) bytes)")

        // Resolve bookmark to URL
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            debugLog("🔴 ThumbnailService: Failed to resolve bookmark for key: \(bookmarkKey)")
            return nil
        }

        debugLog("🟡 ThumbnailService: Resolved bookmark to URL: \(url.path), isStale: \(isStale)")

        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            debugLog("🔴 ThumbnailService: Failed to start security scope for: \(url.path)")
            return nil
        }

        debugLog("🟢 ThumbnailService: Successfully established security scope for: \(url.path)")

        return url
    }

    /// Releases security-scoped access for a folder URL
    private func releaseSecurityScope(for url: URL) {
        url.stopAccessingSecurityScopedResource()
    }

    // MARK: - Public API

    /// Request thumbnail for the given file path with two-tier caching
    /// Handles security-scoped access for sandboxed app file access
    func thumbnail(for path: String, size: CGSize) async -> NSImage? {
        debugLog("📷 ThumbnailService.thumbnail() called for: \(path)")

        // Establish security-scoped access for the file's parent folder
        // This is required in sandboxed macOS apps to access user files
        let scopedFolderURL = establishSecurityScope(for: path)
        defer {
            if let url = scopedFolderURL {
                releaseSecurityScope(for: url)
                debugLog("📷 ThumbnailService: Released security scope for: \(url.path)")
            }
        }

        // 1. Try memory cache (fastest - no file access needed)
        if let cacheKey = try? generateCacheKey(for: path, size: size),
           let cached = memoryCache.object(forKey: cacheKey as NSString) {
            debugLog("📷 ThumbnailService: ✅ Found in memory cache")
            return cached
        }

        // 2. Try disk cache (cache files are in app sandbox, no security scope needed)
        if let cacheKey = try? generateCacheKey(for: path, size: size),
           let diskImage = loadFromDiskCache(key: cacheKey, sourcePath: path) {
            debugLog("📷 ThumbnailService: ✅ Found in disk cache")
            // Warm up memory cache
            memoryCache.setObject(
                diskImage,
                forKey: cacheKey as NSString,
                cost: estimateImageCost(diskImage)
            )
            return diskImage
        }

        debugLog("📷 ThumbnailService: Cache miss, generating thumbnail...")

        // 3. Generate new thumbnail (requires security scope)
        // If we couldn't establish scope, try anyway (file might be accessible)
        guard let image = await generateThumbnail(for: path, size: size) else {
            debugLog("📷 ThumbnailService: ❌ Failed to generate thumbnail")
            return nil
        }

        debugLog("📷 ThumbnailService: ✅ Generated thumbnail successfully")

        // 4. Cache in both layers
        if let cacheKey = try? generateCacheKey(for: path, size: size) {
            memoryCache.setObject(
                image,
                forKey: cacheKey as NSString,
                cost: estimateImageCost(image)
            )
            saveToDiskCache(image: image, key: cacheKey)
        }

        return image
    }

    /// Clear both memory and disk caches
    func clearCache() async {
        memoryCache.removeAllObjects()
        clearDiskCache()
        Task { @MainActor in
            Log.info("Thumbnail cache cleared", category: .filesystem)
        }
    }

    /// Get cache statistics for debugging
    func cacheStats() async -> (diskFiles: Int, diskSizeBytes: Int64) {
        guard let cacheDir = try? getCacheDirectory() else {
            return (0, 0)
        }

        // Collect URLs synchronously to avoid async iteration issues
        let urls = collectCacheURLs(in: cacheDir)

        var fileCount = 0
        var totalSize: Int64 = 0

        for fileURL in urls {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                fileCount += 1
                totalSize += Int64(size)
            }
        }

        return (fileCount, totalSize)
    }

    /// Collect all URLs in a directory (synchronous helper to avoid async iteration issues)
    private nonisolated func collectCacheURLs(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var urls: [URL] = []
        for case let fileURL as URL in enumerator {
            urls.append(fileURL)
        }
        return urls
    }

    // MARK: - Cache Key Generation

    /// Generate stable cache key using SHA256 of path + size + modification date
    private func generateCacheKey(for path: String, size: CGSize) throws -> String {
        // Get file modification date for cache invalidation
        do {
            let attrs = try fileManager.attributesOfItem(atPath: path)
            guard let modDate = attrs[.modificationDate] as? Date else {
                debugLog("📷 generateCacheKey: ❌ No modification date in attrs for \(path)")
                throw ThumbnailCacheError.invalidPath
            }

            // Create stable key from path + size + mod date
            let input = "\(path)|\(Int(size.width))x\(Int(size.height))|\(Int(modDate.timeIntervalSince1970))"
            let hash = SHA256.hash(data: Data(input.utf8))
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

            // Use first 32 chars for reasonable filename length
            return String(hashString.prefix(32))
        } catch {
            debugLog("📷 generateCacheKey: ❌ Failed to get file attrs for \(path): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Disk Cache Directory

    private func getCacheDirectory() throws -> URL {
        guard let cacheDir = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            throw ThumbnailCacheError.cacheDirUnavailable
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.forma.fileorganizing"
        let thumbnailCache = cacheDir
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("Thumbnails", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: thumbnailCache.path) {
            try fileManager.createDirectory(
                at: thumbnailCache,
                withIntermediateDirectories: true
            )
        }

        return thumbnailCache
    }

    /// Get cache file URL with subdirectory sharding (first 2 chars)
    private func getCacheURL(for key: String) -> URL? {
        guard let cacheDir = try? getCacheDirectory() else { return nil }

        // Shard into subdirectories to avoid filesystem bottlenecks
        let subdir = String(key.prefix(2))
        let subdirURL = cacheDir.appendingPathComponent(subdir, isDirectory: true)

        // Create subdirectory if needed
        if !fileManager.fileExists(atPath: subdirURL.path) {
            do {
                try fileManager.createDirectory(
                    at: subdirURL,
                    withIntermediateDirectories: true
                )
            } catch {
                Task { @MainActor in
                    Log.debug("Failed to create cache subdirectory \(subdir): \(error.localizedDescription)", category: .fileOperations)
                }
            }
        }

        return subdirURL.appendingPathComponent("\(key).png")
    }

    // MARK: - Disk Cache Operations

    private func loadFromDiskCache(key: String, sourcePath: String) -> NSImage? {
        guard let cacheURL = getCacheURL(for: key),
              fileManager.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        // Validate cache is still fresh (source file not modified after cache creation)
        guard let sourceAttrs = try? fileManager.attributesOfItem(atPath: sourcePath),
              let cacheAttrs = try? fileManager.attributesOfItem(atPath: cacheURL.path),
              let sourceModDate = sourceAttrs[.modificationDate] as? Date,
              let cacheCreateDate = cacheAttrs[.creationDate] as? Date,
              cacheCreateDate > sourceModDate else {
            // Cache is stale, remove it
            do {
                try fileManager.removeItem(at: cacheURL)
            } catch {
                Task { @MainActor in
                    Log.debug("Failed to remove stale cache file: \(error.localizedDescription)", category: .fileOperations)
                }
            }
            return nil
        }

        return NSImage(contentsOf: cacheURL)
    }

    private func saveToDiskCache(image: NSImage, key: String) {
        guard let cacheURL = getCacheURL(for: key) else { return }

        // Convert to PNG data
        guard let cgImage = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else { return }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else { return }

        // Write atomically to prevent corruption
        do {
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            Task { @MainActor in
                Log.debug("Failed to save thumbnail to disk cache: \(error.localizedDescription)", category: .fileOperations)
            }
        }
    }

    private func clearDiskCache() {
        guard let cacheDir = try? getCacheDirectory() else { return }

        // Remove and recreate directory
        do {
            try fileManager.removeItem(at: cacheDir)
        } catch {
            Task { @MainActor in
                Log.debug("Failed to remove cache directory during clear: \(error.localizedDescription)", category: .fileOperations)
            }
        }

        do {
            try fileManager.createDirectory(
                at: cacheDir,
                withIntermediateDirectories: true
            )
        } catch {
            Task { @MainActor in
                Log.debug("Failed to recreate cache directory during clear: \(error.localizedDescription)", category: .fileOperations)
            }
        }
    }

    // MARK: - Cache Maintenance

    private func performStartupMaintenance() async {
        await cleanupOldThumbnails()
        await evictIfOverSizeLimit()
    }

    /// Remove thumbnails older than maxCacheAgeDays
    private func cleanupOldThumbnails() async {
        guard let cacheDir = try? getCacheDirectory() else { return }

        let cutoffDate = Date().addingTimeInterval(-Double(maxCacheAgeDays) * 86400)
        let urls = collectCacheURLs(in: cacheDir)

        var removedCount = 0

        for fileURL in urls {
            guard let creationDate = try? fileURL.resourceValues(
                forKeys: [.creationDateKey]
            ).creationDate else { continue }

            if creationDate < cutoffDate {
                do {
                    try fileManager.removeItem(at: fileURL)
                    removedCount += 1
                } catch {
                    Task { @MainActor in
                        Log.debug("Failed to remove old cache file during cleanup: \(error.localizedDescription)", category: .fileOperations)
                    }
                }
            }
        }

        if removedCount > 0 {
            Task { @MainActor in
                Log.debug("Removed \(removedCount) old thumbnail cache entries", category: .filesystem)
            }
        }
    }

    /// Evict oldest thumbnails if cache exceeds size limit (LRU-style)
    private func evictIfOverSizeLimit() async {
        guard let cacheDir = try? getCacheDirectory() else { return }

        let urls = collectCacheURLs(in: cacheDir)

        var cacheFiles: [(url: URL, size: Int64, date: Date)] = []
        var totalSize: Int64 = 0

        for fileURL in urls {
            guard let resourceValues = try? fileURL.resourceValues(
                forKeys: [.fileSizeKey, .creationDateKey]
            ) else { continue }

            let size = Int64(resourceValues.fileSize ?? 0)
            let date = resourceValues.creationDate ?? Date.distantPast

            // Only count PNG files (skip directories)
            if fileURL.pathExtension == "png" {
                cacheFiles.append((fileURL, size, date))
                totalSize += size
            }
        }

        // Evict oldest files if over limit
        if totalSize > maxDiskCacheSize {
            let sorted = cacheFiles.sorted { $0.date < $1.date }
            var currentSize = totalSize
            var evictedCount = 0

            for file in sorted {
                if currentSize <= maxDiskCacheSize {
                    break
                }

                do {
                    try fileManager.removeItem(at: file.url)
                    currentSize -= file.size
                    evictedCount += 1
                } catch {
                    Task { @MainActor in
                        Log.debug("Failed to evict cache file during size limit enforcement: \(error.localizedDescription)", category: .fileOperations)
                    }
                }
            }

            Task { @MainActor in
                Log.debug("Evicted \(evictedCount) thumbnail cache entries to stay under size limit", category: .filesystem)
            }
        }
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail(for path: String, size: CGSize) async -> NSImage? {
        let fileURL = URL(fileURLWithPath: path)
        debugLog("📷 generateThumbnail: Attempting for \(fileURL.lastPathComponent)")

        // Try QuickLook Thumbnail Generator first (handles most file types)
        if let image = await generateQLThumbnail(for: fileURL, size: size) {
            debugLog("📷 generateThumbnail: ✅ QuickLook succeeded")
            return image
        }

        // Fallback to Image I/O for basic images if QL fails
        if let image = generateImageIOThumbnail(for: fileURL, size: size) {
            debugLog("📷 generateThumbnail: ✅ ImageIO succeeded")
            return image
        }

        debugLog("📷 generateThumbnail: ❌ Both methods failed")
        return nil
    }

    private func generateQLThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .thumbnail
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            debugLog("📷 generateQLThumbnail: ✅ Success for \(url.lastPathComponent)")
            return thumbnail.nsImage
        } catch {
            debugLog("📷 generateQLThumbnail: ❌ Error for \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private func generateImageIOThumbnail(for url: URL, size: CGSize) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height) * (NSScreen.main?.backingScaleFactor ?? 2.0)
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            debugLog("📷 generateImageIOThumbnail: ❌ Failed to create source/image for \(url.lastPathComponent)")
            return nil
        }

        debugLog("📷 generateImageIOThumbnail: ✅ Success for \(url.lastPathComponent)")
        return NSImage(cgImage: cgImage, size: size)
    }

    // MARK: - Helpers

    private func estimateImageCost(_ image: NSImage) -> Int {
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        // Estimate: 4 bytes per pixel (RGBA)
        return width * height * 4
    }
}
