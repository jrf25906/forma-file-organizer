import SwiftUI

/// Enhanced menu bar interface with file review, live counts, and automation status.
///
/// ## Layout (6 sections per design spec)
/// 1. Header — "Forma" + automation status dot
/// 2. Status Summary — pending count banner + organized stats
/// 3. File Review Card — single-file review with organize/skip
/// 4. Quick Actions — "Organize All" for high-confidence files
/// 5. Monitored Folders — folder counts
/// 6. Footer — "Open Forma" + Settings gear
struct MenuBarView: View {
    @StateObject private var viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: MenuBarViewModel = MenuBarViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Adaptive Colors

    private var sectionBackground: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.05) : .formaBoneWhite
    }

    private var sectionBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.12)
            : Color.formaSeparator.opacity(0.4)
    }

    var body: some View {
        VStack(spacing: FormaSpacing.tight) {
            // 1. Header
            headerSection

            // 2. Status Summary + File Review (grouped)
            menuBarSection {
                statusSummarySection

                if FeatureFlagService.shared.isEnabled(.menuBarFileReview) {
                    Divider()
                        .padding(.horizontal, FormaSpacing.tight)

                    if viewModel.hasPendingFiles {
                        fileReviewSection
                    } else {
                        allClearSection
                    }
                }
            }

            // 3. Quick Actions
            if viewModel.highConfidenceCount > 0 {
                menuBarSection {
                    quickActionsSection
                }
            }

            // 4. Monitored Folders
            if viewModel.hasPendingFiles {
                menuBarSection {
                    folderCountsSection
                }
            }

            // 5. Footer
            footerSection
        }
        .padding(FormaSpacing.tight)
        .frame(width: 340)
        .background(Color.formaBackground)
        .onAppear {
            viewModel.startRefreshing()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }

    // MARK: - Section Container

    /// Wraps content in a grouped card surface matching the main app's card pattern.
    @ViewBuilder
    private func menuBarSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(sectionBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(sectionBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
    }

    // MARK: - 1. Header Section

    private var headerSection: some View {
        HStack(spacing: FormaSpacing.tight) {
            Text("Forma")
                .font(.formaH3)
                .foregroundColor(.formaLabel)

            Spacer()

            // Automation status pill
            automationStatusPill
        }
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
    }

    @ViewBuilder
    private var automationStatusPill: some View {
        let status = viewModel.automationStatus
        HStack(spacing: FormaSpacing.micro) {
            Circle()
                .fill(automationDotColor)
                .frame(width: 7, height: 7)

            Text(automationDotLabel)
                .font(.formaMenuMetadata)
                .foregroundColor(.formaSecondaryLabel)
        }
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(
            Capsule(style: .continuous)
                .fill(automationDotColor.opacity(0.1))
        )
        .help(status.statusText)
    }

    private var automationDotColor: Color {
        switch viewModel.automationStatus.mode {
        case .scanAndOrganize:
            return .formaSage
        case .scanOnly:
            return .formaWarning
        case .off:
            return .formaTertiaryLabel
        }
    }

    private var automationDotLabel: String {
        switch viewModel.automationStatus.mode {
        case .scanAndOrganize:
            return "Watching"
        case .scanOnly:
            return "Scan only"
        case .off:
            return "Off"
        }
    }

    // MARK: - 2. Status Summary Section

    private var statusSummarySection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            // Pending count banner
            if viewModel.hasPendingFiles {
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.formaWarning)

                    Text(viewModel.pendingSummary)
                        .font(.formaMenuItem)
                        .fontWeight(.semibold)
                        .foregroundColor(.formaLabel)
                }
                .padding(.vertical, FormaSpacing.tight)
                .padding(.horizontal, FormaSpacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.formaWarning.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .strokeBorder(Color.formaWarning.opacity(0.2), lineWidth: 1)
                )
                .formaCornerRadius(FormaRadius.control)
            }

            // Organized stats
            HStack(spacing: FormaSpacing.standard) {
                Label("\(viewModel.organizedTodayCount) today", systemImage: "checkmark.circle")
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaSecondaryLabel)

                Label("\(viewModel.organizedThisWeekCount) this week", systemImage: "calendar")
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaSecondaryLabel)
            }
        }
        .padding(FormaSpacing.standard)
    }

    // MARK: - 3. File Review Card Section

    private var fileReviewSection: some View {
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
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.currentReviewFile?.path)
        .padding(.horizontal, FormaSpacing.standard)
        .padding(.bottom, FormaSpacing.tight)
    }

    private var allClearSection: some View {
        HStack(spacing: FormaSpacing.tight) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.formaSage)

            VStack(alignment: .leading, spacing: 2) {
                Text("All clear")
                    .font(.formaMenuItem)
                    .fontWeight(.medium)
                    .foregroundColor(.formaLabel)

                Text("No files need attention")
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaTertiaryLabel)
            }

            Spacer()
        }
        .padding(FormaSpacing.standard)
    }

    // MARK: - 4. Quick Actions Section

    private var quickActionsSection: some View {
        VStack(spacing: FormaSpacing.tight) {
            if viewModel.showOrganizeAllConfirmation {
                // Confirmation toast
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.formaSage)
                    Text("Files organized!")
                        .font(.formaMenuItem)
                        .fontWeight(.medium)
                        .foregroundColor(.formaSage)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.tight)
                .background(Color.formaSage.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .strokeBorder(Color.formaSage.opacity(0.2), lineWidth: 1)
                )
                .formaCornerRadius(FormaRadius.control)
                .transition(.opacity)
            } else {
                Button(action: {
                    Task { await viewModel.organizeAllHighConfidence() }
                }) {
                    HStack(spacing: FormaSpacing.micro) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Organize All (\(viewModel.highConfidenceCount) high confidence)")
                            .font(.formaMenuItem)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.formaSteelBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.formaSteelBlue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                            .strokeBorder(Color.formaSteelBlue.opacity(0.2), lineWidth: 1)
                    )
                    .formaCornerRadius(FormaRadius.control)
                }
                .buttonStyle(.plain)
                .help("Organize files with 90%+ confidence")
            }
        }
        .padding(FormaSpacing.standard)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showOrganizeAllConfirmation)
    }

    // MARK: - 5. Monitored Folders Section

    private var folderIconBackground: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.08) : .formaControlBackground
    }

    private var folderIconBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaSeparator.opacity(0.4)
    }

    private var folderCountsSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text("Monitored Folders")
                .font(.formaCaption)
                .fontWeight(.semibold)
                .foregroundColor(.formaTertiaryLabel)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, FormaSpacing.micro)

            ForEach(viewModel.folderStatuses) { folder in
                HStack(spacing: FormaSpacing.tight) {
                    // Icon circle matching main app sidebar pattern
                    ZStack {
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .fill(folderIconBackground)
                            .frame(width: 26, height: 26)

                        Image(systemName: folder.iconName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(folder.count > 0 ? .formaSteelBlue : .formaTertiaryLabel)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .strokeBorder(folderIconBorder, lineWidth: 1)
                    )

                    Text(folder.name)
                        .font(.formaMenuItem)
                        .foregroundColor(.formaLabel)

                    Spacer()

                    // Count badge
                    if folder.count > 0 {
                        Text("\(folder.count)")
                            .font(.formaMenuMetadata)
                            .fontWeight(.semibold)
                            .foregroundColor(.formaWarning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.formaWarning.opacity(0.1))
                            .clipShape(Capsule(style: .continuous))
                    } else {
                        Text("\(folder.count)")
                            .font(.formaMenuMetadata)
                            .foregroundColor(.formaTertiaryLabel)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(FormaSpacing.standard)
    }

    // MARK: - 6. Footer Section

    private var footerButtonBackground: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.06)
            : Color.formaSteelBlue.opacity(0.06)
    }

    private var footerSection: some View {
        HStack(spacing: FormaSpacing.tight) {
            // Open Forma button (primary footer action)
            Button(action: openMainInterface) {
                HStack(spacing: FormaSpacing.micro) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Open Forma")
                        .font(.formaMenuItem)
                        .fontWeight(.medium)
                }
                .foregroundColor(.formaSteelBlue)
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.vertical, 6)
                .background(footerButtonBackground)
                .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()

            // Settings gear
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.formaSecondaryLabel)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(sectionBackground)
                    )
                    .overlay(
                        Circle().strokeBorder(sectionBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaSecondaryLabel)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
    }

    // MARK: - Helpers

    private func openSettings() {
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
        WindowLifecycleManager.shared.mainWindowDidAppear()
        openWindow(id: "main")
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(viewModel: MenuBarViewModel())
}
