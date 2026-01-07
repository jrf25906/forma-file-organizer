import SwiftUI

struct SmartFeaturesSection: View {
    @AppStorage("feature.masterAI") private var masterAIEnabled = true
    @AppStorage(FeatureFlagService.Feature.patternLearning.rawValue) private var patternLearning = FeatureFlagService.Feature.patternLearning.defaultValue
    @AppStorage(FeatureFlagService.Feature.ruleSuggestions.rawValue) private var ruleSuggestions = FeatureFlagService.Feature.ruleSuggestions.defaultValue
    @AppStorage(FeatureFlagService.Feature.destinationPrediction.rawValue) private var destinationPrediction = FeatureFlagService.Feature.destinationPrediction.defaultValue
    @AppStorage(FeatureFlagService.Feature.contextDetection.rawValue) private var contextDetection = FeatureFlagService.Feature.contextDetection.defaultValue
    @AppStorage(FeatureFlagService.Feature.contentScanning.rawValue) private var contentScanning = FeatureFlagService.Feature.contentScanning.defaultValue
    @AppStorage(FeatureFlagService.Feature.analyticsAndInsights.rawValue) private var analyticsAndInsights = FeatureFlagService.Feature.analyticsAndInsights.defaultValue
    @AppStorage(FeatureFlagService.Feature.storageTrends.rawValue) private var storageTrends = FeatureFlagService.Feature.storageTrends.defaultValue
    @AppStorage(FeatureFlagService.Feature.usageStats.rawValue) private var usageStats = FeatureFlagService.Feature.usageStats.defaultValue
    @AppStorage(FeatureFlagService.Feature.storageHealthScore.rawValue) private var storageHealthScore = FeatureFlagService.Feature.storageHealthScore.defaultValue
    @AppStorage(FeatureFlagService.Feature.optimizationRecommendations.rawValue) private var optimizationRecommendations = FeatureFlagService.Feature.optimizationRecommendations.defaultValue
    @AppStorage(FeatureFlagService.Feature.analyticsReports.rawValue) private var analyticsReports = FeatureFlagService.Feature.analyticsReports.defaultValue
    @AppStorage(FeatureFlagService.Feature.backgroundMonitoring.rawValue) private var backgroundMonitoring = FeatureFlagService.Feature.backgroundMonitoring.defaultValue
    @AppStorage(FeatureFlagService.Feature.autoOrganize.rawValue) private var autoOrganize = FeatureFlagService.Feature.autoOrganize.defaultValue
    @AppStorage(FeatureFlagService.Feature.automationReminders.rawValue) private var automationReminders = FeatureFlagService.Feature.automationReminders.defaultValue

    // Automation user settings
    @AppStorage(AutomationUserSettings.Keys.mode) private var automationModeRaw = AutomationMode.scanOnly.rawValue
    @AppStorage(AutomationUserSettings.Keys.scanInterval) private var scanInterval = FormaConfig.Automation.defaultScanIntervalMinutes
    @AppStorage(AutomationUserSettings.Keys.scanOnLaunch) private var scanOnLaunch = true
    @AppStorage(AutomationUserSettings.Keys.notifications) private var automationNotifications = true

