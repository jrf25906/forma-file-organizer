import SwiftUI

/// Large KPI card for the "Big Three" impact metrics.
struct ImpactMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let trend: Trend?
    var showsScoreRamp: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    enum Trend {
        case up(String)
        case down(String)
        case neutral

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: return .formaSoftGreen
            case .down: return .formaError
            case .neutral: return .formaSecondaryLabelHigh
            }
        }

        var label: String? {
            switch self {
            case .up(let text), .down(let text):
                return text
            case .neutral:
                return nil
            }
        }
    }

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color = .formaSteelBlue,
        trend: Trend? = nil,
        showsScoreRamp: Bool = false
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.trend = trend
        self.showsScoreRamp = showsScoreRamp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Header with icon
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: icon)
                    .font(.formaH3)
                    .foregroundColor(color)

                Text(title)
                    .font(.formaCompactMedium)
                    .foregroundColor(.formaSecondaryLabelHigh)

                Spacer()

                // Trend indicator
                if let trend {
                    trendChip(trend)
                }
            }

            // Hero value
            Text(value)
                .font(.formaHero)
                .foregroundColor(.formaLabel)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Optional subtitle
            if let subtitle {
                Text(subtitle)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }

            if showsScoreRamp {
                scoreRamp
            }
        }
        .padding(FormaSpacing.generous)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaSurfaceWork)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(
                    Color.formaSeparator.opacity(colorScheme == .dark ? 0.64 : 0.42),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color.opacity(colorScheme == .dark ? 0.92 : 0.86))
                .frame(width: 4)
                .padding(.vertical, FormaSpacing.standard)
                .padding(.leading, FormaSpacing.tight)
        }
        .formaShadow(.resting)
    }

    private func trendChip(_ trend: Trend) -> some View {
        HStack(spacing: 3) {
            Image(systemName: trend.icon)
                .font(.formaCaptionSemibold)
            if let label = trend.label {
                Text(label)
                    .font(.formaCompactMedium)
                    .monospacedDigit()
            }
        }
        .foregroundColor(trend.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(trend.color.opacity(colorScheme == .dark ? 0.20 : 0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(trend.color.opacity(colorScheme == .dark ? 0.34 : 0.22), lineWidth: 0.75)
        )
    }

    private var scoreRamp: some View {
        HStack(spacing: 5) {
            ForEach(Array(scoreRampItems.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(item.color.opacity(colorScheme == .dark ? 0.86 : 0.78))
                        .frame(width: 18, height: 4)
                    Text(item.label)
                        .font(.formaMicro)
                        .foregroundColor(.formaTertiaryLabelHigh)
                        .lineLimit(1)
                }
            }
        }
        .padding(.top, FormaSpacing.micro)
    }

    private var scoreRampItems: [(label: String, color: Color)] {
        [
            ("A+", .formaSoftGreen),
            ("A", .formaSage),
            ("B", .formaSteelBlue),
            ("C", .formaWarning),
            ("Fix", .formaError)
        ]
    }
}

// MARK: - Convenience Initializers

extension ImpactMetricCard {
    /// Create a Space Reclaimed card.
    static func spaceReclaimed(_ bytes: Int64, previousBytes: Int64? = nil) -> ImpactMetricCard {
        let trend: Trend?
        if let previous = previousBytes, previous > 0 {
            let delta = bytes - previous
            let percentage = abs(Double(delta) / Double(previous) * 100)
            if delta > 0 {
                trend = .up("+\(Int(percentage))%")
            } else if delta < 0 {
                trend = .down("-\(Int(percentage))%")
            } else {
                trend = .neutral
            }
        } else {
            trend = nil
        }

        return ImpactMetricCard(
            title: "Space Reclaimed",
            value: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file),
            subtitle: "freed this period",
            icon: "arrow.up.trash.fill",
            color: .formaSoftGreen,
            trend: trend
        )
    }

    /// Create a Time Saved card.
    static func timeSaved(_ seconds: Int, previousSeconds: Int? = nil) -> ImpactMetricCard {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        let value: String
        if hours > 0 {
            value = "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            value = "\(minutes) min"
        } else {
            value = "< 1 min"
        }

        let trend: Trend?
        if let previous = previousSeconds, previous > 0 {
            let delta = seconds - previous
            let percentage = abs(Double(delta) / Double(previous) * 100)
            if delta > 0 {
                trend = .up("+\(Int(percentage))%")
            } else if delta < 0 {
                trend = .down("-\(Int(percentage))%")
            } else {
                trend = .neutral
            }
        } else {
            trend = nil
        }

        return ImpactMetricCard(
            title: "Time Saved",
            value: value,
            subtitle: "from automation",
            icon: "clock.arrow.circlepath",
            color: .formaSteelBlue,
            trend: trend
        )
    }

    /// Create an Organization Score card.
    static func organizationScore(_ score: Int) -> ImpactMetricCard {
        let grade: String
        let color: Color

        switch score {
        case 90...100:
            grade = "A+"
            color = .formaSoftGreen
        case 85..<90:
            grade = "A"
            color = .formaSoftGreen
        case 80..<85:
            grade = "B+"
            color = .formaSage
        case 75..<80:
            grade = "B"
            color = .formaSage
        case 70..<75:
            grade = "C+"
            color = .formaSteelBlue
        case 60..<70:
            grade = "C"
            color = .formaSteelBlue
        default:
            grade = "Needs Work"
            color = .formaWarning
        }

        return ImpactMetricCard(
            title: "Organization Score",
            value: "\(score)",
            subtitle: grade,
            icon: "chart.bar.fill",
            color: color,
            showsScoreRamp: true
        )
    }
}

// MARK: - Preview

#Preview("Impact Metrics") {
    HStack(spacing: FormaSpacing.generous) {
        ImpactMetricCard.spaceReclaimed(2_500_000_000, previousBytes: 1_800_000_000)
        ImpactMetricCard.timeSaved(2700, previousSeconds: 1800)
        ImpactMetricCard.organizationScore(87)
    }
    .padding()
    .background(Color.formaBoneWhite)
}
