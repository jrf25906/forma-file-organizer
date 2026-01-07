import AppKit
import SwiftUI

/// Floating preview popup showing larger thumbnail and file details on hover
struct ThumbnailPreviewPopup: View {
    let file: FileItem
    let cursorPosition: CGPoint
    @State private var largeThumbnail: NSImage?
    @State private var isLoading = true
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let maxPreviewSize: CGFloat = 300
    private let popupWidth: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Preview image
            if let thumbnail = largeThumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxPreviewSize, maxHeight: maxPreviewSize)
                    .formaCornerRadius(FormaRadius.control)
            } else if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
                        .frame(width: 200, height: 200)

                    ProgressView()
                }
            } else {
                // Fallback to icon if thumbnail can't be loaded
                let icon = NSWorkspace.shared.icon(forFile: file.path)
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            }

            // File details
            VStack(alignment: .leading, spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                // Filename
                Text(file.name)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)
                    .lineLimit(2)
                    .truncationMode(.middle)

                // Type and size
                HStack(spacing: FormaSpacing.micro) {
                    Text(file.fileExtension.uppercased())
                        .font(.formaCompact)
                        .foregroundColor(.formaSecondaryLabel)

                    Text("•")
                        .font(.formaCompact)
                        .foregroundColor(.formaSecondaryLabel)

                    Text(file.size)
                        .font(.formaCompact)
                        .foregroundColor(.formaSecondaryLabel)
                }

                // Modified date
                Text("Modified \(file.creationDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.formaSmall)
                    .foregroundColor(.formaTertiaryLabel)

                // Image dimensions (if image file with thumbnail)
                if file.category == .images, let thumbnail = largeThumbnail {
                    Text("\(Int(thumbnail.size.width)) × \(Int(thumbnail.size.height)) pixels")
                        .font(.formaSmall)
                        .foregroundColor(.formaTertiaryLabel)
                }
            }
        }
        .padding(FormaSpacing.standard)
        .frame(width: popupWidth)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaControlBackground)
                .shadow(
                    color: Color.formaObsidian.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .position(smartPosition())
        .opacity(isLoading ? Color.FormaOpacity.prominent : 1.0)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isLoading)
        .task {
            await loadLargeThumbnail()
        }
    }

    /// Calculate smart position near cursor that stays on screen
    private func smartPosition() -> CGPoint {
        guard let screen = NSScreen.main else {
            return cursorPosition
        }

        let screenFrame = screen.visibleFrame
        let popupHeight: CGFloat = 400 // Estimated max height
        let offset: CGFloat = FormaSpacing.generous - FormaSpacing.micro // Offset from cursor
        let edgeInset: CGFloat = FormaSpacing.tight + (FormaSpacing.micro / 2)

        var x = cursorPosition.x + offset
        var y = cursorPosition.y - offset

        // Keep popup on screen horizontally
        if x + popupWidth > screenFrame.maxX {
            x = cursorPosition.x - popupWidth - offset
        }
        if x < screenFrame.minX {
            x = screenFrame.minX + edgeInset
        }

        // Keep popup on screen vertically
        if y + popupHeight > screenFrame.maxY {
            y = screenFrame.maxY - popupHeight - edgeInset
        }
        if y < screenFrame.minY {
            y = screenFrame.minY + edgeInset
        }

        return CGPoint(x: x, y: y)
    }

    /// Load larger thumbnail for preview (300x300)
    private func loadLargeThumbnail() async {
        isLoading = true
        defer { isLoading = false }

        // Attempt thumbnail for all file types - QLThumbnailGenerator handles
        // images, videos, PDFs, documents, and other supported formats
        largeThumbnail = await ThumbnailService.shared.thumbnail(
            for: file.path,
            size: CGSize(width: maxPreviewSize, height: maxPreviewSize)
        )
    }
}

#Preview {
    ZStack {
        Color.formaBoneWhite

        ThumbnailPreviewPopup(
            file: FileItem(
                path: "/Users/test/Desktop/Example Photo.jpg",
                sizeInBytes: 3_355_443,
                creationDate: Date().addingTimeInterval(-86400),
                destination: nil,
                status: .pending
            ),
            cursorPosition: CGPoint(x: 200, y: 200)
        )
    }
    .frame(width: 800, height: 600)
}
