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

    init(viewModel: MenuBarViewModel = MenuBarViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Header
            headerSection

            Divider()
                .padding(.horizontal, FormaSpacing.standard)

            // 2. Status Summary
            statusSummarySection

            // 3. File Review Card
            if FeatureFlagService.shared.isEnabled(.menuBarFileReview) {
                if viewModel.hasPendingFiles {
                    fileReviewSection
                } else {
                    allClearSection
                }

                Divider()
                    .padding(.horizontal, FormaSpacing.standard)
            }

            // 4. Quick Actions
            if viewModel.highConfidenceCount > 0 {
                quickActionsSection
                Divider()
                    .padding(.horizontal, FormaSpacing.standard)
            }

            // 5. Monitored Folders
            if viewModel.hasPendingFiles {
                folderCountsSection
                Divider()
                    .padding(.horizontal, FormaSpacing.standard)
            }

            // 6. Footer
            footerSection
        }
        .frame(width: 340)
        .background(Color.formaBackground)
        .onAppear {
            viewModel.startRefreshing()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }

    // MARK: - 1. Header Section

    private var headerSection: some View {
        HStack(spacing: FormaSpacing.tight) {
            Text("Forma")
                .font(.formaMenuTitle)
                .foregroundColor(.formaLabel)

            Spacer()

            // Automation status dot with label
            automationStatusDot
        }
        .padding(FormaSpacing.standard)
    }

    @ViewBuilder
    private var automationStatusDot: some View {
        let status = viewModel.automationStatus
        HStack(spacing: FormaSpacing.micro) {
            Circle()
                .fill(automationDotColor)
                .frame(width: 8, height: 8)

            Text(automationDotLabel)
                .font(.formaMenuMetadata)
                .foregroundColor(.formaSecondaryLabel)
        }
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
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            // Pending count banner
            if viewModel.hasPendingFiles {
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: "tray.full.fill")
                        .font(.formaMenuItem)
                        .foregroundColor(.formaWarning)

                    Text(viewModel.pendingSummary)
                        .font(.formaMenuItem)
                        .fontWeight(.medium)
                        .foregroundColor(.formaLabel)
                }
                .padding(.vertical, FormaSpacing.tight)
                .padding(.horizontal, FormaSpacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.formaWarning.opacity(0.08))
                .formaCornerRadius(FormaRadius.control)
            }

            // Organized stats
            HStack(spacing: FormaSpacing.standard) {
                Label("\(viewModel.organizedTodayCount) today", systemImage: "checkmark.circle")
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaTertiaryLabel)

                Label("\(viewModel.organizedThisWeekCount) this week", systemImage: "calendar")
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaTertiaryLabel)
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
                        .foregroundColor(.formaSage)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.tight)
                .background(Color.formaSage.opacity(0.1))
                .formaCornerRadius(FormaRadius.control)
                .transition(.opacity)
            } else {
                Button(action: {
                    Task { await viewModel.organizeAllHighConfidence() }
                }) {
                    HStack(spacing: FormaSpacing.micro) {
                        Image(systemName: "bolt.fill")
                            .font(.formaMenuMetadata)
                        Text("Organize All (\(viewModel.highConfidenceCount) high confidence)")
                            .font(.formaMenuMetadata)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.formaSteelBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.tight)
                    .background(Color.formaSteelBlue.opacity(0.08))
                    .formaCornerRadius(FormaRadius.control)
                }
                .buttonStyle(.plain)
                .help("Organize files with 90%+ confidence")
            }
        }
        .padding(.horizontal, FormaSpacing.standard)
        .padding(.vertical, FormaSpacing.tight)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showOrganizeAllConfirmation)
    }

    // MARK: - 5. Monitored Folders Section

    private var folderCountsSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text("Monitored Folders")
                .font(.formaMenuMetadata)
                .fontWeight(.medium)
                .foregroundColor(.formaTertiaryLabel)
                .textCase(.uppercase)
                .padding(.bottom, FormaSpacing.micro)

            ForEach(viewModel.folderStatuses) { folder in
                HStack(spacing: FormaSpacing.tight) {
                    // Accent dot for folders with pending files
                    Circle()
                        .fill(folder.count > 0 ? Color.formaWarning : Color.clear)
                        .frame(width: 6, height: 6)

                    Image(systemName: folder.iconName)
                        .font(.formaMenuMetadata)
                        .foregroundColor(.formaTertiaryLabel)
                        .frame(width: 16)

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

    // MARK: - 6. Footer Section

    private var footerSection: some View {
        HStack(spacing: FormaSpacing.tight) {
            // Open Forma link
            Button(action: openMainInterface) {
                HStack(spacing: FormaSpacing.micro) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.formaMenuMetadata)
                    Text("Open Forma")
                        .font(.formaMenuMetadata)
                        .fontWeight(.medium)
                }
                .foregroundColor(.formaSteelBlue)
            }
            .buttonStyle(.plain)

            Spacer()

            // Settings gear
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.formaMenuItem)
                    .foregroundColor(.formaSecondaryLabel)
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
        .padding(FormaSpacing.standard)
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
