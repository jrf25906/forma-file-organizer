import Foundation

protocol BookmarkStore: Sendable {
    func saveBookmark(_ data: Data, forKey key: String) throws
    func loadBookmark(forKey key: String) -> Data?
    func deleteBookmark(forKey key: String) throws
    func listAllBookmarkKeys() -> [String]
    func deleteAllBookmarks() throws
    func migrateFromUserDefaults(keys: [String]) throws
}

struct SecureBookmarkStoreAdapter: BookmarkStore {
    func saveBookmark(_ data: Data, forKey key: String) throws {
        try SecureBookmarkStore.saveBookmark(data, forKey: key)
    }

    func loadBookmark(forKey key: String) -> Data? {
        SecureBookmarkStore.loadBookmark(forKey: key)
    }

    func deleteBookmark(forKey key: String) throws {
        try SecureBookmarkStore.deleteBookmark(forKey: key)
    }

    func listAllBookmarkKeys() -> [String] {
        SecureBookmarkStore.listAllBookmarkKeys()
    }

    func deleteAllBookmarks() throws {
        try SecureBookmarkStore.deleteAllBookmarks()
    }

    func migrateFromUserDefaults(keys: [String]) throws {
        try SecureBookmarkStore.migrateFromUserDefaults(keys: keys)
    }
}

enum BookmarkStoreProvider {
    @TaskLocal static var override: BookmarkStore?

    static var shared: BookmarkStore {
        override ?? SecureBookmarkStoreAdapter()
    }
}
