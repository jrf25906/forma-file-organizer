import SwiftUI

enum FloatingActionBarMode {
    case selection  // Multi-select mode
    case review     // Review mode (Needs Review)
}

struct FloatingActionBar: View {
    /// Visual bar height used to reserve scroll-content space in parent views.
    static let chromeHeight: CGFloat = 44

    /// Bottom offset from window edge used by the overlay placement.
    static let bottomOffset: CGFloat = FormaSpacing.large + FormaSpacing.tight

    let mode: FloatingActionBarMode
    let count: Int
    let canOrganizeAll: Bool
    let reviewState: ReviewActionBarState
    let onOrganize: () -> Void
    let onSkip: () -> Void
    let onBulkEdit: (() -> Void)?
    let onDeselect: (() -> Void)?
    
    // Convenience init for backwards compatibility
    init(
        selectedCount: Int,
        canOrganizeAll: Bool,
        onOrganizeAll: @escaping () -> Void,
        onSkipAll: @escaping () -> Void,
        onBulkEdit: @escaping () -> Void,
        onDeselect: @escaping () -> Void
    ) {
        self.mode = .selection
        self.count = selectedCount
        self.canOrganizeAll = canOrganizeAll
        self.reviewState = .clear
        self.onOrganize = onOrganizeAll
        self.onSkip = onSkipAll
        self.onBulkEdit = onBulkEdit
        self.onDeselect = onDeselect
    }
    
    // New init with mode parameter
    init(
        mode: FloatingActionBarMode,
        count: Int,
        canOrganizeAll: Bool,
        reviewState: ReviewActionBarState = .clear,
        onOrganize: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onBulkEdit: (() -> Void)? = nil,
        onDeselect: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.count = count
        self.canOrganizeAll = canOrganizeAll
        self.reviewState = reviewState
        self.onOrganize = onOrganize
        self.onSkip = onSkip
        self.onBulkEdit = onBulkEdit
        self.onDeselect = onDeselect
    }
    
    private var statusText: String {
        switch mode {
        case .selection:
            return "file\(count == 1 ? "" : "s") selected"
        case .review:
            return reviewStatusText
        }
    }

    private var reviewStatusText: String {
        switch reviewState {
        case .ready(let readyCount):
            return readyCount == 1 ? "1 file ready to organize" : "\(readyCount) files ready to organize"
        case .needsDestination(let destinationCount):
            return destinationCount == 1
                ? "1 file needs a destination first"
                : "\(destinationCount) files need destinations first"
        case .needsReview(let reviewCount):
            return reviewCount == 1
                ? "1 file still needs review"
                : "\(reviewCount) files still need review"
        case .clear:
            return "This pass is clear"
        }
    }

    private var reviewStatusIconName: String {
        switch reviewState {
        case .ready:
            return "tray.full.fill"
        case .needsDestination:
            return "folder.badge.questionmark"
        case .needsReview:
            return "doc.text.magnifyingglass"
        case .clear:
            return "checkmark.circle.fill"
        }
    }

    private var reviewStatusTone: RightRailSemanticTone {
        switch reviewState {
        case .ready:
            return .live
        case .needsDestination:
            return .blocked
        case .needsReview:
            return .progress
        case .clear:
            return .neutral
        }
    }
    
    private var primaryButtonLabel: String {
        switch mode {
        case .selection:
            return "Organize Selected"
        case .review:
            return "Organize Ready"
        }
    }

    private var showsPrimaryButton: Bool {
        switch mode {
        case .selection:
            return true
        case .review:
            guard canOrganizeAll else { return false }
            if case .ready = reviewState {
                return true
            }
            return false
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Folder icon + status
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: mode == .selection ? "checkmark.circle.fill" : reviewStatusIconName)
                    .font(.formaBodyLarge)
                    .foregroundColor(mode == .selection ? Color.formaSteelBlue : reviewStatusTone.color)

                Text(statusText)
                    .font(.formaBodyMedium)
                    .foregroundColor(Color.formaSecondaryLabel)
            }
            .padding(.leading, FormaSpacing.standard)
            .overlay(alignment: .topLeading) {
                if mode == .review {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("floatingActionBar_reviewStatus")
                        .accessibilityLabel(statusText)
                        .accessibilityValue(statusText)
                }
            }

            Spacer()

            // Center: Action buttons
            HStack(spacing: 12) {
                // SELECTION MODE SPECIFIC ACTIONS
                if mode == .selection {
                    // Bulk Edit (Move)
                    if let onBulkEdit = onBulkEdit {
                        Button(action: onBulkEdit) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.gear")
                                    .font(.formaCompact)
                                Text("Move")
                                    .font(.formaBodyMedium)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .foregroundColor(.formaLabel)
                            .background(Color.formaControlBackground.opacity(Color.FormaOpacity.strong))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Delete (Placeholder action for now, or use onSkip if it maps to delete/skip)
                    // The user requested "Delete", but we don't have a direct delete action passed in yet.
                    // We'll use a visual placeholder that calls onSkip for now (as "Skip" often implies removing from view)
                    // OR better, we omit it if we can't implement it safely yet, but the user asked for "Move" and "Delete".
                    // Let's implement "Skip" as the secondary action as requested, and "Move" (Bulk Edit) as a primary util.
                }

                // Skip button (Ghost outline style)
                FormaSecondaryButton(
                    title: mode == .selection ? "Skip Selection" : "Set Aside",
                    action: onSkip,
                    cornerRadius: FormaRadius.pill
                )
                .frame(width: mode == .selection ? 140 : 132, height: 32)
                .help(mode == .selection ? "Skip the selected files." : "Defer this review pass and bring it back later.")
                .accessibilityHint(mode == .selection ? "Skip the selected files." : "Defers the current review pass so you can resume it later.")

                // Primary action (Organize)
                if showsPrimaryButton {
                    FormaPrimaryButton(
                        title: primaryButtonLabel,
                        icon: "arrow.down.doc.fill",
                        action: onOrganize,
                        tint: .formaSteelBlue,
                        cornerRadius: FormaRadius.pill
                    )
                    .frame(width: mode == .selection ? 168 : 148, height: 36)
                }
            }

            Spacer()

            // Right: Close button (Selection Mode)
            HStack(spacing: FormaSpacing.tight) {
                if let deselect = onDeselect, mode == .selection {
                    Button(action: deselect) {
                        Image(systemName: "xmark")
                            .font(.formaBodyBold)
                            .foregroundColor(Color.formaSecondaryLabel)
                            .padding(8)
                            .background(Color.formaControlBackground.opacity(Color.FormaOpacity.strong))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Deselect all")
                } else {
                    // Spacer to balance the layout if no close button
                    Color.clear.frame(width: 32, height: 32)
                }
            }
            .padding(.trailing, FormaSpacing.standard)
        }
        .padding(.vertical, 6)
        .frame(minHeight: Self.chromeHeight)
        .frame(maxWidth: .infinity)
        .background {
            FormaMaterialSurface(tier: .overlay, cornerRadius: FormaRadius.pill)
                .formaShadow(FormaShadow.floating)
        }
        .padding(.horizontal, FormaSpacing.large)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}




#Preview {
    VStack {
        FloatingActionBar(
            selectedCount: 3,
            canOrganizeAll: true,
            onOrganizeAll: {},
            onSkipAll: {},
            onBulkEdit: {},
            onDeselect: {}
        )
        Spacer()
    }
}
