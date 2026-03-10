import SwiftUI
import SwiftData
import AppKit

@main
@MainActor
struct Forma_File_OrganizingApp: App {

    let container: ModelContainer

    @StateObject private var services: AppServices
    @StateObject private var dashboardViewModel: DashboardViewModel

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    private static func uiTestWindowSize() -> (width: CGFloat, height: CGFloat)? {
        guard isUITesting else { return nil }
        guard let raw = ProcessInfo.processInfo.environment["FORMA_WINDOW_SIZE"] else { return nil }
        let parts = raw.lowercased().split(separator: "x", maxSplits: 1).map(String.init)
        guard parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]) else { return nil }
        guard width > 0, height > 0 else { return nil }
        return (CGFloat(width), CGFloat(height))
    }

    private var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        Self.isUITesting
    }
    
    // MARK: - Schema Definition (DRY Principle)
    static let appSchema = Schema([
        Rule.self,
        RuleCategory.self,
        FileItem.self,
        ActivityItem.self,
        StorageSnapshot.self,
        LearnedPattern.self,
        ProjectCluster.self,
        MLTrainingHistory.self
    ])

    init() {
        let appServices = AppServices()
        _services = StateObject(wrappedValue: appServices)
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(services: appServices))

        // Check if running UI Tests (take precedence over XCTestConfigurationFilePath)
        if Self.isUITesting {
            // Allow UI tests to force appearance for deterministic screenshots.
            // Expected values match `AppearanceMode.rawValue`: system|light|dark
            if let forcedAppearance = ProcessInfo.processInfo.environment["FORMA_APPEARANCE_MODE"],
               AppearanceMode(rawValue: forcedAppearance) != nil {
                UserDefaults.standard.set(forcedAppearance, forKey: "appearanceMode")
            }

            do {
                let modelConfiguration = ModelConfiguration(schema: Self.appSchema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: Self.appSchema, configurations: [modelConfiguration])
                
                // Seed UI Test Mocks
                let context = ModelContext(container)
                for mock in FileItem.uiTestMocks {
                    context.insert(mock)
                }
                do {
                    try context.save()
                } catch {
                    Log.error("Failed to save UI test mocks to SwiftData: \(error.localizedDescription)", category: .general)
                    // In UI tests, this is non-critical - mocks are in memory anyway
                }
            } catch {
                fatalError("Could not create UI Test ModelContainer: \(error)")
            }
            return
        }

        // Check if running tests (Unit Tests)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // Create an in-memory container for testing to avoid side effects and crashes
            do {
                let modelConfiguration = ModelConfiguration(schema: Self.appSchema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: Self.appSchema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create Test ModelContainer: \(error)")
            }
            return
        }

        do {
            // Allow migration when schema changes
            let modelConfiguration = ModelConfiguration(
                schema: Self.appSchema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )

            container = try ModelContainer(for: Self.appSchema, configurations: [modelConfiguration])

            // Seed default rules
            let context = ModelContext(container)
            let ruleService = RuleService(modelContext: context)
            do {
                try ruleService.seedDefaultRules()
            } catch {
                Log.error("Failed to seed default rules: \(error.localizedDescription)", category: .general)
                // Non-critical - app can still function without default rules
            }

            // Initialize categories and migrate existing rules
            let categoryService = CategoryService(modelContext: context)
            do {
                try categoryService.createDefaultCategoryIfNeeded()
                let migratedCount = try categoryService.migrateExistingRulesToDefaultCategory()
                if migratedCount > 0 {
                    Log.info("Migrated \(migratedCount) rules to General category", category: .general)
                }
            } catch {
                Log.error("Failed to initialize categories: \(error.localizedDescription)", category: .general)
                // Non-critical - rules will still work without explicit category assignment
            }

            // Initialize notification service (requests authorization)
            _ = appServices.notificationService

            // Enable performance console logging for debugging
            #if DEBUG
            PerformanceMonitor.shared.consoleLoggingEnabled = true
            #endif

            // Configure FormaActions with full capabilities for menu bar and AppIntents
            configureFormaActions()

            scheduleAnalyticsMaintenance(using: appServices)

        } catch {
            // FATAL: If the store cannot be opened or migrated, we MUST NOT delete it to try again.
            // Deleting the store causes data loss. Instead, we log the exact error and crash,
            // which preserves the user's data on disk so it can be recovered or migrated manually.
            let errorMessage = "CRITICAL: ModelContainer creation failed. The database could not be opened or migrated. Error: \(error.localizedDescription)"
            Log.error(errorMessage, category: .general)
            
            // In a full production macOS app, we would ideally show an NSAlert here before terminating,
            // but since SwiftUI App init is synchronous and before the runloop, fatalError is the safest
            // way to halt execution without data loss.
            fatalError(errorMessage)
        }
    }
    
    @SceneBuilder
    var body: some Scene {
        mainWindowScene
        settingsScene
        MenuBarScene(container: container, isTesting: isTesting)
    }

    // MARK: - Scenes

    private var mainWindowScene: some Scene {
        let windowSize = Self.uiTestWindowSize()
        return WindowGroup(id: "main") {
            dashboardRootView
        }
        .defaultSize(
            width: windowSize?.width ?? FormaSpacing.Window.preferredWidth,
            height: windowSize?.height ?? FormaSpacing.Window.preferredHeight
        )
        .modelContainer(container)
        .commands {
            SidebarCommands()
        }
        .windowToolbarStyle(.unified)
    }

    private var dashboardRootView: some View {
        let windowSize = Self.uiTestWindowSize()
        return DashboardView()
            .frame(
                minWidth: windowSize?.width ?? 1200,
                minHeight: windowSize?.height ?? 800
            )
            .environmentObject(services)
            .environmentObject(dashboardViewModel)
            .background(WindowChromeConfiguratorView())
            .automationLifecycle()  // v1.4: Automation engine lifecycle management
    }

    private var settingsScene: some Scene {
        Settings {
            SettingsView()
        }
        .modelContainer(container)
    }

    /// Configures FormaActions with full capabilities for scanning and organizing.
    /// This enables the menu bar and AppIntents to perform file operations.
    private func configureFormaActions() {
        let scanProvider = DashboardFileScanProvider()
        let coordinator = FileOrganizationCoordinator()

        FormaActions.shared.configureFull(
            modelContext: container.mainContext,
            organizationCoordinator: coordinator,
            scanProvider: scanProvider
        )
    }

    private func scheduleAnalyticsMaintenance(using services: AppServices) {
        Task { @MainActor in
            do {
                try await services.analyticsService.recordDailySnapshotIfNeeded(container: container)
                _ = try await services.reportService.generateWeeklyReportIfNeeded(container: container)
            } catch {
                Log.error("Analytics maintenance failed: \(error.localizedDescription)", category: .analytics)
            }
        }
    }

}

private struct WindowChromeConfiguratorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            configure(window)
        }
    }

    private func configure(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
    }
}
