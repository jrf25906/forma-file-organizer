import SwiftUI
import ServiceManagement

struct GeneralSettingsSection: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch = true
    @AppStorage(ScanOptionsResolver.scanSubfoldersKey) private var scanSubfolders = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @State private var launchAtLoginErrorMessage: String?
    @State private var isApplyingLaunchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(spacing: FormaSpacing.generous) {
                // Appearance Section
                SettingsSection("Appearance") {
                    SettingsRow("Theme", subtitle: "Choose how Forma looks") {
                        Picker("", selection: $appearanceMode) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Label(mode.displayName, systemImage: mode.iconName)
                                    .tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }

                // Startup Section
                SettingsSection("Startup") {
                    VStack(spacing: 0) {
                        SettingsRow("Launch at Login") {
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .tint(.formaSteelBlue)
                        }

                        Divider().padding(.leading, FormaSpacing.standard)

                        SettingsRow("Auto-scan on Launch", subtitle: "Scan Desktop, Downloads, and Documents when the app starts") {
                            Toggle("", isOn: $autoScanOnLaunch)
                                .toggleStyle(.switch)
                                .tint(.formaSteelBlue)
                        }

                        Divider().padding(.leading, FormaSpacing.standard)

                        SettingsRow("Scan Subfolders", subtitle: "Include files in nested folders during scans") {
                                Toggle("", isOn: $scanSubfolders)
                                    .toggleStyle(.switch)
                                    .tint(.formaSteelBlue)
                                    .disabled(!FeatureFlagService.shared.getRawValue(.recursiveScanning))
                        }
                    }
                }

                // Notifications Section
                SettingsSection("Notifications") {
                    SettingsRow("Show Notifications", subtitle: "Show system notifications when files are organized") {
                        Toggle("", isOn: $showNotifications)
                            .toggleStyle(.switch)
                            .tint(.formaSteelBlue)
                    }
                }

                // Help Section
                SettingsSection("Help") {
                    SettingsRow("Guided Tour", subtitle: "Walk through Forma's main features") {
                        Button("Replay Tour") {
                            UserDefaults.standard.set(false, forKey: "hasSeenGuidedTour")
                            // Post notification so DashboardView can pick it up
                            NotificationCenter.default.post(name: .replayGuidedTour, object: nil)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Reset Button
                Button("Reset All Settings") {
                    resetAllSettings()
                }
                .foregroundColor(.formaError)
                .buttonStyle(.plain)
                .padding(.top, FormaSpacing.tight)
            }
            .padding(FormaSpacing.generous)
        }
        .background(Color.clear)
        .frame(minWidth: 400)
        .onAppear {
            syncLaunchAtLoginStateFromSystem()
        }
        .onChange(of: launchAtLogin) { _, newValue in
            applyLaunchAtLoginChange(enabled: newValue)
        }
        .alert(
            "Couldn't Update Launch at Login",
            isPresented: Binding(
                get: { launchAtLoginErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        launchAtLoginErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                launchAtLoginErrorMessage = nil
            }
        } message: {
            Text(launchAtLoginErrorMessage ?? "Unknown error")
        }
    }

    private func syncLaunchAtLoginStateFromSystem() {
        guard #available(macOS 13.0, *) else { return }
        isApplyingLaunchAtLogin = true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        isApplyingLaunchAtLogin = false
    }

    private func applyLaunchAtLoginChange(enabled: Bool) {
        guard !isApplyingLaunchAtLogin else { return }
        // Use SMAppService for macOS 13+
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status != .enabled {
                        try service.register()
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                }
            } catch {
                Log.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)", category: .ui)
                isApplyingLaunchAtLogin = true
                launchAtLogin = !enabled
                isApplyingLaunchAtLogin = false
                launchAtLoginErrorMessage = "macOS rejected the startup-item change. Check System Settings > General > Login Items and try again."
            }
        }
    }

    private func resetAllSettings() {
        launchAtLogin = false
        showNotifications = true
        autoScanOnLaunch = true
        scanSubfolders = false
        appearanceMode = AppearanceMode.system.rawValue
        applyLaunchAtLoginChange(enabled: false)
    }
}
