import SwiftUI

/// Enhanced menu bar interface with live file counts, recent activity, and automation controls.
///
/// ## Features
/// - Live file counts by source folder
/// - Recent organization activity with undo hints
/// - Automation status and quick toggle
/// - Quick actions: Scan, Organize, Open Main Window
struct MenuBarView: View {
    @StateObject private var viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow

    init(viewModel: MenuBarViewModel = MenuBarViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

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

            StocksStyleMenuBarToggle(
                isEnabled: viewModel.automationStatus.isEnabled
            ) { shouldEnable in
                if shouldEnable != viewModel.automationStatus.isEnabled {
                    _ = viewModel.toggleAutomation()
                }
            }
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

    private func openMainInterface() {
        openWindow(id: "main")
    }
}

private struct StocksStyleMenuBarToggle: View {
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredState: Bool?

    private let containerCornerRadius: CGFloat = 13
    private let selectedCornerRadius: CGFloat = 10
    private let segmentWidth: CGFloat = 36
    private let segmentHeight: CGFloat = 22
    private let segmentPlateHorizontalInset: CGFloat = 3
    private let segmentPlateVerticalInset: CGFloat = 1

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(label: "On", value: true)

            Rectangle()
                .fill(separatorColor)
                .frame(width: 1, height: 16)
                .allowsHitTesting(false)

            segmentButton(label: "Off", value: false)
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                .fill(containerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(containerBorder, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(topRimColor, lineWidth: 0.6)
                )
        }
        .fixedSize(horizontal: true, vertical: false)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isEnabled)
        .animation(.easeOut(duration: 0.16), value: hoveredState)
    }

    private func segmentButton(label: String, value: Bool) -> some View {
        let isSelected = isEnabled == value
        let isHovered = hoveredState == value

        return Button(action: { onToggle(value) }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(activeBorder, lineWidth: 0.8)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(selectedHighlight)
                                .frame(height: 5)
                                .padding(.horizontal, 3)
                                .padding(.top, 1)
                        }
                        .shadow(color: selectedGlowColor, radius: 5, x: 0, y: 0)
                        .shadow(color: selectedDropShadowColor, radius: 2, x: 0, y: 1)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(hoverBorder, lineWidth: 0.7)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(hoverHighlight)
                                .frame(height: 4)
                                .padding(.horizontal, 3)
                                .padding(.top, 1)
                        }
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                Text(label)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(
                        isSelected
                            ? .formaLabel
                            : (isHovered ? .formaLabel : idleForeground)
                    )
                    .frame(width: segmentWidth, height: segmentHeight)
            }
            .frame(width: segmentWidth, height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveredState = value
            } else if hoveredState == value {
                hoveredState = nil
            }
        }
    }

    private var idleForeground: Color {
        colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel
    }

    private var separatorColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.20)
    }

    private var containerFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.formaBoneWhite.opacity(0.08))
        }
        return AnyShapeStyle(Color.formaBoneWhite.opacity(0.72))
    }

    private var containerBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(Color.FormaOpacity.medium)
            : Color.formaObsidian.opacity(0.18)
    }

    private var topRimColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.20)
            : Color.formaBoneWhite.opacity(0.45)
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.28)
            : Color.formaObsidian.opacity(0.12)
    }

    private var activeFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(0.20),
                        Color.formaBoneWhite.opacity(0.07),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(0.92),
                    Color.formaBoneWhite.opacity(0.74),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var selectedHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.14 : 0.22),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var selectedGlowColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.05)
            : Color.formaSteelBlue.opacity(0.04)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Color.formaObsidian.opacity(0.08)
    }

    private var hoverFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.formaBoneWhite.opacity(0.12))
        }
        return AnyShapeStyle(Color.formaObsidian.opacity(0.08))
    }

    private var hoverBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.14 : 0.22),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(viewModel: MenuBarViewModel())
}
