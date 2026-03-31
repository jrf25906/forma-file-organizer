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
        onOrganize: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onBulkEdit: (() -> Void)? = nil,
        onDeselect: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.count = count
        self.canOrganizeAll = canOrganizeAll
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
            return count > 0 ? "\(count) ready right now" : "Review current pass"
        }
    }
    
    private var primaryButtonLabel: String {
        switch mode {
        case .selection:
            return "Organize \(count)" // Shortened for cleaner look
        case .review:
            return "Organize \(count)" // Match the current view count
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Folder icon + status
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: mode == .selection ? "checkmark.circle.fill" : "tray.full.fill")
                    .font(.formaBodyLarge)
                    .foregroundColor(mode == .selection ? Color.formaSteelBlue : Color.formaWarmOrange)

                Text(statusText)
                    .font(.formaBodyMedium)
                    .foregroundColor(Color.formaSecondaryLabel)
            }
            .padding(.leading, FormaSpacing.standard)

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
                    title: mode == .selection ? "Skip Selection" : "Done for now",
                    action: onSkip,
                    cornerRadius: FormaRadius.pill
                )
                .frame(width: mode == .selection ? 140 : 132, height: 32)

                // Primary action (Organize)
                if canOrganizeAll || mode == .selection {
                    FormaPrimaryButton(
                        title: primaryButtonLabel,
                        icon: "arrow.down.doc.fill",
                        action: onOrganize,
                        tint: mode == .selection ? Color.formaSteelBlue : Color.formaSage,
                        cornerRadius: FormaRadius.pill
                    )
                    .frame(width: 140, height: 36)
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
                .formaShadow(.floating)
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
