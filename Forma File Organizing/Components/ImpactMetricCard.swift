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

    private var tileFill: Color {
        colorScheme == .dark
            ? Color.formaSurfaceFloating.opacity(0.78)
            : Color.formaSurfaceFloating
    }

    private var tileBorder: Color {
        Color.formaSeparator.opacity(colorScheme == .dark ? 0.46 : 0.30)
    }

    private var iconFill: Color {
        color.opacity(colorScheme == .dark ? 0.18 : 0.10)
    }

    private var accessibilitySummary: String {
        var parts = [title, value]

        if let subtitle {
            parts.append(subtitle)
        }

        if let trendLabel = trend?.label {
            parts.append("Trend \(trendLabel)")
        }

        return parts.joined(separator: ", ")
    }

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
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: icon)
                    .font(.formaSmallSemibold)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .fill(iconFill)
                    )

                Text(title)
                    .font(.formaCompactSemibold)
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: FormaSpacing.tight)

                if let trend {
                    trendChip(trend)
                }
            }

            Text(value)
                .font(.formaH1)
                .foregroundColor(.formaLabel)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.64)

            if let subtitle {
                Text(subtitle)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            if showsScoreRamp {
                scoreRamp
            }
        }
        .padding(.vertical, FormaSpacing.large)
        .padding(.horizontal, FormaSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 124, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .fill(tileFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .strokeBorder(tileBorder, lineWidth: FormaBorderWidth.thin)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
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
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(trend.color.opacity(colorScheme == .dark ? 0.16 : 0.08))
        )
        .overlay(
            Capsule()
                .strokeBorder(trend.color.opacity(colorScheme == .dark ? 0.28 : 0.18), lineWidth: FormaBorderWidth.hairline)
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
