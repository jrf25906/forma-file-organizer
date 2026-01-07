import SwiftUI
import SwiftData

struct ActivityFeed: View {
    let activities: [ActivityItem]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(Color.formaSecondaryLabel)
                    .accessibilityHidden(true)
                Text("Activity")
                    .formaH2Style()
                    .foregroundColor(Color.formaObsidian)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Activity feed")
            .accessibilityAddTraits(.isHeader)

            // Activity list
            if activities.isEmpty {
                EmptyActivityFeed()
            } else {
                ScrollView {
                    VStack(spacing: FormaSpacing.tight) {
                        ForEach(activities, id: \.id) { activity in
                            ActivityRow(activity: activity)
                        }
                    }
                }
                .accessibilityLabel("Activity list with \(activities.count) \(activities.count == 1 ? "item" : "items")")
            }
        }
        .padding(FormaSpacing.generous)
    }
}

struct ActivityRow: View {
    let activity: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: FormaSpacing.standard) {
            // Icon
            Image(systemName: activity.activityType.iconName)
                .font(.formaBodyMedium)
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(iconColor.opacity(Color.FormaOpacity.light))
                )
                .accessibilityHidden(true) // Icon is decorative, info in combined label

            // Content
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                HStack {
                    Text(activity.fileName)
                        .formaMetadataStyle()
                        .foregroundColor(Color.formaObsidian)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if let ext = activity.fileExtension {
                        Text(ext.uppercased())
                            .font(.formaCaptionSemibold)
                            .foregroundColor(.formaBoneWhite)
                            .padding(.horizontal, FormaSpacing.micro)
                            .padding(.vertical, FormaSpacing.micro / 2)
                            .background(
                                Capsule()
                                    .fill(FileTypeCategory.category(for: ext).color)
                            )
                            .accessibilityHidden(true) // Included in combined label
                    }
                }

                Text(activity.details)
                    .font(.formaSmall)
                    .foregroundColor(Color.formaSecondaryLabel)
                    .lineLimit(2)

                Text(activity.relativeTimestamp)
                    .font(.formaCaption)
                    .foregroundColor(Color.formaTertiaryLabel)
            }

            Spacer()
        }
        .padding(FormaSpacing.tight)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                .fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Activity item in your history")
    }

    /// Combined accessibility description for screen readers
    private var accessibilityDescription: String {
        var parts: [String] = []

        // Activity type comes first
        parts.append(activity.activityType.displayName)

        // File name with extension
        if let ext = activity.fileExtension {
            parts.append("\(activity.fileName), \(ext.uppercased()) file")
        } else {
            parts.append(activity.fileName)
        }

        // Details
        parts.append(activity.details)

        // Relative time
        parts.append(activity.relativeTimestamp)

        return parts.joined(separator: ". ")
    }

    private var iconColor: Color {
        switch activity.activityType {
        // File operations
        case .fileScanned:
            return Color.formaSteelBlue
        case .fileOrganized, .fileMoved:
            return Color.formaSage
        case .fileSkipped:
            return Color.formaWarmOrange
        case .fileDeleted:
            return Color.formaError
        case .operationFailed:
            return Color.formaError

        // Rule operations
        case .ruleCreated, .ruleApplied, .ruleUpdated:
            return Color.formaMutedBlue
        case .ruleDeleted:
            return Color.formaError

        // Onboarding & setup
        case .onboardingCompleted:
            return Color.formaSage
        case .folderAccessGranted:
            return Color.formaMutedBlue

        // Duplicate handling
        case .duplicatesDetected:
            return Color.formaWarmOrange
        case .duplicateDeleted:
            return Color.formaError
        case .duplicateKept:
            return Color.formaSage

        // AI & learning
        case .patternLearned, .patternApplied:
            return Color.formaSteelBlue
        case .aiSuggestionAccepted:
            return Color.formaSage
        case .aiSuggestionRejected:
            return Color.formaWarmOrange

        // Bulk operations
        case .bulkOrganized:
            return Color.formaSage
        case .bulkUndone:
            return Color.formaSteelBlue
        case .bulkPartialFailure:
            return Color.formaWarmOrange

        // Automation (v1.4)
        case .automationScanCompleted:
            return Color.formaSteelBlue
        case .automationAutoOrganized:
            return Color.formaSage
        case .automationError:
            return Color.formaError
        case .automationPaused:
            return Color.formaWarmOrange
        case .automationResumed:
            return Color.formaSage
        }
    }
}

struct EmptyActivityFeed: View {
    var body: some View {
        VStack(spacing: FormaSpacing.standard) {
            Image(systemName: "tray")
                .font(.formaIconMedium)
                .foregroundColor(Color.formaTertiaryLabel)
                .accessibilityHidden(true)

            Text("No Activity Yet")
                .formaBodyStyle()
                .foregroundColor(Color.formaSecondaryLabel)

            Text("Your recent actions will appear here")
                .formaMetadataStyle()
                .foregroundColor(Color.formaTertiaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(FormaSpacing.extraLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No activity yet. Your recent actions will appear here.")
    }
}

// MARK: - Preview
#Preview {
    ActivityFeed(activities: ActivityItem.mocks)
        .frame(width: 280, height: 400)
}
