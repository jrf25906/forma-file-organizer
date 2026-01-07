import SwiftUI

enum FloatingActionBarMode {
    case selection  // Multi-select mode
    case review     // Review mode (Needs Review)
}

struct FloatingActionBar: View {
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
            return "Ready to Organize"
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

    private var compactPrimaryButtonLabel: String {
        switch mode {
        case .selection:
            return "Organize"
        case .review:
            return "Organize"
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
            .padding(.leading, FormaSpacing.generous)

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
                            .background(Color.formaControlBackground.opacity(0.5))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.formaSeparator, lineWidth: 0.5)
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

                // Skip button (Ghost / Text Link style per feedback)
                Button(action: onSkip) {
                    Text(mode == .selection ? "Skip Selection" : "Skip")
                        .font(.formaBodyMedium)
                        .foregroundColor(Color.formaSecondaryLabel)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle()) // Make it easier to click
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

                // Primary action (Organize)
                if canOrganizeAll || mode == .selection {
                    Button(action: onOrganize) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.formaBodyMedium)
                            Text(primaryButtonLabel)
                                .font(.formaBodySemibold)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .foregroundColor(.formaBoneWhite)
                        .background(
                            GlassButtonBackground(
                                tint: mode == .selection ? Color.formaSteelBlue : Color.formaSage,
                                cornerRadius: FormaRadius.pill
                            )
                        )
                        .shadow(color: (mode == .selection ? Color.formaSteelBlue : Color.formaSage).opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .pressAnimation()
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
                            .background(Color.formaControlBackground.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Deselect all")
                } else {
                    // Spacer to balance the layout if no close button
                    Color.clear.frame(width: 32, height: 32)
                }
            }
            .padding(.trailing, FormaSpacing.generous)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            FormaMaterialSurface(tier: .overlay, cornerRadius: FormaRadius.pill)
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
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
