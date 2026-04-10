import Foundation

enum MetadataWorkflowStatus: String, CaseIterable, Hashable, Sendable, Codable {
    case queued
    case organized
    case archived
    case recovered
    case ignored
}