    private var automationMode: AutomationMode {
        AutomationMode(rawValue: automationModeRaw) ?? .scanOnly
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smart Features")
                        .font(.formaH2)
                        .foregroundColor(.formaObsidian)

                    Text("Control how Forma learns from your organization habits and makes suggestions.")
                        .font(.formaBody)
                        .foregroundColor(.formaSecondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, FormaSpacing.tight)

                // Master Toggle Section
                SettingsSection("AI Features") {
                    SettingsRow(
                        "Enable AI Features",
                        subtitle: "Master toggle for all smart features. Turn off to disable all AI-powered functionality."
                    ) {
                        Toggle("", isOn: $masterAIEnabled)
                            .toggleStyle(.switch)
                            .tint(.formaSteelBlue)
                    }
                }

                // Individual Features Section
                SettingsSection("Individual Features") {
                    VStack(spacing: 0) {
                        // Pattern Learning
                        SmartFeatureRow(
                            feature: .patternLearning,
                            isEnabled: $patternLearning,
                            masterEnabled: masterAIEnabled
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        // Rule Suggestions
                        SmartFeatureRow(
                            feature: .ruleSuggestions,
                            isEnabled: $ruleSuggestions,
                            masterEnabled: masterAIEnabled,
                            dependencyMet: patternLearning,
                            requiresFeature: .patternLearning
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        // Destination Prediction
                        SmartFeatureRow(
                            feature: .destinationPrediction,
                            isEnabled: $destinationPrediction,
                            masterEnabled: masterAIEnabled,
                            dependencyMet: patternLearning,
                            requiresFeature: .patternLearning
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        // Context Detection
                        SmartFeatureRow(
                            feature: .contextDetection,
                            isEnabled: $contextDetection,
                            masterEnabled: masterAIEnabled
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        // Content Scanning (with performance warning)
                        SmartFeatureRow(
                            feature: .contentScanning,
                            isEnabled: $contentScanning,
                            masterEnabled: masterAIEnabled,
                            showPerformanceWarning: true
                        )
                    }
                }

                SettingsSection("Analytics & Insights") {
                    VStack(spacing: 0) {
                        SmartFeatureRow(
                            feature: .analyticsAndInsights,
                            isEnabled: $analyticsAndInsights,
                            masterEnabled: masterAIEnabled
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        SmartFeatureRow(
                            feature: .storageTrends,
                            isEnabled: $storageTrends,
                            masterEnabled: masterAIEnabled,
                            dependencyMet: analyticsAndInsights,
                            requiresFeature: .analyticsAndInsights
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        SmartFeatureRow(
                            feature: .usageStats,
                            isEnabled: $usageStats,
                            masterEnabled: masterAIEnabled,
                            dependencyMet: analyticsAndInsights,
                            requiresFeature: .analyticsAndInsights
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        SmartFeatureRow(
                            feature: .storageHealthScore,
                            isEnabled: $storageHealthScore,
                            masterEnabled: masterAIEnabled,
                            dependencyMet: analyticsAndInsights,
                            requiresFeature: .analyticsAndInsights
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        SmartFeatureRow(
                            feature: .optimizationRecommendations,
                            isEnabled: $optimizationRecommendations,
                            masterEnabled: masterAIEnabled,
                            dependencyMet: analyticsAndInsights,
                            requiresFeature: .analyticsAndInsights
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        SmartFeatureRow(
                            feature: .analyticsReports,
                            isEnabled: $analyticsReports,
                            masterEnabled: masterAIEnabled,
                            dependencyMet: analyticsAndInsights,
                            requiresFeature: .analyticsAndInsights
                        )
                    }
                }

                // Automation Section
                SettingsSection("Automation") {
                    VStack(spacing: 0) {
                        // Background Monitoring
                        SmartFeatureRow(
                            feature: .backgroundMonitoring,
                            isEnabled: $backgroundMonitoring,
                            masterEnabled: masterAIEnabled
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        // Auto-Organize
                        SmartFeatureRow(
                            feature: .autoOrganize,
                            isEnabled: $autoOrganize,
                            masterEnabled: masterAIEnabled,
                            dependencyMet: backgroundMonitoring,
                            requiresFeature: .backgroundMonitoring
                        )

                        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

                        // Smart Reminders
                        SmartFeatureRow(
                            feature: .automationReminders,
                            isEnabled: $automationReminders,
                            masterEnabled: masterAIEnabled,
                            dependencyMet: backgroundMonitoring,
                            requiresFeature: .backgroundMonitoring
                        )
                    }
                }

                // Automation Behavior (only show when background monitoring is enabled)
                if masterAIEnabled && backgroundMonitoring {
                    SettingsSection("Automation Behavior") {
                        VStack(spacing: 0) {
                            // Mode Selector
                            AutomationModeRow(
                                selectedMode: $automationModeRaw,
                                autoOrganizeEnabled: autoOrganize
                            )

                            Divider().padding(.leading, FormaSpacing.standard)

                            // Scan Interval
                            SettingsRow(
                                "Background Scan Interval",
                                subtitle: "How often Forma scans for new files"
                            ) {
                                Picker("", selection: $scanInterval) {
                                    Text("Every 5 minutes").tag(5)
                                    Text("Every 15 minutes").tag(15)
                                    Text("Every 30 minutes").tag(30)
                                    Text("Every hour").tag(60)
                                    Text("Every 2 hours").tag(120)
                                }
                                .frame(width: 160)
                            }

                            Divider().padding(.leading, FormaSpacing.standard)

                            // Scan on Launch
                            SettingsRow(
                                "Scan on Launch",
                                subtitle: "Automatically scan when Forma starts"
                            ) {
                                Toggle("", isOn: $scanOnLaunch)
                                    .toggleStyle(.switch)
                                    .tint(.formaSteelBlue)
                            }

                            Divider().padding(.leading, FormaSpacing.standard)

                            // Automation Notifications
                            SettingsRow(
                                "Automation Notifications",
                                subtitle: "Get notified when files are organized or need attention"
                            ) {
                                Toggle("", isOn: $automationNotifications)
                                    .toggleStyle(.switch)
                                    .tint(.formaSteelBlue)
                                    .disabled(!automationReminders)
                                    .opacity(automationReminders ? 1 : Color.FormaOpacity.strong)
                            }
                        }
                    }
                }

                // Info Section
                if !masterAIEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.formaSteelBlue)
                            .font(.formaH2)

                        Text("AI features are currently disabled. Enable the master toggle above to use smart organization features.")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                    .padding(FormaSpacing.standard)
                    .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
                }

                // Reset Button
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .foregroundColor(.formaSteelBlue)
                .buttonStyle(.plain)
                .padding(.top, FormaSpacing.tight)
            }
            .padding(FormaSpacing.generous)
        }
        .background(Color.formaBoneWhite)
        .frame(minWidth: 400)
    }

    private func resetToDefaults() {
        masterAIEnabled = true
        analyticsAndInsights = FeatureFlagService.Feature.analyticsAndInsights.defaultValue
        patternLearning = FeatureFlagService.Feature.patternLearning.defaultValue
        ruleSuggestions = FeatureFlagService.Feature.ruleSuggestions.defaultValue
        destinationPrediction = FeatureFlagService.Feature.destinationPrediction.defaultValue
        contentScanning = FeatureFlagService.Feature.contentScanning.defaultValue
        contextDetection = FeatureFlagService.Feature.contextDetection.defaultValue
        storageTrends = FeatureFlagService.Feature.storageTrends.defaultValue
        usageStats = FeatureFlagService.Feature.usageStats.defaultValue
        storageHealthScore = FeatureFlagService.Feature.storageHealthScore.defaultValue
        optimizationRecommendations = FeatureFlagService.Feature.optimizationRecommendations.defaultValue
        analyticsReports = FeatureFlagService.Feature.analyticsReports.defaultValue
        backgroundMonitoring = FeatureFlagService.Feature.backgroundMonitoring.defaultValue
        autoOrganize = FeatureFlagService.Feature.autoOrganize.defaultValue
        automationReminders = FeatureFlagService.Feature.automationReminders.defaultValue
    }
}

// MARK: - Smart Feature Row Component

private struct SmartFeatureRow: View {
    let feature: FeatureFlagService.Feature
    @Binding var isEnabled: Bool
    let masterEnabled: Bool
    var dependencyMet: Bool = true
    var requiresFeature: FeatureFlagService.Feature? = nil
    var showPerformanceWarning: Bool = false

    private var isEffectivelyDisabled: Bool {
        !masterEnabled || !dependencyMet
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: feature.iconName)
                .font(.formaH3)
                .foregroundColor(isEffectivelyDisabled ? .formaSecondaryLabel : .formaSteelBlue)
                .frame(width: 32, height: 32)
                .background(
                    isEffectivelyDisabled
                        ? Color.formaSecondaryLabel.opacity(Color.FormaOpacity.light)
                        : Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
                )
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(feature.displayName)
                        .font(.formaBody)
                        .foregroundColor(isEffectivelyDisabled ? .formaSecondaryLabel : .formaObsidian)

                    if showPerformanceWarning && isEnabled && masterEnabled {
                        Image(systemName: "bolt.fill")
                            .font(.formaCaption)
                            .foregroundColor(.formaWarning)
                            .help("May impact performance on large files")
                    }
                }

                Text(feature.description)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
                    .lineLimit(2)

                    if let requiresFeature, !dependencyMet && masterEnabled {
                        Text("Requires \"\(requiresFeature.displayName)\" to be enabled")
                            .font(.formaSmall)
                            .foregroundColor(.formaWarning)
                    }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .tint(.formaSteelBlue)
                .disabled(isEffectivelyDisabled)
                .opacity(isEffectivelyDisabled ? Color.FormaOpacity.strong : 1)
        }
        .padding(FormaSpacing.large)
        .contentShape(Rectangle())
    }
}

// MARK: - Automation Mode Row Component

private struct AutomationModeRow: View {
    @Binding var selectedMode: String
    let autoOrganizeEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "gearshape.2")
                    .font(.formaBodyLarge)
                    .foregroundColor(.formaSteelBlue)

                Text("Automation Mode")
                    .font(.formaBodyBold)
                    .foregroundColor(.formaObsidian)
            }

            // Mode options
            VStack(spacing: 8) {
                ForEach(AutomationMode.allCases) { mode in
                    AutomationModeOption(
                        mode: mode,
                        isSelected: selectedMode == mode.rawValue,
                        isDisabled: mode == .scanAndOrganize && !autoOrganizeEnabled,
                        onSelect: { selectedMode = mode.rawValue }
                    )
                }
            }

            // Warning if auto-organize is disabled but selected
                if selectedMode == AutomationMode.scanAndOrganize.rawValue && !autoOrganizeEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.formaCompact)
                            .foregroundColor(.formaWarning)

