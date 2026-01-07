import SwiftUI

struct ReportPreviewView: View {
    let report: AnalyticsReport
    let exportAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack {
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text("Latest Report")
                        .font(.formaH3)
                        .foregroundColor(.formaObsidian)
                    Text("\(report.period.description) • \(reportDateFormatter.string(from: report.generatedAt))")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }
                Spacer()
                Button("Export as PDF", action: exportAction)
                    .buttonStyle(.borderedProminent)
            }

            HStack(spacing: FormaSpacing.large) {
                AnalyticsStatCard(icon: "chart.line.uptrend.xyaxis", value: "\(report.storageTrendPoints.count)", label: "Trend points", color: Color.formaSteelBlue)
                AnalyticsStatCard(icon: "clock", value: timeString(from: report.usageStatistics.timeSavedSeconds), label: "Time saved", color: Color.formaMutedBlue)
                AnalyticsStatCard(icon: "heart.text.square", value: "\(report.healthScore.score)", label: "Health score", color: Color.formaSage)
            }

            if !report.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text("Top Recommendations")
                        .font(.formaBody)
                        .foregroundColor(.formaObsidian)
                    ForEach(report.recommendations.sorted(by: { $0.priority < $1.priority }).prefix(3)) { recommendation in
                        Text("• \(recommendation.title): \(recommendation.detail)")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                }
            }
        }
        .padding(FormaSpacing.large)
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle), radius: 8, x: 0, y: 4)
    }
}

private extension ReportPeriod {
    var description: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
}

private let reportDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

private func timeString(from seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}
