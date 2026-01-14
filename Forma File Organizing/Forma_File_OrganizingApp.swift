import SwiftUI
import SwiftData

@main
@MainActor
struct Forma_File_OrganizingApp: App {

    let container: ModelContainer

    @StateObject private var services: AppServices
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var menuBarViewModel: MenuBarViewModel
    
    // MARK: - Schema Definition (DRY Principle)
    private static let appSchema = Schema([
        Rule.self,
        RuleCategory.self,
        FileItem.self,
        ActivityItem.self,
        StorageSnapshot.self,
        CustomFolder.self,
        LearnedPattern.self,
        ProjectCluster.self,
        MLTrainingHistory.self
    ])

    init() {
        let appServices = AppServices()
        _services = StateObject(wrappedValue: appServices)
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(services: appServices))
        _menuBarViewModel = StateObject(wrappedValue: MenuBarViewModel())

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
        
        // Check if running UI Tests
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
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
            // IMPROVED: Try to backup before deleting
            Log.error("ModelContainer creation failed with error: \(error)", category: .general)
            Log.info("Attempting to backup and reset store...", category: .general)
            
            // Get the default store URL
            let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
            let backupURL = URL.applicationSupportDirectory.appending(path: "default.store.backup")
            
            // Backup the old store if it exists
            if FileManager.default.fileExists(atPath: storeURL.path) {
                do {
                    // Remove old backup if exists
                    try? FileManager.default.removeItem(at: backupURL)
                    // Create new backup
                    try FileManager.default.copyItem(at: storeURL, to: backupURL)
                    Log.info("Created backup at: \(backupURL.path)", category: .general)
                } catch {
                    Log.error("Failed to create backup: \(error)", category: .general)
                }
            }
            
            // Try to delete the old store
            try? FileManager.default.removeItem(at: storeURL)
            
            // Try again with a fresh store
            do {
                let modelConfiguration = ModelConfiguration(
                    schema: Self.appSchema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )
                container = try ModelContainer(for: Self.appSchema, configurations: [modelConfiguration])
                
                // Seed default rules for fresh store
                let context = ModelContext(container)
                let ruleService = RuleService(modelContext: context)
                do {
                    try ruleService.seedDefaultRules()
                } catch {
                    Log.error("Failed to seed default rules after store reset: \(error.localizedDescription)", category: .general)
                    // Non-critical - app can still function without default rules
                }

                // Initialize categories for fresh store
                let categoryService = CategoryService(modelContext: context)
                do {
                    try categoryService.createDefaultCategoryIfNeeded()
                    _ = try categoryService.migrateExistingRulesToDefaultCategory()
                } catch {
                    Log.error("Failed to initialize categories after store reset: \(error.localizedDescription)", category: .general)
                }

                _ = appServices.notificationService

                #if DEBUG
                PerformanceMonitor.shared.consoleLoggingEnabled = true
                #endif

                // Configure FormaActions for fresh store
                configureFormaActions()

                Log.info("Successfully created fresh store. Backup available at: \(backupURL.path)", category: .general)
                scheduleAnalyticsMaintenance(using: appServices)
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }
    
    var body: some Scene {
        // Main Window (Dashboard)
        WindowGroup(id: "main") {
            DashboardView()
                .frame(minWidth: 1200, minHeight: 800)
                // .background(.regularMaterial) removed to allow custom PrimaryBackgroundView to control background
                .background(Color.clear)
                .configureForFullHeightSidebar()  // Xcode/ChatGPT-style window configuration
                .environment(\.openSettings, SettingsOpener.open)
                .environmentObject(services)
                .environmentObject(dashboardViewModel)
                .automationLifecycle()  // v1.4: Automation engine lifecycle management
        }
        .defaultSize(width: FormaSpacing.Window.preferredWidth, height: FormaSpacing.Window.preferredHeight)
        .modelContainer(container)
        .commands {
            SidebarCommands()
        }
        .windowToolbarStyle(.unified(showsTitle: false))

        // Settings Scene (opens with Cmd+, and programmatically)
        Settings {
            SettingsView()
        }
        .modelContainer(container)

        // Menu Bar Extra - Enhanced with live file counts and recent activity
        MenuBarExtra("Forma", image: "MenuBarIcon") {
            MenuBarView(viewModel: menuBarViewModel) {
                openMainWindow()
            }
            .onAppear {
                // Configure FormaActions with read-only access for menu bar
                // (Full configuration happens in DashboardView when coordinators are available)
                FormaActions.shared.configureReadOnly(modelContext: container.mainContext)
            }
        }
        .menuBarExtraStyle(.window) // Use .window for custom SwiftUI content
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

    /// Opens the main Forma window, bringing the app to the foreground
    private func openMainWindow() {
        // Activate the app and bring to foreground
        NSApp.activate(ignoringOtherApps: true)

        // Find and focus the main window, or open a new one
        if let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            // Open a new main window if none exists
            // Note: @Environment(\.openWindow) doesn't work here since we're in the App struct
            // The NSApp.activate should trigger WindowGroup to open if no window exists
        }
    }
}
