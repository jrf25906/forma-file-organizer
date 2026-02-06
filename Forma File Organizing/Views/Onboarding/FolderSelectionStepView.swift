import SwiftUI

// MARK: - Folder Selection Step View

/// Second step: Vertical pre-checked folder list for quick opt-out selection
struct FolderSelectionStepView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Binding var selection: OnboardingFolderSelection
    let isRequestingPermissions: Bool
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var animateIn = false
    @State private var selectionBounce = false

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            VStack(spacing: FormaSpacing.standard) {
                // Header
                VStack(spacing: FormaSpacing.standard) {
                    // Show progress spinner when requesting permissions, otherwise show step title
                    if isRequestingPermissions {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(width: 48, height: 48)
                    }

                    Text(isRequestingPermissions ? "Requesting Access..." : "Choose your folders")
                        .font(.formaDisplayHeading)
                        .foregroundColor(.formaLabel)
                        .progressiveReveal(isVisible: animateIn, index: 0, baseDelay: 0.08, offsetY: 16)

                    Text(isRequestingPermissions
                         ? "Please grant access when prompted"
                         : "We've selected the most common ones.\nUncheck any you'd rather manage yourself.")
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabel)
                        .multilineTextAlignment(.center)
                        .progressiveReveal(isVisible: animateIn, index: 1, baseDelay: 0.08, offsetY: 16)
                }
                .padding(.top, FormaSpacing.generous)

                // Vertical folder list
                VStack(spacing: 8) {
                    FolderRowItem(folder: .desktop, isSelected: $selection.desktop, index: 0)
                    FolderRowItem(folder: .downloads, isSelected: $selection.downloads, index: 1)
                    FolderRowItem(folder: .documents, isSelected: $selection.documents, index: 2)
                    FolderRowItem(folder: .pictures, isSelected: $selection.pictures, index: 3)
                    FolderRowItem(folder: .music, isSelected: $selection.music, index: 4)
                }
                .padding(.horizontal, FormaSpacing.extraLarge)

                // Selection count + privacy note
                VStack(spacing: FormaSpacing.tight) {
                    if selection.hasAnySelected {
                        Text("\(selection.selectedCount) folder\(selection.selectedCount == 1 ? "" : "s") selected")
                            .font(.formaBodyMedium)
                            .foregroundColor(.formaSteelBlue)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .formaBounce(trigger: selectionBounce)
                    }

                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "lock.shield.fill")
                            .font(.formaCompact)
                            .foregroundColor(.formaSage)
                        Text("Your files never leave your Mac")
                            .font(.formaCompact)
                            .foregroundColor(.formaTertiaryLabel)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: selection.selectedCount)
                .padding(.top, FormaSpacing.tight)
            }
            .padding(.bottom, FormaSpacing.standard)

            // Footer (reuse existing OnboardingFooter)
            OnboardingFooter(
                primaryTitle: isRequestingPermissions ? "Granting Access..." : "Continue",
                primaryEnabled: selection.hasAnySelected && !isRequestingPermissions,
                primaryAction: onContinue,
                secondaryTitle: "Back",
                secondaryAction: isRequestingPermissions ? nil : onBack,
                hint: isRequestingPermissions ? nil : (selection.hasAnySelected ? nil : "Select at least one folder")
            )
            .disabled(isRequestingPermissions)
        }
        .onAppear {
            animateIn = true
        }
        .onChange(of: selection.selectedCount) { _, _ in
            selectionBounce.toggle()
        }
    }
}

// MARK: - Folder Row Item

/// A clean horizontal row: checkbox + colored folder icon + name + description.
struct FolderRowItem: View {
    let folder: OnboardingFolder
    @Binding var isSelected: Bool
    let index: Int

    @State private var isHovered = false
    @State private var animateIn = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isSelected.toggle()
            }
        }) {
            HStack(spacing: 14) {
                // Checkbox
                FormaCheckbox.compact(isSelected: isSelected, action: { isSelected.toggle() })

                // SF Symbol folder icon
                Image(systemName: "folder.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(folder.color)
                    .font(.system(size: 24))

                // Name and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.title)
                        .font(.formaBodySemibold)
                        .foregroundColor(.formaLabel)

                    Text(folder.folderDescription)
                        .font(.formaCompact)
                        .foregroundColor(.formaTertiaryLabel)
                }

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? folder.color.opacity(0.06) : (isHovered ? folder.color.opacity(0.04) : Color.formaControlBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? folder.color : Color.formaSeparator.opacity(0.5),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? folder.color.opacity(0.12) : Color.clear,
                    radius: isSelected ? 8 : 0,
                    x: 0,
                    y: isSelected ? 3 : 0)
            .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : (animateIn ? 0 : 3)),
            axis: (x: 1, y: 0, z: 0)
        )
        .progressiveReveal(isVisible: animateIn, index: index, baseDelay: 0.08, offsetY: 16)
        .onAppear {
            animateIn = true
        }
    }
}

// MARK: - Folder Descriptions

private extension OnboardingFolder {
    var folderDescription: String {
        switch self {
        case .desktop: return "Files on your desktop"
        case .downloads: return "Your downloaded files"
        case .documents: return "Your documents folder"
        case .pictures: return "Photos and images"
        case .music: return "Audio files and playlists"
        }
    }
}

// MARK: - Preview

#Preview("Folder Selection") {
    FolderSelectionStepView(
        selection: .constant(OnboardingFolderSelection()),
        isRequestingPermissions: false,
        onContinue: {},
        onBack: {}
    )
    .frame(width: 650, height: 720)
    .background(Color.formaBackground)
    .environmentObject(DashboardViewModel())
}
