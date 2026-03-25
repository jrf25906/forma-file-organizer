import SwiftUI

/// Compact menu bar interface for quick review, automation status, and shortcuts.
struct MenuBarView: View {
    @StateObject private var viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    private let autoRefreshOnAppear: Bool

    init(
        viewModel: MenuBarViewModel = MenuBarViewModel(),
        autoRefreshOnAppear: Bool = true
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.autoRefreshOnAppear = autoRefreshOnAppear
    }

    var body: some View {
        ZStack {
            GradientBackdropView(
                intensity: colorScheme == .dark ? Color.FormaOpacity.overlay : 0.9,
                blurRadius: FormaSpacing.huge + FormaSpacing.standard
            )

            MenuBarSurface(
                tier: .overlay,
                tint: shellTint,
                cornerRadius: FormaRadius.large,
                padding: FormaSpacing.tight
            ) {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    headerSection

                    if FeatureFlagService.shared.isEnabled(.menuBarFileReview), viewModel.hasPendingFiles {
                        reviewQueueSection
                    } else {
                        allClearSection
                    }

                    supportRowsSection
                    footerSection
                }
            }
        }
        .padding(4)
        .frame(width: 344)
        .background(Color.clear)
        .onAppear {
            guard autoRefreshOnAppear else { return }
            viewModel.startRefreshing()
        }
        .onDisappear {
            guard autoRefreshOnAppear else { return }
            viewModel.stopRefreshing()
        }
    }

    private var shellTint: Color {
        if viewModel.hasPendingFiles {
            return Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.18 : 0.10)
        }
        return Color.formaSage.opacity(colorScheme == .dark ? 0.16 : 0.08)
    }

    private var headerSection: some View {
        HStack(spacing: FormaSpacing.tight) {
            FormaChromeSurface(
                cornerRadius: FormaRadius.control,
                fill: colorScheme == .dark
                    ? Color.formaControlBackground.opacity(0.82)
                    : Color.formaBoneWhite.opacity(0.92),
                tint: .formaSteelBlue,
                elevation: .raised
            )
            .frame(width: 30, height: 30)
            .overlay(
                FormaLogo(style: .mark, height: 16)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("Forma")
                    .font(.formaH3)
                    .foregroundColor(.formaLabel)

                Text(headerSubtitle)
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaSecondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: FormaSpacing.tight)

            automationStatusPill
        }
    }

    private var headerSubtitle: String {
        if viewModel.hasPendingFiles {
            return "\(viewModel.pendingFiles.count) item\(viewModel.pendingFiles.count == 1 ? "" : "s") in review queue"
        }

        return viewModel.automationStatus.statusText
    }

    @ViewBuilder
    private var automationStatusPill: some View {
        let status = viewModel.automationStatus

        HStack(spacing: FormaSpacing.micro) {
            Circle()
                .fill(automationTint)
                .frame(width: 7, height: 7)

            Text(automationLabel)
                .font(.formaMenuMetadata)
                .foregroundColor(automationTint)
                .monospacedDigit()
        }
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, 6)
        .background(
            FormaChromeSurface(
                cornerRadius: FormaRadius.pill,
                fill: colorScheme == .dark
                    ? Color.formaControlBackground.opacity(0.76)
                    : Color.formaBoneWhite.opacity(0.92),
                tint: automationTint,
                elevation: .resting
            )
        )
        .help(status.statusText)
    }

    private var automationTint: Color {
        switch viewModel.automationStatus.mode {
        case .scanAndOrganize:
            return .formaSage
        case .scanOnly:
            return .formaWarning
        case .off:
            return .formaSecondaryLabel
        }
    }

    private var automationLabel: String {
        switch viewModel.automationStatus.mode {
        case .scanAndOrganize:
            return "Watching"
        case .scanOnly:
            return "Scan Only"
        case .off:
            return "Off"
        }
    }

    private var reviewQueueSection: some View {
        Group {
            if let file = viewModel.currentReviewFile {
                MenuBarFileReviewCard(
                    file: file,
                    paginationText: viewModel.reviewPaginationText,
                    isOrganizing: viewModel.isOrganizingCurrent,
                    canGoBack: viewModel.currentReviewIndex > 0,
                    canGoForward: viewModel.currentReviewIndex < viewModel.pendingFiles.count - 1,
                    onOrganize: {
                        Task { await viewModel.organizeCurrentFile() }
                    },
                    onSkip: {
                        viewModel.skipCurrentFile()
                    },
                    onPrevious: {
                        viewModel.navigateReview(direction: .previous)
                    },
                    onNext: {
                        viewModel.navigateReview(direction: .next)
                    }
                )
                .id(file.path)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.currentReviewFile?.path)
    }

    private var allClearSection: some View {
        MenuBarFlatRow(tint: .formaSage, cornerRadius: FormaRadius.card, padding: FormaSpacing.standard) {
            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                summaryIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text("All clear")
                        .font(.formaBodySemibold)
                        .foregroundColor(.formaLabel)

                    Text(clearSummaryText)
                        .font(.formaMenuMetadata)
                        .foregroundColor(.formaSecondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: FormaSpacing.tight)

                summaryCountBadge
            }
        }
    }

    private var clearSummaryText: String {
        if viewModel.automationStatus.mode == .off {
            return "Nothing needs attention right now."
        }

        if viewModel.automationStatus.isWatchingFolders {
            return "No files are waiting. Forma is live-watching your folders."
        }

        return "No files are waiting. Forma is ready for the next scan."
    }

    private var summaryIcon: some View {
        FormaChromeSurface(
            cornerRadius: FormaRadius.control,
            fill: colorScheme == .dark
                ? Color.formaControlBackground.opacity(0.78)
                : Color.formaBoneWhite.opacity(0.90),
            tint: .formaSage,
            elevation: .resting
        )
        .frame(width: 34, height: 34)
        .overlay(
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.formaSage)
        )
    }

    private var summaryCountBadge: some View {
        Text("0")
            .font(.formaBodySemibold)
            .foregroundColor(.formaSage)
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                FormaChromeSurface(
                    cornerRadius: FormaRadius.pill,
                    fill: colorScheme == .dark
                        ? Color.formaControlBackground.opacity(0.72)
                        : Color.formaBoneWhite.opacity(0.88),
                    tint: .formaSage,
                    elevation: .resting
                )
            )
            .accessibilityLabel("No files need review")
    }

    private var supportRowsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            activityStatsRow

            if viewModel.highConfidenceCount > 0 {
                MenuBarDivider()
                    .padding(.vertical, 4)
                highConfidenceRow
            }

            if viewModel.totalPendingFiles > 0 {
                MenuBarDivider()
                    .padding(.vertical, 4)
                monitoredFoldersSection
            }
        }
    }

    private var activityStatsRow: some View {
        HStack(spacing: 0) {
            compactStatColumn(
                title: "Today",
                value: "\(viewModel.organizedTodayCount)",
                icon: "checkmark.circle.fill",
                tint: .formaSage
            )

            verticalDivider

            compactStatColumn(
                title: "This Week",
                value: "\(viewModel.organizedThisWeekCount)",
                icon: "calendar",
                tint: .formaSteelBlue
            )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private func compactStatColumn(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: FormaSpacing.tight) {
            Image(systemName: icon)
                .font(.formaCaptionSemibold)
                .foregroundColor(tint)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.formaCaptionSemibold)
                    .foregroundColor(.formaSecondaryLabel)
                    .textCase(.uppercase)

                Text(value)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var highConfidenceRow: some View {
        Group {
            if viewModel.showOrganizeAllConfirmation {
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.formaSage)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Files organized")
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaLabel)

                        Text("High-confidence matches were moved.")
                            .font(.formaMenuMetadata)
                            .foregroundColor(.formaSecondaryLabel)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.formaSage.opacity(colorScheme == .dark ? 0.12 : 0.08))
                )
                .transition(.opacity)
            } else {
                Button(action: {
                    Task { await viewModel.organizeAllHighConfidence() }
                }) {
                    HStack(spacing: FormaSpacing.tight) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("High-confidence matches")
                                .font(.formaBodySemibold)
                                .foregroundColor(.formaLabel)

                            Text("\(viewModel.highConfidenceCount) file\(viewModel.highConfidenceCount == 1 ? "" : "s") can be organized immediately")
                                .font(.formaMenuMetadata)
                                .foregroundColor(.formaSecondaryLabel)
                        }

                        Spacer(minLength: 0)

                        Label("Organize", systemImage: "bolt.fill")
                            .font(.formaCompactSemibold)
                            .foregroundColor(.formaSteelBlue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Organize files with 90% or higher confidence")
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showOrganizeAllConfirmation)
    }

    private var monitoredFoldersSection: some View {
        let folders = viewModel.folderStatuses.filter(\.hasFiles)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                VStack(spacing: 0) {
                    HStack(spacing: FormaSpacing.tight) {
                        folderIcon(for: folder)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.name)
                                .font(.formaMenuItem)
                                .foregroundColor(.formaLabel)

                            Text(folder.count == 1 ? "1 file waiting" : "\(folder.count) files waiting")
                                .font(.formaMenuMetadata)
                                .foregroundColor(.formaSecondaryLabel)
                        }

                        Spacer(minLength: FormaSpacing.tight)

                        folderCountBadge(for: folder)
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 6)

                    if index < folders.count - 1 {
                        MenuBarDivider()
                    }
                }
            }
        }
    }

    private func folderIcon(for folder: MenuBarViewModel.FolderStatus) -> some View {
        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
            .fill(Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.06 : 0.42))
            .frame(width: 24, height: 24)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                    .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: 1)
            )
            .overlay(
                Image(systemName: folder.iconName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(folder.count > 0 ? .formaSteelBlue : .formaTertiaryLabel)
            )
    }

    private func folderCountBadge(for folder: MenuBarViewModel.FolderStatus) -> some View {
        Text("\(folder.count)")
            .font(.formaCaptionSemibold)
            .foregroundColor(folder.count > 0 ? .formaSteelBlue : .formaSecondaryLabel)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        (folder.count > 0 ? Color.formaSteelBlue : Color.formaSecondaryLabel)
                            .opacity(colorScheme == .dark ? 0.12 : 0.06)
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        (folder.count > 0 ? Color.formaSteelBlue : Color.formaSecondaryLabel)
                            .opacity(colorScheme == .dark ? 0.18 : 0.10),
                        lineWidth: 1
                    )
            )
    }

    private var footerSection: some View {
        VStack(spacing: FormaSpacing.tight) {
            MenuBarDivider()
                .padding(.top, 2)

            HStack(spacing: FormaSpacing.tight) {
                Button(action: openMainInterface) {
                    HStack(spacing: FormaSpacing.micro) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Open Forma")
                            .font(.formaBodySemibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(MenuBarButtonStyle(kind: .secondary(nil)))

                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(MenuBarButtonStyle(kind: .utility))
                .help("Settings")

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.formaCompactMedium)
                }
                .buttonStyle(MenuBarButtonStyle(kind: .utility))
            }
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.formaSeparator.opacity(colorScheme == .dark ? 0.22 : 0.10))
            .frame(width: 1)
            .padding(.vertical, 8)
    }

    private func openMainInterface() {
        WindowLifecycleManager.shared.mainWindowDidAppear()
        openWindow(id: "main")
    }
}

#Preview("Menu Bar - Pending Destination") {
    MenuBarView(
        viewModel: .previewPendingWithDestination(),
        autoRefreshOnAppear: false
    )
}

#Preview("Menu Bar - Pending Needs Destination") {
    MenuBarView(
        viewModel: .previewPendingWithoutDestination(),
        autoRefreshOnAppear: false
    )
}

#Preview("Menu Bar - All Clear") {
    MenuBarView(
        viewModel: .previewAllClear(),
        autoRefreshOnAppear: false
    )
}
