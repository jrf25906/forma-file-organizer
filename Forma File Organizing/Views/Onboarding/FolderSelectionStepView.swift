import SwiftUI

// MARK: - Folder Selection Step View

/// Second step: Visual folder selection with animated cards
struct FolderSelectionStepView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Binding var selection: OnboardingFolderSelection
    let isRequestingPermissions: Bool
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FormaSpacing.standard) {
                // Header with geometric illustration
                VStack(spacing: FormaSpacing.standard) {
                    if isRequestingPermissions {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(width: 48, height: 48)
                    } else {
                        // Geometric folder illustration (echoes logo)
                        OnboardingGeometricIcon(style: .folders)
                            .frame(width: 64, height: 64)
                    }

                    Text(isRequestingPermissions ? "Requesting Access..." : "Pick your spaces")
                        .font(.formaH1)
                        .foregroundColor(.formaLabel)

                    Text(isRequestingPermissions
                         ? "Please grant access when prompted"
                         : "Tap the folders you'd like Forma to organize")
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, FormaSpacing.tight)

                // Visual folder grid - 3 columns, 2 rows
                VStack(spacing: FormaSpacing.standard) {
                    // Row 1: Desktop, Downloads, Documents
                    HStack(spacing: FormaSpacing.standard) {
                        AnimatedFolderCard(
                            folder: .desktop,
                            isSelected: $selection.desktop
                        )
                        AnimatedFolderCard(
                            folder: .downloads,
                            isSelected: $selection.downloads
                        )
                        AnimatedFolderCard(
                            folder: .documents,
                            isSelected: $selection.documents
                        )
                    }

                    // Row 2: Pictures, Music (centered)
                    HStack(spacing: FormaSpacing.standard) {
                        Spacer()
                        AnimatedFolderCard(
                            folder: .pictures,
                            isSelected: $selection.pictures
                        )
                        AnimatedFolderCard(
                            folder: .music,
                            isSelected: $selection.music
                        )
                        Spacer()
                    }
                }
                .padding(.horizontal, FormaSpacing.large)

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

                        Text("Your files stay on your Mac")
                            .font(.formaCompact)
                            .foregroundColor(.formaTertiaryLabel)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: selection.selectedCount)
                .padding(.top, FormaSpacing.tight)
            }
            .padding(.top, FormaSpacing.tight)
            .padding(.bottom, FormaSpacing.standard)

            // Footer
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

// MARK: - Animated Folder Card

struct AnimatedFolderCard: View {
    let folder: OnboardingFolder
    @Binding var isSelected: Bool

    @State private var isHovered = false
    @State private var iconOffsets: [CGFloat] = [0, 0, 0]

    private let cardSize: CGFloat = 140

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isSelected.toggle()
            }
        }) {
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .stroke(isSelected ? folder.color : Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: isSelected ? 2.5 : 1)
                    )

                // Content
                VStack(spacing: FormaSpacing.tight) {
                    // Rising icons container
                    ZStack {
                        // Folder base shape (simplified geometric)
                        FolderBaseShape(color: folder.color, isSelected: isSelected, isHovered: isHovered)

                        // Rising content icons
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: folder.contentIcons[index])
                                    .font(.formaBodyLarge)
                                    .fontWeight(.medium)
                                    .foregroundColor(folder.color.opacity(isHovered || isSelected ? Color.FormaOpacity.prominent : 0))
                                    .offset(y: iconOffsets[index])
                                    .scaleEffect(isHovered || isSelected ? 1.0 : 0.6)
                            }
                        }
                        .offset(y: -8)
                    }
                    .frame(height: 56)

                    // Folder name
                    Text(folder.title)
                        .font(.formaBodySemibold)
                        .foregroundColor(isSelected ? folder.color : .formaLabel)

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? folder.color : Color.formaSeparator, lineWidth: 1.5)
                            .frame(width: 20, height: 20)

                        if isSelected {
                            Circle()
                                .fill(folder.color)
                                .frame(width: 20, height: 20)

                            Image(systemName: "checkmark")
                                .font(.formaSmallSemibold)
                                .foregroundColor(.formaBoneWhite)
                        }
                    }
                }
                .padding(FormaSpacing.standard)
            }
            .frame(width: cardSize, height: cardSize)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .shadow(color: shadowColor, radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 3)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isHovered = hovering
            }
            animateIcons(rising: hovering)
        }
    }

    private var cardBackgroundColor: Color {
        if isSelected {
            return folder.color.opacity(Color.FormaOpacity.light)
        } else if isHovered {
            return Color.formaControlBackground
        } else {
            return Color.formaControlBackground.opacity(Color.FormaOpacity.high)
        }
    }

    private var shadowColor: Color {
        if isSelected {
            return folder.color.opacity(Color.FormaOpacity.medium)
        } else {
            return Color.formaObsidian.opacity(Color.FormaOpacity.light)
        }
    }

    private func animateIcons(rising: Bool) {
        for i in 0..<3 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(Double(i) * 0.05)) {
                iconOffsets[i] = rising ? -16 - CGFloat(i) * 2 : 0
            }
        }
    }
}

// MARK: - Folder Base Shape

struct FolderBaseShape: View {
    let color: Color
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        ZStack {
            // Main folder body (geometric rectangle like logo)
            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .fill(color.opacity(isSelected ? Color.FormaOpacity.overlay : (isHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light)))
                .frame(width: 48, height: 36)
                .offset(y: 4)

            // Folder tab (small rectangle on top-left, like logo asymmetry)
            RoundedRectangle(cornerRadius: FormaRadius.micro - (FormaRadius.micro / 4), style: .continuous)
                .fill(color.opacity(isSelected ? Color.FormaOpacity.strong : (isHovered ? Color.FormaOpacity.overlay : Color.FormaOpacity.medium)))
                .frame(width: 20, height: 8)
                .offset(x: -12, y: -12)
        }
        .animation(.easeOut(duration: 0.2), value: isSelected)
        .animation(.easeOut(duration: 0.2), value: isHovered)
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
