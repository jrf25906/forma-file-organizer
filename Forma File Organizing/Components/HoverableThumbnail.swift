import SwiftUI
import AppKit

/// Wrapper for FileThumbnailView that adds hover preview support
struct HoverableThumbnail<Content: View>: View {
    let file: FileItem
    let onHoverChange: (FileItem?, NSEvent?) -> Void
    let content: () -> Content
    
    @State private var isHovering = false
    
    var body: some View {
        content()
            .onContinuousHover { phase in
                switch phase {
                case .active(_):
                    if !isHovering {
                        isHovering = true
                        // Capture mouse location for positioning
                        let event = NSApp.currentEvent
                        onHoverChange(file, event)
                    }
                case .ended:
                    isHovering = false
                    onHoverChange(nil, nil)
                }
            }
    }
}

extension View {
    /// Add hover preview functionality to a view
    func hoverableWithPreview(file: FileItem, onHoverChange: @escaping (FileItem?, NSEvent?) -> Void) -> some View {
        HoverableThumbnail(file: file, onHoverChange: onHoverChange) {
            self
        }
    }
}
