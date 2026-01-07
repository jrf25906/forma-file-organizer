import SwiftUI
import AppKit

/// A view modifier that accesses and configures the underlying NSWindow.
/// Used to achieve the Xcode/ChatGPT-style full-height sidebar that extends above traffic lights.
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
        // Make titlebar transparent so content can extend behind it
        window.titlebarAppearsTransparent = true

        // Ensure full-size content view is enabled (allows content behind traffic lights)
        window.styleMask.insert(.fullSizeContentView)

        // Allow window to be moved by dragging the background
        window.isMovableByWindowBackground = true

        // Hide the title text but keep the titlebar area
        window.titleVisibility = .hidden

        // Set the toolbar style to unified without title (for consistency)
        window.toolbarStyle = .unified
        
        // Enable window transparency for glass effect
        window.isOpaque = false
        window.backgroundColor = .clear
    }
}

/// View extension for applying window configuration
extension View {
    /// Applies the Xcode/ChatGPT-style window configuration for full-height sidebar support.
    func configureForFullHeightSidebar() -> some View {
        self.background(WindowAccessor())
    }
}
