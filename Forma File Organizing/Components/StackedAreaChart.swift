import SwiftUI
import Charts

/// Stacked area chart showing manual vs automated file operations over time.
struct StackedAreaChart: View {
    let points: [AutomationEfficiencyPoint]
    var showLegend: Bool = true
    var chrome: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    /// Transform points into chart-friendly data.
    private var chartData: [ChartDataPoint] {
        var result: [ChartDataPoint] = []

        for point in points {
            result.append(ChartDataPoint(
                date: point.date,
                count: point.manualActions,
                type: .manual
            ))
            result.append(ChartDataPoint(
                date: point.date,
                count: point.automatedActions,
                type: .automated
            ))
        }

        return result
    }

    /// Overall automation rate.
    private var automationRate: Double {
        let totalManual = points.map(\.manualActions).reduce(0, +)
        let totalAuto = points.map(\.automatedActions).reduce(0, +)
        let total = totalManual + totalAuto
        guard total > 0 else { return 0 }
        return Double(totalAuto) / Double(total)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.formaSurfaceFloating.opacity(0.52)
            : Color.formaSurfaceFloating.opacity(0.76)
    }

    private var cardBorder: Color {
        Color.formaSeparator.opacity(colorScheme == .dark ? 0.38 : 0.24)
    }

    private var plotAreaBackground: Color {
        colorScheme == .dark
            ? Color.formaSurfaceAnchor.opacity(0.22)
            : Color.formaSurfaceChrome.opacity(0.58)
    }

    private var plotAreaBorder: Color {
        Color.formaSeparator.opacity(colorScheme == .dark ? 0.24 : 0.18)
    }

    private var axisLineColor: Color {
        Color.formaSeparator.opacity(colorScheme == .dark ? 0.45 : Color.FormaOpacity.medium)
    }

    private var emptyStatePrimaryColor: Color {
        colorScheme == .dark
            ? .formaSecondaryLabelHigh
            : Color.formaLabel.opacity(0.7)
    }

    private var emptyStateSecondaryColor: Color {
        colorScheme == .dark
            ? .formaTertiaryLabelHigh
            : Color.formaLabel.opacity(0.55)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            if points.isEmpty {
                emptyState
            } else {
                chart

                if showLegend {
                    legend
                }
            }
        }
        .padding(chrome ? FormaSpacing.large : 0)
        .background {
            if chrome {
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(cardBackground)
            }
        }
        .overlay {
            if chrome {
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        Chart(chartData) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Actions", point.count),
                stacking: .standard
            )
            .foregroundStyle(by: .value("Type", point.type.label))
        }
        .chartForegroundStyleScale([
            ActionType.manual.label: Color.formaMutedBlue.opacity(0.7),
            ActionType.automated.label: Color.formaSoftGreen.opacity(0.7)
        ])
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine()
                    .foregroundStyle(axisLineColor)
                AxisTick()
                    .foregroundStyle(axisLineColor)
                AxisValueLabel(format: .dateTime.month().day())
                    .foregroundStyle(Color.formaSecondaryLabelHigh)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                    .foregroundStyle(axisLineColor)
                AxisTick()
                    .foregroundStyle(axisLineColor)
                AxisValueLabel {
                    if let count = value.as(Int.self) {
                        Text("\(count)")
                    }
                }
                .foregroundStyle(Color.formaSecondaryLabelHigh)
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                        .fill(plotAreaBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                        .strokeBorder(plotAreaBorder, lineWidth: FormaBorderWidth.hairline)
                )
        }
        .frame(minHeight: 200)
    }

    @ViewBuilder
    private var legend: some View {
        HStack(spacing: FormaSpacing.generous) {
            // Manual legend
            HStack(spacing: FormaSpacing.tight) {
                Circle()
                    .fill(Color.formaMutedBlue.opacity(0.7))
                    .frame(width: 8, height: 8)
                Text("Manual")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }

            // Automated legend
            HStack(spacing: FormaSpacing.tight) {
                Circle()
                    .fill(Color.formaSoftGreen.opacity(0.7))
                    .frame(width: 8, height: 8)
                Text("Automated")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }

            Spacer()

            // Automation rate badge
            HStack(spacing: 4) {
                Image(systemName: "wand.and.stars")
                    .font(.formaSmall)
                Text("\(Int(automationRate * 100))% automated")
                    .font(.formaSmallSemibold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundColor(.formaSoftGreen)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: FormaSpacing.tight) {
            Image(systemName: "chart.xyaxis.line")
                .font(.formaH3)
                .foregroundColor(emptyStateSecondaryColor)
            Text("No activity data yet")
                .font(.formaSmallSemibold)
                .foregroundColor(emptyStatePrimaryColor)
            Text("Organize some files to see your automation efficiency.")
                .font(.formaSmall)
                .foregroundColor(emptyStateSecondaryColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FormaSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
    }
}

// MARK: - Supporting Types

private struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let type: ActionType
}

private enum ActionType: String {
    case manual
    case automated

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .automated: return "Automated"
        }
    }
}

// MARK: - Preview

#Preview("Stacked Area Chart") {
    let calendar = Calendar.current
    let today = Date()

    let samplePoints = (0..<14).map { dayOffset -> AutomationEfficiencyPoint in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        // Simulate increasing automation over time
        let automationBias = Double(14 - dayOffset) / 14.0
        let manual = Int.random(in: 5...20)
        let automated = Int(Double(manual) * automationBias * 2)
        return AutomationEfficiencyPoint(
            date: date,
            manualActions: manual,
            automatedActions: automated
        )
    }.reversed()

    VStack {
        Text("Automation Efficiency")
            .font(.formaH2)
            .foregroundColor(.formaObsidian)

        StackedAreaChart(points: Array(samplePoints))
    }
    .padding()
    .background(Color.formaBoneWhite)
}
