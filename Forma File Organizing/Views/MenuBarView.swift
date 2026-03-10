import SwiftUI

/// Compact menu bar interface for quick review, automation status, and shortcuts.
struct MenuBarView: View {
    @StateObject private var viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: MenuBarViewModel = MenuBarViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                padding: FormaSpacing.standard
            ) {
                VStack(spacing: FormaSpacing.tight) {
                    headerSection
                    summarySection

                    if FeatureFlagService.shared.isEnabled(.menuBarFileReview), viewModel.hasPendingFiles {
                        reviewQueueSection
                    }

                    if viewModel.highConfidenceCount > 0 {
                        quickActionsSection
                    }

                    if viewModel.hasPendingFiles {
                        folderCountsSection
                    }

                    footerSection
                }
            }
        }
        .padding(6)
        .frame(width: 344)
        .background(Color.clear)
        .onAppear {
            viewModel.startRefreshing()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }

    private var shellTint: Color {
        if viewModel.hasPendingFiles {
            return Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.28 : 0.18)
        }
        return Color.formaSage.opacity(colorScheme == .dark ? 0.24 : 0.14)
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
                .frame(width: 34, height: 34)
                .overlay(
                    FormaLogo(style: .mark, height: 18)
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

    private var summarySection: some View {
        MenuBarSurface(
            tint: viewModel.hasPendingFiles
                ? Color.formaWarning.opacity(colorScheme == .dark ? 0.20 : 0.12)
                : Color.formaSage.opacity(colorScheme == .dark ? 0.16 : 0.10)
        ) {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                HStack(spacing: FormaSpacing.standard) {
                    summaryIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.hasPendingFiles ? "Pending review" : "All clear")
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaLabel)

                        Text(viewModel.hasPendingFiles ? reviewSummaryText : clearSummaryText)
                            .font(.formaMenuMetadata)
                            .foregroundColor(.formaSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: FormaSpacing.tight)

                    summaryCountBadge
                }

                HStack(spacing: FormaSpacing.tight) {
                    statTile(
                        title: "Today",
                        value: "\(viewModel.organizedTodayCount)",
                        icon: "checkmark.circle.fill",
                        tint: .formaSage
                    )

                    statTile(
                        title: "This Week",
                        value: "\(viewModel.organizedThisWeekCount)",
                        icon: "calendar",
                        tint: .formaSteelBlue
                    )
                }
            }
            .padding(FormaSpacing.standard)
        }
    }

    private var reviewSummaryText: String {
        if viewModel.highConfidenceCount > 0 {
            return "\(viewModel.highConfidenceCount) high-confidence match\(viewModel.highConfidenceCount == 1 ? "" : "es") ready to move."
        }

        return "Review files before Forma moves them."
    }

    private var clearSummaryText: String {
        if viewModel.automationStatus.mode == .off {
            return "Nothing needs attention right now."
        }

        return "Nothing needs attention. Forma is still watching your folders."
    }

    private var summaryIcon: some View {
        FormaChromeSurface(
            cornerRadius: FormaRadius.control,
            fill: colorScheme == .dark
                ? Color.formaControlBackground.opacity(0.80)
                : Color.formaBoneWhite.opacity(0.92),
            tint: summaryIconTint,
            elevation: .raised
        )
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: viewModel.hasPendingFiles ? "tray.full.fill" : "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(summaryIconTint)
            )
    }

    private var summaryIconTint: Color {
        viewModel.hasPendingFiles ? .formaWarning : .formaSage
    }

    private var summaryCountBadge: some View {
        Text(viewModel.hasPendingFiles ? "\(viewModel.pendingFiles.count)" : "0")
            .font(.formaBodySemibold)
            .foregroundColor(summaryIconTint)
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                FormaChromeSurface(
                    cornerRadius: FormaRadius.pill,
                    fill: colorScheme == .dark
                        ? Color.formaControlBackground.opacity(0.76)
                        : Color.formaBoneWhite.opacity(0.92),
                    tint: summaryIconTint,
                    elevation: .resting
                )
            )
            .accessibilityLabel(viewModel.hasPendingFiles ? "\(viewModel.pendingFiles.count) files need review" : "No files need review")
    }

    private func statTile(title: String, value: String, icon: String, tint: Color) -> some View {
        MenuBarSurface(
            tier: .base,
            tint: tint.opacity(colorScheme == .dark ? 0.22 : 0.14),
            cornerRadius: FormaRadius.control,
            padding: FormaSpacing.tight
        ) {
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Label(title, systemImage: icon)
                    .font(.formaCaptionSemibold)
                    .foregroundColor(.formaSecondaryLabel)

                Text(value)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reviewQueueSection: some View {
        MenuBarSurface(
            tint: Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.18 : 0.10)
        ) {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                MenuBarSectionHeading(title: "Review Queue")
                    .padding(.horizontal, FormaSpacing.standard)
                    .padding(.top, FormaSpacing.standard)

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
                    .padding(.horizontal, FormaSpacing.standard)
                    .padding(.bottom, FormaSpacing.standard)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.currentReviewFile?.path)
    }

    private var quickActionsSection: some View {
        MenuBarSurface(
            tint: Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.20 : 0.12)
        ) {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                MenuBarSectionHeading(title: "Quick Actions")

                if viewModel.showOrganizeAllConfirmation {
                    MenuBarSurface(
                        tier: .base,
                        tint: Color.formaSage.opacity(colorScheme == .dark ? 0.22 : 0.14),
                        cornerRadius: FormaRadius.control,
                        padding: FormaSpacing.tight
                    ) {
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
                    }
                    .transition(.opacity)
                } else {
                    Button(action: {
                        Task { await viewModel.organizeAllHighConfidence() }
                    }) {
                        HStack(spacing: FormaSpacing.tight) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Organize High-Confidence Files")
                                    .font(.formaBodySemibold)

                                Text("\(viewModel.highConfidenceCount) file\(viewModel.highConfidenceCount == 1 ? "" : "s") with 90%+ confidence")
                                    .font(.formaMenuMetadata)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(MenuBarButtonStyle(kind: .secondary(.formaSteelBlue)))
                    .help("Organize files with 90% or higher confidence")
                }
            }
            .padding(FormaSpacing.standard)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showOrganizeAllConfirmation)
    }

    private var folderCountsSection: some View {
        MenuBarSurface(
            tint: Color.formaMutedBlue.opacity(colorScheme == .dark ? 0.18 : 0.10)
        ) {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                MenuBarSectionHeading(title: "Monitored Folders", detail: "\(viewModel.totalPendingFiles) pending")

                ForEach(viewModel.folderStatuses) { folder in
                    HStack(spacing: FormaSpacing.tight) {
                        folderIcon(for: folder)

                        Text(folder.name)
                            .font(.formaMenuItem)
                            .foregroundColor(.formaLabel)

                        Spacer(minLength: FormaSpacing.tight)

                        folderCountBadge(for: folder)
                    }
                }
            }
            .padding(FormaSpacing.standard)
        }
    }

    private func folderIcon(for folder: MenuBarViewModel.FolderStatus) -> some View {
        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
            .fill(Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.08 : 0.60))
            .frame(width: 28, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                    .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.30 : 0.20), lineWidth: 1)
            )
            .overlay(
                Image(systemName: folder.iconName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(folder.count > 0 ? .formaSteelBlue : .formaTertiaryLabel)
            )
    }

    private func folderCountBadge(for folder: MenuBarViewModel.FolderStatus) -> some View {
        Text("\(folder.count)")
            .font(.formaCaptionSemibold)
            .foregroundColor(folder.count > 0 ? .formaSteelBlue : .formaSecondaryLabel)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        (folder.count > 0 ? Color.formaSteelBlue : Color.formaSecondaryLabel)
                            .opacity(colorScheme == .dark ? 0.18 : 0.10)
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        (folder.count > 0 ? Color.formaSteelBlue : Color.formaSecondaryLabel)
                            .opacity(colorScheme == .dark ? 0.24 : 0.14),
                        lineWidth: 1
                    )
            )
    }

    private var footerSection: some View {
        MenuBarSurface(
            tint: Color.formaMutedBlue.opacity(colorScheme == .dark ? 0.14 : 0.08)
        ) {
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
                .buttonStyle(MenuBarButtonStyle(kind: .secondary(.formaSteelBlue)))

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
            .padding(FormaSpacing.standard)
        }
    }

    private func openMainInterface() {
        WindowLifecycleManager.shared.mainWindowDidAppear()
        openWindow(id: "main")
    }
}

#Preview {
    MenuBarView(viewModel: MenuBarViewModel())
}
