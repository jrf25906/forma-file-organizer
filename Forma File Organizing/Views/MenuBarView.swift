import SwiftUI

/// Enhanced menu bar interface with live file counts, recent activity, and automation controls.
///
/// ## Features
/// - Live file counts by source folder
/// - Recent organization activity with undo hints
/// - Automation status and quick toggle
/// - Quick actions: Scan, Organize, Open Main Window
struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow

    /// Callback to open the main app interface
    var openMainInterface: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            headerSection

            Divider()
                .padding(.horizontal, FormaSpacing.standard)

            // File counts by folder
            if viewModel.hasPendingFiles {
                folderCountsSection
                Divider()
                    .padding(.horizontal, FormaSpacing.standard)
            }

            // Recent activity
            if !viewModel.recentActivity.isEmpty {
                recentActivitySection
                Divider()
                    .padding(.horizontal, FormaSpacing.standard)
            }

            // Automation status
            automationSection

            Divider()
                .padding(.horizontal, FormaSpacing.standard)

            // Actions
            actionsSection
        }
        .frame(width: 280)
        .background(Color.formaBackground)
        .onAppear {
            viewModel.startRefreshing()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: FormaSpacing.tight) {
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text("Forma")
                    .font(.formaMenuTitle)
                    .foregroundColor(.formaLabel)

                Text(viewModel.pendingSummary)
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()

            // Status indicator
            statusIndicatorView
        }
        .padding(FormaSpacing.standard)
    }

    @ViewBuilder
    private var statusIndicatorView: some View {
        switch viewModel.statusIndicator {
        case .clear:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.formaSage)
                .font(.system(size: 18, weight: .medium))
        case .low:
            Circle()
                .fill(Color.formaSteelBlue)
                .frame(width: 10, height: 10)
        case .medium:
            Circle()
                .fill(Color.formaWarning)
                .frame(width: 10, height: 10)
        case .high:
            ZStack {
                Circle()
                    .stroke(Color.formaError.opacity(Color.FormaOpacity.overlay), lineWidth: 2)
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color.formaError)
                    .frame(width: 10, height: 10)
            }
        }
    }

    // MARK: - Folder Counts Section

    private var folderCountsSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            ForEach(viewModel.folderStatuses) { folder in
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: folder.iconName)
                        .font(.formaMenuItem)
                        .foregroundColor(.formaTertiaryLabel)
                        .frame(width: 20)

                    Text(folder.name)
                        .font(.formaMenuItem)
                        .foregroundColor(.formaLabel)

                    Spacer()

                    Text("\(folder.count)")
                        .font(.formaMenuTitle)
                        .foregroundColor(folder.count > 0 ? .formaLabel : .formaTertiaryLabel)
                }
            }
        }
        .padding(FormaSpacing.standard)
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text("Recent Activity")
                .font(.formaMenuMetadata)
                .fontWeight(.medium)
                .foregroundColor(.formaTertiaryLabel)
                .textCase(.uppercase)
                .padding(.bottom, FormaSpacing.micro)

            ForEach(viewModel.recentActivity) { activity in
                recentActivityRow(activity)
            }
        }
        .padding(FormaSpacing.standard)
    }

    private func recentActivityRow(_ activity: FormaActions.RecentActivity) -> some View {
        HStack(spacing: FormaSpacing.tight) {
            // File type indicator
            Image(systemName: activity.iconName)
                .font(.formaMenuMetadata)
                .foregroundColor(.formaSage)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.fileName)
                    .font(.formaMenuItem)
                    .foregroundColor(.formaLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(activity.destination)
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaTertiaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(activity.relativeTime)
                .font(.formaMenuMetadata)
                .foregroundColor(.formaQuaternaryLabel)
        }
    }

    // MARK: - Automation Section

    private var automationSection: some View {
        HStack(spacing: FormaSpacing.tight) {
            Image(systemName: viewModel.automationStatus.mode.iconName)
                .font(.formaMenuItem)
                .foregroundColor(automationStatusColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Automation")
                    .font(.formaMenuItem)
                    .foregroundColor(.formaLabel)

                Text(viewModel.automationStatus.statusText)
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()

            // Toggle pill
            Button(action: {
                _ = viewModel.toggleAutomation()
            }) {
                Text(viewModel.automationStatus.isEnabled ? "On" : "Off")
                    .font(.formaMenuMetadata)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.automationStatus.isEnabled ? .formaSage : .formaTertiaryLabel)
                    .padding(.horizontal, FormaSpacing.tight)
                    .padding(.vertical, FormaSpacing.micro)
                    .background(
                        Capsule()
                            .fill(
                                viewModel.automationStatus.isEnabled
                                    ? Color.formaSage.opacity(Color.FormaOpacity.light)
                                    : Color.formaLabel.opacity(Color.FormaOpacity.subtle)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.standard)
    }

    private var automationStatusColor: Color {
        switch viewModel.automationStatus.mode {
        case .off:
            return .formaTertiaryLabel
        case .scanOnly:
            return .formaSteelBlue
        case .scanAndOrganize:
            return .formaSage
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: FormaSpacing.tight) {
            // Primary action button
            Button(action: openMainInterface) {
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: viewModel.hasPendingFiles ? "play.fill" : "arrow.up.forward.square")
                        .font(.formaMenuTitle)
                    Text(viewModel.hasPendingFiles ? "Scan & Review" : "Open Forma")
                        .font(.formaMenuTitle)
                }
                .foregroundColor(.formaBoneWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.tight)
                .background(Color.formaSteelBlue)
                .formaCornerRadius(FormaRadius.control)
            }
            .buttonStyle(.plain)

            // Secondary actions row
            HStack(spacing: FormaSpacing.tight) {
                // Quick organize (if there are high-confidence files)
                if viewModel.hasPendingFiles {
                    Button(action: {
                        Task {
                            _ = await viewModel.organizeHighConfidenceFiles()
                        }
                    }) {
                        HStack(spacing: FormaSpacing.micro) {
                            Image(systemName: "bolt.fill")
                                .font(.formaMenuMetadata)
                            Text("Quick Organize")
                                .font(.formaMenuMetadata)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.formaSteelBlue)
                        .padding(.vertical, FormaSpacing.micro + 2)
                        .padding(.horizontal, FormaSpacing.tight)
                        .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                        .formaCornerRadius(FormaRadius.small)
                    }
                    .buttonStyle(.plain)
                    .help("Organize files with 90%+ confidence")
                }

                Spacer()

                // Settings
                Button(action: openSettings) {
                    Text("Settings")
                        .font(.formaMenuMetadata)
                        .fontWeight(.medium)
                        .foregroundColor(.formaSecondaryLabel)
                        .padding(.vertical, FormaSpacing.micro + 2)
                        .padding(.horizontal, FormaSpacing.tight)
                        .background(Color.formaLabel.opacity(Color.FormaOpacity.subtle))
                        .formaCornerRadius(FormaRadius.small)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)

                // Quit
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.formaMenuMetadata)
                        .fontWeight(.medium)
                        .foregroundColor(.formaError)
                        .padding(.vertical, FormaSpacing.micro + 2)
                        .padding(.horizontal, FormaSpacing.tight)
                        .background(Color.formaError.opacity(Color.FormaOpacity.subtle))
                        .formaCornerRadius(FormaRadius.small)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FormaSpacing.standard)
    }

    // MARK: - Helpers

    private func openSettings() {
        // Simulate Cmd+, keypress to open Settings
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: ",",
            charactersIgnoringModifiers: ",",
            isARepeat: false,
            keyCode: 43
        )
        if let event = event {
            NSApp.postEvent(event, atStart: true)
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(viewModel: MenuBarViewModel()) {
        print("Open main interface")
    }
}
