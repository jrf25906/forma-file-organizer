import SwiftUI
import ServiceManagement

struct GeneralSettingsSection: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch = true
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

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
                        }

                        Divider().padding(.leading, FormaSpacing.standard)

                        SettingsRow("Auto-scan on Launch", subtitle: "Scan Desktop, Downloads, and Documents when the app starts") {
                            Toggle("", isOn: $autoScanOnLaunch)
                                .toggleStyle(.switch)
                        }
                    }
                }

                // Notifications Section
                SettingsSection("Notifications") {
                    SettingsRow("Show Notifications", subtitle: "Show system notifications when files are organized") {
                        Toggle("", isOn: $showNotifications)
                            .toggleStyle(.switch)
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
        .background(Color.formaBackground)
        .frame(minWidth: 400)
    }

    private func setLaunchAtLogin(enabled: Bool) {
        // Use SMAppService for macOS 13+
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status == .notRegistered {
                        try service.register()
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                }
            } catch {
                Log.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)", category: .ui)
            }
        }
    }

    private func resetAllSettings() {
        launchAtLogin = false
        showNotifications = true
        autoScanOnLaunch = true
        appearanceMode = AppearanceMode.system.rawValue
        setLaunchAtLogin(enabled: false)
    }
}
