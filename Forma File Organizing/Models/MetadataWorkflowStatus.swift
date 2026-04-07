import Foundation

enum MetadataWorkflowStatus: String, CaseIterable, Hashable, Sendable {
    case queued
    case organized
    case recovered
    case ignored
}
