import Foundation

/// Tracks the state of security-scoped bookmark migration from UserDefaults to Keychain.
///
/// This state is persisted to UserDefaults and allows the app to:
/// 1. Know if migration has been attempted
/// 2. Track migration success/failure
/// 3. Show recovery UI when migration fails
/// 4. Prevent repeated migration attempts
struct BookmarkMigrationState: Codable {
    enum Status: String, Codable {
        case notStarted
        case succeeded
        case failed
        case partialSuccess
    }
    
    let status: Status
    let migratedKeys: [String]
    let failedKeys: [String]
    let timestamp: Date
    let errorMessage: String?
    
    // MARK: - UserDefaults Persistence
    
    private static let storageKey = "BookmarkMigrationState"
    
    /// Saves the migration state to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }
    
    /// Loads the migration state from UserDefaults
    static func load() -> BookmarkMigrationState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(BookmarkMigrationState.self, from: data) else {
            return nil
        }
        return state
    }
    
    /// Clears the saved migration state (for testing or retry)
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    // MARK: - State Queries
    
    /// Whether migration has been completed successfully
    var isSuccessful: Bool {
        status == .succeeded
    }
    
    /// Whether migration failed completely
    var hasFailed: Bool {
        status == .failed
    }
    
    /// Whether migration partially succeeded (some bookmarks migrated, others failed)
    var isPartial: Bool {
        status == .partialSuccess
    }
    
    /// Whether the app should show migration recovery UI
    var needsRecovery: Bool {
        status == .failed || status == .partialSuccess
    }
    
    /// User-facing description of the migration result
    var userDescription: String {
        switch status {
        case .notStarted:
            return "Migration not started"
        case .succeeded:
            return "Successfully migrated \(migratedKeys.count) folder permissions"
        case .failed:
            if let error = errorMessage {
                return "Failed to migrate folder permissions: \(error)"
            }
            return "Failed to migrate folder permissions. You may need to re-grant access."
        case .partialSuccess:
            return "Partially migrated: \(migratedKeys.count) succeeded, \(failedKeys.count) failed"
        }
    }
    
    /// Detailed description for debugging
    var debugDescription: String {
        var desc = "Migration Status: \(status.rawValue)\n"
        desc += "Timestamp: \(timestamp)\n"
        if !migratedKeys.isEmpty {
            desc += "✅ Migrated: \(migratedKeys.joined(separator: ", "))\n"
        }
        if !failedKeys.isEmpty {
            desc += "❌ Failed: \(failedKeys.joined(separator: ", "))\n"
        }
        if let error = errorMessage {
            desc += "Error: \(error)\n"
        }
        return desc
    }
    
    // MARK: - Factory Methods
    
    static func success(migratedKeys: [String]) -> BookmarkMigrationState {
        BookmarkMigrationState(
            status: .succeeded,
            migratedKeys: migratedKeys,
            failedKeys: [],
            timestamp: Date(),
            errorMessage: nil
        )
    }
    
    static func failure(failedKeys: [String], error: Error) -> BookmarkMigrationState {
        BookmarkMigrationState(
            status: .failed,
            migratedKeys: [],
            failedKeys: failedKeys,
            timestamp: Date(),
            errorMessage: error.localizedDescription
        )
    }
    
    static func partial(migratedKeys: [String], failedKeys: [String]) -> BookmarkMigrationState {
        BookmarkMigrationState(
            status: .partialSuccess,
            migratedKeys: migratedKeys,
            failedKeys: failedKeys,
            timestamp: Date(),
            errorMessage: nil
        )
    }
}
