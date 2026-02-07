import SwiftUI

// MARK: - JIT Permission Card

/// Inline permission request shown when the user clicks a locked folder in the sidebar.
/// Displays in the main content area with a clear explanation and single "Grant Access" CTA.
/// Dismisses automatically once access is granted.
struct JITPermissionCard: View {
    let folderName: String
    let onGrantAccess: () -> Void

    var body: some View {
        VStack(spacing: FormaSpacing.generous) {
            Spacer()

            VStack(spacing: FormaSpacing.generous) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundColor(.formaSteelBlue)

                VStack(spacing: FormaSpacing.tight) {
                    Text("Forma needs access to \(folderName)")
                        .font(.formaH3)
                        .foregroundColor(.formaLabel)
                        .multilineTextAlignment(.center)

                    Text("Grant access so Forma can scan and organize files in your \(folderName) folder.")
                        .font(.formaBody)
                        .foregroundColor(.formaSecondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FormaSpacing.large)
                }

                Button(action: onGrantAccess) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.formaBodySemibold)
                        Text("Grant Access")
                            .font(.formaBodyLarge)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.formaBoneWhite)
                    .padding(.horizontal, FormaSpacing.large)
                    .padding(.vertical, FormaSpacing.standard)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaSteelBlue)
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: "lock.shield.fill")
                        .font(.formaCaption)
                        .foregroundColor(.formaTertiaryLabel)
                    Text("Files stay on your Mac. Forma never uploads anything.")
                        .font(.formaSmall)
                        .foregroundColor(.formaTertiaryLabel)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("JIT Permission Card") {
    JITPermissionCard(
        folderName: "Documents",
        onGrantAccess: {}
    )
    .frame(width: 600, height: 400)
    .background(Color.formaBackground)
}
