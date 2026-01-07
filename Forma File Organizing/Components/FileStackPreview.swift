import SwiftUI

/// Displays a stack of overlapping file type icons for batch suggestions.
///
/// Creates a visual "mental shortcut" by showing 3-4 actual file type icons
/// stacked together, helping users recognize related work sessions at a glance.
///
/// ## Usage
/// ```swift
/// FileStackPreview(files: projectFiles)
/// FileStackPreview(files: downloads, maxVisible: 3)
/// ```
struct FileStackPreview: View {
    let files: [FileItem]
    var maxVisible: Int = 4

    /// Offset between each stacked icon
    private let stackOffset: CGFloat = 10

    /// Slight vertical stagger for depth effect
    private let verticalOffset: CGFloat = -2

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(visibleFiles.enumerated()), id: \.offset) { index, file in
                FileTypeIconView(file: file)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .fill(categoryColor(for: file).opacity(Color.FormaOpacity.light))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .strokeBorder(Color.formaBoneWhite.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: Color.formaObsidian.opacity(0.08), radius: 2, x: 0, y: 1)
                    .offset(
                        x: CGFloat(index) * stackOffset,
                        y: CGFloat(index) * verticalOffset
                    )
                    .zIndex(Double(maxVisible - index))
            }

            // Overflow indicator (+N more)
            if files.count > maxVisible {
                Text("+\(files.count - maxVisible)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 3))
                    )
                    .offset(
                        x: CGFloat(maxVisible) * stackOffset + 4,
                        y: 0
                    )
            }
        }
        .frame(
            width: calculateWidth(),
            height: 32,
            alignment: .leading
        )
    }

    // MARK: - Private

    private var visibleFiles: [FileItem] {
        Array(files.prefix(maxVisible))
    }

    private func calculateWidth() -> CGFloat {
        let baseWidth: CGFloat = 28
        let overflowWidth: CGFloat = files.count > maxVisible ? 24 : 0
        return baseWidth + (CGFloat(min(files.count, maxVisible) - 1) * stackOffset) + overflowWidth
    }

    private func categoryColor(for file: FileItem) -> Color {
        switch file.category {
        case .images:
            return .formaWarmOrange
        case .documents:
            return .formaMutedBlue
        case .videos:
            return .formaSteelBlue
        case .audio:
            return .formaSage
        case .archives:
            return .formaSoftGreen
        case .all:
            return .formaSecondaryLabel
        }
    }
}

// MARK: - File Type Icon View

/// Displays an appropriate SF Symbol for a file's type
private struct FileTypeIconView: View {
    let file: FileItem

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch file.category {
        case .images:
            return "photo.fill"
        case .documents:
            // More specific document icons
            if file.fileExtension.lowercased() == "pdf" {
                return "doc.richtext.fill"
            }
            return "doc.text.fill"
        case .videos:
            return "film.fill"
        case .audio:
            return "waveform"
        case .archives:
            return "archivebox.fill"
        case .all:
            return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch file.category {
        case .images:
            return .formaWarmOrange
        case .documents:
            return .formaMutedBlue
        case .videos:
            return .formaSteelBlue
        case .audio:
            return .formaSage
        case .archives:
            return .formaSoftGreen
        case .all:
            return .formaSecondaryLabel
        }
    }
}

// MARK: - Preview

#Preview("4 Files") {
    // Mock files for preview
    FileStackPreview(files: [])
        .padding()
        .background(.regularMaterial)
}

#Preview("Many Files") {
    FileStackPreview(files: [], maxVisible: 4)
        .padding()
        .background(.regularMaterial)
}
