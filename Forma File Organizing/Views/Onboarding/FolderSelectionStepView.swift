import SwiftUI

// MARK: - Folder Selection Step View

/// Second step: Vertical pre-checked folder list for quick opt-out selection
struct FolderSelectionStepView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Binding var selection: OnboardingFolderSelection
    let isRequestingPermissions: Bool
    let onContinue: () -> Void
    let onBack: () -> Void

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

                    Text(isRequestingPermissions
                         ? "Please grant access when prompted"
                         : "We've selected the most common ones.\nUncheck any you'd rather manage yourself.")
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, FormaSpacing.generous)

                // Vertical folder list
                VStack(spacing: 8) {
                    FolderRowItem(folder: .desktop, isSelected: $selection.desktop, animationDelay: 0.2)
                    FolderRowItem(folder: .downloads, isSelected: $selection.downloads, animationDelay: 0.25)
                    FolderRowItem(folder: .documents, isSelected: $selection.documents, animationDelay: 0.3)
                    FolderRowItem(folder: .pictures, isSelected: $selection.pictures, animationDelay: 0.35)
                    FolderRowItem(folder: .music, isSelected: $selection.music, animationDelay: 0.4)
                }
                .padding(.horizontal, FormaSpacing.extraLarge)

                // Selection count + privacy note
                VStack(spacing: FormaSpacing.tight) {
                    if selection.hasAnySelected {
                        Text("\(selection.selectedCount) folder\(selection.selectedCount == 1 ? "" : "s") selected")
                            .font(.formaBodyMedium)
                            .foregroundColor(.formaSteelBlue)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
    }
}

// MARK: - Folder Row Item

/// A clean horizontal row: checkbox + colored folder mini-icon + name + description.
struct FolderRowItem: View {
    let folder: OnboardingFolder
    @Binding var isSelected: Bool
    let animationDelay: Double

    @State private var isHovered = false
    @State private var animateIn = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isSelected.toggle()
            }
        }) {
            HStack(spacing: 14) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? folder.color : Color.clear)
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isSelected ? folder.color : Color.formaSecondaryLabel.opacity(0.3), lineWidth: 1.5)
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Colored folder mini-icon
                FolderMiniIcon(color: folder.color)

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
                    .fill(isHovered ? folder.color.opacity(0.04) : Color.formaControlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? folder.color : Color.formaSeparator.opacity(0.5),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(animationDelay)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Folder Mini Icon

/// A small colored folder shape rendered with layered rounded rectangles.
struct FolderMiniIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            // Tab
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 6)
                .offset(x: -5, y: -11)

            // Body
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 32, height: 22)

            // Front
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color.opacity(0.75))
                .frame(width: 32, height: 18)
                .offset(y: 2)
        }
        .frame(width: 32, height: 28)
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
