import SwiftUI
import Charts

/// Stacked area chart showing manual vs automated file operations over time.
struct StackedAreaChart: View {
    let points: [AutomationEfficiencyPoint]
    var showLegend: Bool = true

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
        .padding(FormaSpacing.large)
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .shadow(
            color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle),
            radius: 8,
            x: 0,
            y: 4
        )
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
                AxisTick()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let count = value.as(Int.self) {
                        Text("\(count)")
                    }
                }
            }
        }
        .chartLegend(.hidden)
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
                    .foregroundColor(.formaSecondaryLabel)
            }

            // Automated legend
            HStack(spacing: FormaSpacing.tight) {
                Circle()
                    .fill(Color.formaSoftGreen.opacity(0.7))
                    .frame(width: 8, height: 8)
                Text("Automated")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()

            // Automation rate badge
            HStack(spacing: 4) {
                Image(systemName: "wand.and.stars")
                    .font(.formaSmall)
                Text("\(Int(automationRate * 100))% automated")
                    .font(.formaSmallSemibold)
            }
            .foregroundColor(.formaSoftGreen)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: FormaSpacing.tight) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title)
                .foregroundColor(.formaSecondaryLabel)
            Text("No activity data yet")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
            Text("Organize some files to see your automation efficiency.")
                .font(.formaSmall)
                .foregroundColor(.formaTertiaryLabel)
                .multilineTextAlignment(.center)
        }
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
