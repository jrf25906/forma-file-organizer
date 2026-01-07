import SwiftUI
import AppKit

/// Observes the containing window's key state (active window) and updates a binding.
struct WindowKeyObserver: NSViewRepresentable {
    @Binding var isKeyWindow: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isKeyWindow: $isKeyWindow)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attachIfNeeded(to: nsView.window)
    }

    final class Coordinator: NSObject {
        private var isKeyWindow: Binding<Bool>
        private weak var window: NSWindow?

        init(isKeyWindow: Binding<Bool>) {
            self.isKeyWindow = isKeyWindow
            super.init()
        }

        deinit {
            detach()
        }

        @MainActor
        func attachIfNeeded(to window: NSWindow?) {
            guard let window else { return }
            if self.window === window {
                return
            }
            detach()
            self.window = window
            isKeyWindow.wrappedValue = window.isKeyWindow

            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(windowDidResignKey(_:)), name: NSWindow.didResignKeyNotification, object: window)
        }

        private func detach() {
            let center = NotificationCenter.default
            center.removeObserver(self)
            window = nil
        }

        @objc
        private func windowDidBecomeKey(_ notification: Notification) {
            isKeyWindow.wrappedValue = true
        }

        @objc
        private func windowDidResignKey(_ notification: Notification) {
            isKeyWindow.wrappedValue = false
        }
    }
}
