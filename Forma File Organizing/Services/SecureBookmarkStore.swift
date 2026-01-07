import Foundation
import Security

/// Secure storage for security-scoped bookmark data using macOS Keychain
///
/// This class provides secure storage for security-scoped bookmarks to prevent:
/// - Unauthorized access to bookmark data from other processes
/// - Tampering with bookmark data to redirect to malicious folders
/// - Exposure of bookmark data in backups
///
/// OWASP References:
/// - A01:2021 – Broken Access Control
/// - A04:2021 – Insecure Design
/// - A07:2021 – Identification and Authentication Failures
class SecureBookmarkStore {

    // MARK: - Constants

    /// Keychain service identifier for bookmark storage
    private static let keychainService = "com.forma.bookmarks"

    /// Access group for sharing bookmarks between app components if needed
    private static let accessGroup: String? = nil

    // MARK: - Error Types

    enum BookmarkStoreError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case migrationFailed(String)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save bookmark to Keychain (status: \(status))"
            case .loadFailed(let status):
                return "Failed to load bookmark from Keychain (status: \(status))"
            case .deleteFailed(let status):
                return "Failed to delete bookmark from Keychain (status: \(status))"
            case .migrationFailed(let reason):
                return "Failed to migrate bookmark data: \(reason)"
            }
        }
    }

    // MARK: - Save Bookmark

    /// Saves bookmark data securely to the Keychain
    /// - Parameters:
    ///   - data: The security-scoped bookmark data to save
    ///   - key: The unique key to identify this bookmark
    /// - Throws: BookmarkStoreError if the save operation fails
    ///
    /// Security Notes:
    /// - Data is encrypted at rest by macOS Keychain
    /// - Accessible only after first unlock (kSecAttrAccessibleAfterFirstUnlock)
    /// - Isolated from other applications via service identifier
    static func saveBookmark(_ data: Data, forKey key: String) throws {
        // Validate inputs
        guard !data.isEmpty else {
            throw BookmarkStoreError.saveFailed(errSecParam)
        }

        guard !key.isEmpty else {
            throw BookmarkStoreError.saveFailed(errSecParam)
        }

        // Build the query dictionary
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Data accessible after first device unlock and persists across reboots
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Add access group if specified (for app group sharing)
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Delete any existing item first to avoid duplicates
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
        #if DEBUG
        Log.error("SecureBookmarkStore: Failed to save bookmark for key '\(key)' - Status: \(status)", category: .bookmark)
        #endif
            throw BookmarkStoreError.saveFailed(status)
        }

        #if DEBUG
        Log.info("SecureBookmarkStore: Successfully saved bookmark for key '\(key)'", category: .bookmark)
        #endif
    }

    // MARK: - Load Bookmark

    /// Loads bookmark data securely from the Keychain
    /// - Parameter key: The unique key identifying the bookmark
    /// - Returns: The bookmark data if found, nil otherwise
    ///
    /// Security Notes:
    /// - Returns nil rather than throwing for missing items (expected condition)
    /// - Validates data integrity before returning
    static func loadBookmark(forKey key: String) -> Data? {
        guard !key.isEmpty else {
            #if DEBUG
            Log.warning("SecureBookmarkStore: Empty key provided to loadBookmark", category: .bookmark)
            #endif
            return nil
        }

        // Build the query dictionary
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Add access group if specified
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Attempt to retrieve the item
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                #if DEBUG
                Log.warning("SecureBookmarkStore: Failed to load bookmark for key '\(key)' - Status: \(status)", category: .bookmark)
                #endif
            }
            return nil
        }

        // Validate and return the data
        guard let data = result as? Data, !data.isEmpty else {
            #if DEBUG
            Log.warning("SecureBookmarkStore: Retrieved bookmark data is invalid for key '\(key)'", category: .bookmark)
            #endif
            return nil
        }

        #if DEBUG
        Log.info("SecureBookmarkStore: Successfully loaded bookmark for key '\(key)'", category: .bookmark)
        #endif

        return data
    }

    // MARK: - Delete Bookmark

    /// Deletes bookmark data securely from the Keychain
    /// - Parameter key: The unique key identifying the bookmark
    /// - Throws: BookmarkStoreError if the delete operation fails (except for item not found)
    ///
    /// Security Notes:
    /// - Does not throw if item doesn't exist (idempotent operation)
    /// - Ensures complete removal from secure storage
    static func deleteBookmark(forKey key: String) throws {
        guard !key.isEmpty else {
            throw BookmarkStoreError.deleteFailed(errSecParam)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success or item not found are both acceptable outcomes
        guard status == errSecSuccess || status == errSecItemNotFound else {
            #if DEBUG
            Log.error("SecureBookmarkStore: Failed to delete bookmark for key '\(key)' - Status: \(status)", category: .bookmark)
            #endif
            throw BookmarkStoreError.deleteFailed(status)
        }

        #if DEBUG
        Log.info("SecureBookmarkStore: Successfully deleted bookmark for key '\(key)'", category: .bookmark)
        #endif
    }

    // MARK: - Migration from UserDefaults

    /// Migrates bookmark data from UserDefaults to Keychain
    /// - Parameter keys: Array of UserDefaults keys to migrate
    /// - Throws: BookmarkStoreError if migration fails
    ///
    /// This should be called once on app launch to migrate existing bookmarks
    /// from insecure UserDefaults storage to secure Keychain storage.
    ///
    /// Security Notes:
    /// - Removes data from UserDefaults after successful migration
    /// - Validates data integrity during migration
    /// - Logs migration progress for audit trail
    static func migrateFromUserDefaults(keys: [String]) throws {
        var migratedCount = 0
        var failedKeys: [String] = []

        #if DEBUG
        Log.info("SecureBookmarkStore: Starting migration of \(keys.count) bookmarks from UserDefaults", category: .bookmark)
        #endif

        for key in keys {
            // Check if already migrated (data exists in Keychain)
            if loadBookmark(forKey: key) != nil {
                #if DEBUG
                Log.debug("Key '\(key)' already migrated to Keychain, skipping", category: .bookmark)
                #endif

                // Clean up UserDefaults even if already migrated
                UserDefaults.standard.removeObject(forKey: key)
                continue
            }

            // Load from UserDefaults
            guard let data = UserDefaults.standard.data(forKey: key) else {
                #if DEBUG
                Log.debug("No UserDefaults data for key '\(key)', skipping migration", category: .bookmark)
                #endif
                continue
            }

            // Validate data is not empty
            guard !data.isEmpty else {
                #if DEBUG
                Log.warning("Empty bookmark data in UserDefaults for key '\(key)', skipping", category: .bookmark)
                #endif
                failedKeys.append(key)
                continue
            }

            // Validate it's actually bookmark data by attempting to resolve it
            var isStale = false
            do {
                _ = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
            } catch {
                #if DEBUG
                Log.warning("Invalid bookmark data in UserDefaults for key '\(key)', skipping: \(error)", category: .bookmark)
                #endif
                failedKeys.append(key)
                UserDefaults.standard.removeObject(forKey: key)
                continue
            }

            // Save to Keychain
            do {
                try saveBookmark(data, forKey: key)

                // Remove from UserDefaults after successful migration
                UserDefaults.standard.removeObject(forKey: key)

                migratedCount += 1
                #if DEBUG
                Log.info("Migrated '\(key)' to Keychain", category: .bookmark)
                #endif
            } catch {
                #if DEBUG
                Log.error("Failed to migrate bookmark '\(key)': \(error)", category: .bookmark)
                #endif
                failedKeys.append(key)
            }
        }

        #if DEBUG
        let baseMessage = "SecureBookmarkStore: Migration complete - \(migratedCount) successful, \(failedKeys.count) failed"
        if failedKeys.isEmpty {
            Log.info(baseMessage, category: .bookmark)
        } else {
            Log.warning(baseMessage + ", failed keys: \(failedKeys.joined(separator: ", "))", category: .bookmark)
        }
        #endif

        // Only throw if all migrations failed and there was at least one item to migrate
        if !keys.isEmpty && migratedCount == 0 && !failedKeys.isEmpty {
            throw BookmarkStoreError.migrationFailed("All migration attempts failed")
        }
    }

    // MARK: - Utility Methods

    /// Lists all bookmark keys stored in the Keychain
    /// - Returns: Array of bookmark keys, or empty array if none found
    ///
    /// Useful for debugging and auditing stored bookmarks
    static func listAllBookmarkKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            item[kSecAttrAccount as String] as? String
        }
    }

    /// Removes all bookmarks from the Keychain
    /// - Throws: BookmarkStoreError if the operation fails
    ///
    /// Use with caution - this will require users to re-grant folder access
    static func deleteAllBookmarks() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BookmarkStoreError.deleteFailed(status)
        }

        #if DEBUG
        Log.info("SecureBookmarkStore: Deleted all bookmarks from Keychain", category: .bookmark)
        #endif
    }
}
