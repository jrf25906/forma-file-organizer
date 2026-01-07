import Foundation
import SwiftUI

enum FileTypeCategory: String, CaseIterable, Identifiable, Sendable {
    case documents
    case images
    case videos
    case audio
    case archives
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .documents: return "Documents"
        case .images: return "Images"
        case .videos: return "Videos"
        case .audio: return "Audio"
        case .archives: return "Archives"
        case .all: return "All Files"
        }
    }

    var iconName: String {
        switch self {
        case .documents: return "doc.text.fill"
        case .images: return "photo.fill"
        case .videos: return "film.fill"
        case .audio: return "music.note"
        case .archives: return "archivebox.fill"
        case .all: return "folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .documents: return .formaMutedBlue
        case .images: return .formaWarmOrange
        case .videos: return .formaSteelBlue
        case .audio: return .formaSage
        case .archives: return .formaSoftGreen
        case .all: return .formaSecondaryLabel
        }
    }

    var extensions: [String] {
        switch self {
        case .documents:
            return ["pdf", "doc", "docx", "txt", "rtf", "pages", "xls", "xlsx", "csv", "ppt", "pptx", "keynote"]
        case .images:
            return ["jpg", "jpeg", "png", "heic", "gif", "svg", "psd", "ai", "raw", "cr2", "nef"]
        case .videos:
            return ["mov", "mp4", "avi", "mkv", "m4v", "wmv", "flv", "webm"]
        case .audio:
            return ["mp3", "wav", "m4a", "aac", "flac", "ogg", "wma", "aiff"]
        case .archives:
            return ["zip", "dmg", "pkg", "rar", "7z", "tar", "gz", "bz2"]
        case .all:
            return []
        }
    }

    static func category(for fileExtension: String) -> FileTypeCategory {
        let ext = fileExtension.lowercased()

        for category in FileTypeCategory.allCases where category != .all {
            if category.extensions.contains(ext) {
                return category
            }
        }

        return .documents // Default to documents for unknown types
    }

    func matches(fileExtension: String) -> Bool {
        if self == .all { return true }
        return extensions.contains(fileExtension.lowercased())
    }
    
    /// Returns a gradient for the category (used in list/grid views)
    func gradient() -> LinearGradient {
        let primary = color
        let colors: [Color] = [
            primary.opacity(Color.FormaOpacity.medium),
            primary.opacity(Color.FormaOpacity.light)
        ]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
