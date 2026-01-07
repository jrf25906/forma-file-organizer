import SwiftUI

struct FileThumbnailView: View {
    let file: FileItem
    var size: CGFloat = 80

    @State private var thumbnail: NSImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let thumb = thumbnail {
                // Show actual thumbnail (works for images, videos, PDFs, documents, etc.)
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .formaCornerRadius(FormaRadius.small)
            } else {
                // Loading state or fallback to system icon
                ZStack {
                    RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                        .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle - Color.FormaOpacity.ultraSubtle))
                        .frame(width: size, height: size)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    } else {
                        // Fallback to native icon if thumbnail not available
                        let icon = NSWorkspace.shared.icon(forFile: file.path)
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size * 0.65, height: size * 0.65)
                    }
                }
            }
        }
        .task(id: file.path) {
            // Always attempt thumbnail - QLThumbnailGenerator handles all supported types
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard thumbnail == nil else { return }
        isLoading = true
        defer { isLoading = false }

        thumbnail = await ThumbnailService.shared.thumbnail(for: file.path, size: CGSize(width: size, height: size))
    }
}
