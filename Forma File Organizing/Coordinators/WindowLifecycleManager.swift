import AppKit

/// Manages app activation policy transitions between regular (dock + menu bar)
/// and accessory (menu bar only) modes.
///
/// Call `mainWindowDidAppear()` when the main window opens, and
/// `mainWindowDidDisappear()` when it closes, to toggle dock visibility.
@MainActor
final class WindowLifecycleManager {
    
    static let shared = WindowLifecycleManager()
    
    private init() {}
    
    /// Called when the main window appears.
    /// Sets activation policy to `.regular` (dock icon visible) and
    /// tells AutomationEngine we're in `.activeWithWindow` state.
    func mainWindowDidAppear() {
        NSApplication.shared.setActivationPolicy(.regular)
        AutomationEngine.shared.lifecycleState = .activeWithWindow
        AutomationEngine.shared.start()
        Log.info("WindowLifecycleManager: Main window appeared - regular mode", category: .automation)
    }
    
    /// Called when the main window disappears.
    /// Sets activation policy to `.accessory` (no dock icon) after a short delay
    /// and tells AutomationEngine we're in `.menuBarOnly` state.
    func mainWindowDidDisappear() {
        AutomationEngine.shared.lifecycleState = .menuBarOnly
        // Delay the policy change slightly to avoid conflicting with window close animation
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        Log.info("WindowLifecycleManager: Main window disappeared - accessory mode", category: .automation)
    }
}
