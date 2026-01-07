import SwiftUI
import SwiftData

/// View modifier that manages AutomationEngine lifecycle based on app state.
///
/// This modifier:
/// - Configures the engine with required dependencies on first appear
/// - Starts automation when the window becomes active
/// - Pauses automation when the window is closed or app backgrounds
/// - Stops automation when the view disappears
///
/// ## Usage
/// ```swift
/// DashboardView()
///     .automationLifecycle(modelContainer: container)
/// ```
@MainActor
struct AutomationLifecycleModifier: ViewModifier {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    /// Tracks whether we've configured the engine
    @State private var isConfigured = false

    /// The FileOrganizationCoordinator (shared with DashboardViewModel)
    @StateObject private var organizationCoordinator = FileOrganizationCoordinator()

    func body(content: Content) -> some View {
        content
            .onAppear {
                configureAutomationEngineIfNeeded()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
            .onDisappear {
                // Stop automation when the main window disappears
                AutomationEngine.shared.stop()
            }
    }

    // MARK: - Private Methods

    private func configureAutomationEngineIfNeeded() {
        guard !isConfigured else { return }

        let engine = AutomationEngine.shared

        // Create the scan provider
        let scanProvider = DashboardFileScanProvider()

        // Configure the engine
        engine.configure(
            modelContext: modelContext,
            organizationCoordinator: organizationCoordinator,
            scanProvider: scanProvider
        )

        isConfigured = true
        Log.info("AutomationLifecycleModifier: Engine configured", category: .automation)

        // Start with current lifecycle state
        engine.lifecycleState = .activeWithWindow
        engine.start()
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        let engine = AutomationEngine.shared

        switch newPhase {
        case .active:
            // App is foregrounded and active
            engine.lifecycleState = .activeWithWindow
            if isConfigured {
                engine.start()
            }
            Log.info("AutomationLifecycleModifier: Scene active", category: .automation)

        case .inactive:
            // App is visible but not receiving events (e.g., switching apps)
            engine.lifecycleState = .activeWindowClosed
            Log.info("AutomationLifecycleModifier: Scene inactive", category: .automation)

        case .background:
            // App is in the background
            engine.lifecycleState = .backgrounded
            engine.stop()
            Log.info("AutomationLifecycleModifier: Scene backgrounded", category: .automation)

        @unknown default:
            Log.warning("AutomationLifecycleModifier: Unknown scene phase", category: .automation)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds automation lifecycle management to this view.
    ///
    /// This modifier manages the AutomationEngine's lifecycle based on
    /// the app's scene phase, starting and stopping automation appropriately.
    ///
    /// Apply this to your main content view (e.g., DashboardView).
    func automationLifecycle() -> some View {
        modifier(AutomationLifecycleModifier())
    }
}