                        Text("Auto-organize is disabled. Enable it above to use this mode.")
                            .font(.formaSmall)
                            .foregroundColor(.formaWarning)
                    }
                    .padding(.top, FormaSpacing.micro)
                }
        }
        .padding(FormaSpacing.large)
    }
}

// MARK: - Automation Mode Option Component

private struct AutomationModeOption: View {
    let mode: AutomationMode
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            if !isDisabled {
                onSelect()
            }
        }) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isDisabled ? Color.formaSecondaryLabel.opacity(Color.FormaOpacity.overlay) : Color.formaSteelBlue, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(isDisabled ? Color.formaSecondaryLabel.opacity(Color.FormaOpacity.overlay) : Color.formaSteelBlue)
                            .frame(width: 12, height: 12)
                    }
                }

                // Icon
                Image(systemName: mode.iconName)
                    .font(.formaBodyLarge)
                    .foregroundColor(isDisabled ? .formaSecondaryLabel : (isSelected ? .formaSteelBlue : .formaObsidian))
                    .frame(width: 24)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.formaBody)
                        .foregroundColor(isDisabled ? .formaSecondaryLabel : .formaObsidian)

                    Text(mode.description)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.vertical, FormaSpacing.tight)
            .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(isSelected && !isDisabled ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .stroke(isSelected && !isDisabled ? Color.formaSteelBlue.opacity(Color.FormaOpacity.medium) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? Color.FormaOpacity.strong : 1)
    }
}
