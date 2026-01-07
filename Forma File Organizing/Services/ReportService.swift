import Foundation
import SwiftData
import PDFKit
import AppKit

/// Composes analytics reports and handles PDF export.
@MainActor
final class ReportService {
    static let shared = ReportService()
    static let lastReportDateKey = "forma.analytics.lastWeeklyReportDate"

    private init() {}
}

// MARK: - Public API

extension ReportService {
    func generateReport(
        period: ReportPeriod,
        analyticsSummary: AnalyticsSummary,
        recommendations: [OptimizationRecommendation]
    ) -> AnalyticsReport {
        let storageChange = analyticsSummary.trendPoints.last?.totalBytes ?? 0
        let sections: [AnalyticsReportSection] = [
            AnalyticsReportSection(
                title: "Storage Trends",
                body: "Recent storage activity with growth and cleanup deltas.",
                metrics: [
                    "Current total": ByteCountFormatter.string(fromByteCount: storageChange, countStyle: .file),
                    "Points": "\(analyticsSummary.trendPoints.count)"
                ]
            ),
            AnalyticsReportSection(
                title: "Usage",
                body: "Organization activity and estimated time saved.",
                metrics: [
                    "Files organized": "\(analyticsSummary.usageStatistics.filesOrganized)",
                    "Bulk operations": "\(analyticsSummary.usageStatistics.bulkOperations)",
                    "Time saved": timeString(from: analyticsSummary.usageStatistics.timeSavedSeconds)
                ]
            ),
            AnalyticsReportSection(
                title: "Health",
                body: "Overall storage health with factor breakdowns.",
                metrics: [
                    "Score": "\(analyticsSummary.healthScore.score)",
                    "Grade": analyticsSummary.healthScore.grade
                ]
            )
        ]

        return AnalyticsReport(
            id: UUID(),
            generatedAt: Date(),
            period: period,
            storageTrendPoints: analyticsSummary.trendPoints,
            usageStatistics: analyticsSummary.usageStatistics,
            healthScore: analyticsSummary.healthScore,
            recommendations: recommendations,
            sections: sections
        )
    }

    func exportReportAsPDF(
        _ report: AnalyticsReport,
        to url: URL
    ) throws {
        let pageSize = CGSize(width: 612, height: 792) // US Letter @ 72 DPI
        let image = NSImage(size: pageSize)

        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            throw AnalyticsError.pdfExportFailed(underlyingError: NSError(domain: "ReportService", code: -1))
        }

        context.setFillColor(NSColor.formaBoneWhite.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: NSColor.formaSteelBlue
        ]

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]

        let title = "Forma Analytics Report"
        title.draw(in: CGRect(x: 40, y: pageSize.height - 80, width: pageSize.width - 80, height: 30), withAttributes: titleAttributes)

        let subtitle = "\(report.period.description) • Generated \(DateFormatter.short.string(from: report.generatedAt))"
        subtitle.draw(in: CGRect(x: 40, y: pageSize.height - 110, width: pageSize.width - 80, height: 20), withAttributes: bodyAttributes)

        var cursorY = pageSize.height - 140
        for section in report.sections {
            let sectionTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor.formaObsidian
            ]
            section.title.draw(in: CGRect(x: 40, y: cursorY, width: pageSize.width - 80, height: 20), withAttributes: sectionTitleAttrs)
            cursorY -= 22

            section.body.draw(in: CGRect(x: 40, y: cursorY, width: pageSize.width - 80, height: 18), withAttributes: bodyAttributes)
            cursorY -= 20

            for (key, value) in section.metrics {
                "\(key): \(value)".draw(in: CGRect(x: 50, y: cursorY, width: pageSize.width - 100, height: 16), withAttributes: bodyAttributes)
                cursorY -= 18
            }

            cursorY -= 12
        }

        if !report.recommendations.isEmpty {
            "Recommendations".draw(in: CGRect(x: 40, y: cursorY, width: pageSize.width - 80, height: 18), withAttributes: titleAttributes)
            cursorY -= 20

            for recommendation in report.recommendations.sorted(by: { $0.priority < $1.priority }) {
                "• \(recommendation.title) — \(recommendation.detail)".draw(in: CGRect(x: 50, y: cursorY, width: pageSize.width - 100, height: 16), withAttributes: bodyAttributes)
                cursorY -= 18
            }
        }

        image.unlockFocus()

        guard let page = PDFPage(image: image) else {
            throw AnalyticsError.pdfExportFailed(underlyingError: NSError(domain: "ReportService", code: -2))
        }

        let document = PDFDocument()
        document.insert(page, at: 0)

        if !document.write(to: url) {
            throw AnalyticsError.pdfExportFailed(underlyingError: NSError(domain: "ReportService", code: -3))
        }
    }

    func generateWeeklyReportIfNeeded(
        container: ModelContainer,
        now: Date = Date()
    ) async throws -> AnalyticsReport? {
        guard FeatureFlagService.shared.isEnabled(.analyticsAndInsights),
              FeatureFlagService.shared.isEnabled(.analyticsReports) else {
            return nil
        }

        guard shouldGenerateWeeklyReport(now: now) else { return nil }

        let summary = try await AnalyticsService.shared.loadAnalyticsSummary(for: .week, container: container)
        let recs = FeatureFlagService.shared.isEnabled(.optimizationRecommendations) ? summary.healthScore.recommendations : []
        let report = generateReport(period: .weekly, analyticsSummary: summary, recommendations: recs)

        UserDefaults.standard.set(now, forKey: Self.lastReportDateKey)
        return report
    }

    func shouldGenerateWeeklyReport(now: Date = Date()) -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: Self.lastReportDateKey) as? Date else {
            return true
        }
        return !Calendar.current.isDate(lastDate, equalTo: now, toGranularity: .weekOfYear)
    }
}

// MARK: - Helpers

private extension ReportPeriod {
    var description: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
}

private extension DateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private func timeString(from seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}
