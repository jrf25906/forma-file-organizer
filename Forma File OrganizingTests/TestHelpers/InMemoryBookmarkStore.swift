import Foundation
@testable import Forma_File_Organizing

final class InMemoryBookmarkStore: BookmarkStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]

    func saveBookmark(_ data: Data, forKey key: String) throws {
        guard !key.isEmpty else { return }
        storage[key] = data
    }

    func loadBookmark(forKey key: String) -> Data? {
        storage[key]
    }

    func deleteBookmark(forKey key: String) throws {
        storage.removeValue(forKey: key)
    }

    func listAllBookmarkKeys() -> [String] {
        Array(storage.keys)
    }

    func deleteAllBookmarks() throws {
        storage.removeAll()
    }

    func migrateFromUserDefaults(keys: [String]) throws {
        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key) {
                storage[key] = data
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
