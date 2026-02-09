import SwiftUI
import AppKit

/// A view modifier that accesses and configures the underlying NSWindow.
/// Kept for optional window-level chrome tuning.
struct WindowAccessor: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configureWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-check window configuration on updates
        if let window = nsView.window {
            configureWindow(window)
        }
    }

    private func configureWindow(_ window: NSWindow) {
        // Use native macOS chrome conventions.
        window.titlebarAppearsTransparent = false
        window.styleMask.remove(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
    }
}

/// View extension for applying window configuration
extension View {
    /// Applies optional native-aligned window configuration.
    func configureForFullHeightSidebar() -> some View {
        self.background(WindowAccessor())
    }
}
