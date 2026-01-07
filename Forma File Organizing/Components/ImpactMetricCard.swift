import SwiftUI

/// Large KPI card for the "Big Three" impact metrics.
struct ImpactMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let trend: Trend?

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
            case .neutral: return .formaSecondaryLabel
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
        trend: Trend? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.trend = trend
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
                    .foregroundColor(.formaSecondaryLabel)

                Spacer()

                // Trend indicator
                if let trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend.icon)
                            .font(.formaSmall)
                        if let label = trend.label {
                            Text(label)
                                .font(.formaSmall)
                        }
                    }
                    .foregroundColor(trend.color)
                }
            }

            // Hero value
            Text(value)
                .font(.formaHero)
                .foregroundColor(.formaObsidian)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Optional subtitle
            if let subtitle {
                Text(subtitle)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
            }
        }
        .padding(FormaSpacing.generous)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .shadow(
            color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle),
            radius: 8,
            x: 0,
            y: 4
        )
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
            color: .formaMutedBlue,
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
            color: color
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
