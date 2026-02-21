import SwiftUI
import AppKit

// MARK: - Window-Drag Prevention

/// An NSView subclass that returns `false` for `mouseDownCanMoveWindow`,
/// preventing `isMovableByWindowBackground` from intercepting drag gestures
/// on child SwiftUI views (e.g., rule cards that support onDrag reordering).
class NonDraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

/// Wraps a SwiftUI view in a layer that blocks window-background dragging,
/// allowing system drag-and-drop (onDrag/onDrop) to work correctly.
struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NonDraggableNSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// Prevents `isMovableByWindowBackground` from capturing mouse events on this view.
    func blockWindowDrag() -> some View {
        self.background(WindowDragBlocker())
    }
}
