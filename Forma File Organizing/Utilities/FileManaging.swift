import Foundation

protocol FileManaging {
    var homeDirectoryForCurrentUser: URL { get }
    func fileExists(atPath path: String) -> Bool
    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) throws
    func removeItem(at url: URL) throws
    func moveItem(at srcURL: URL, to dstURL: URL) throws
    func copyItem(at srcURL: URL, to dstURL: URL) throws
    func trashItem(at url: URL, resultingItemURL: inout URL?) throws
}

extension FileManager: FileManaging {
    func trashItem(at url: URL, resultingItemURL: inout URL?) throws {
        var nsURL: NSURL?
        try trashItem(at: url, resultingItemURL: &nsURL)
        resultingItemURL = nsURL as URL?
    }
}
