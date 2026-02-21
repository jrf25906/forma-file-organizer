import Foundation
import SwiftData
import SwiftUI
import PDFKit
import AppKit

/// Composes analytics reports and handles PDF export.
@MainActor
final class ReportService {
    static let shared = ReportService()
    static let lastReportDateKey = "forma.analytics.lastWeeklyReportDate"

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let clock: Clock

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        clock: Clock = SystemClock()
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.clock = clock
    }
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
            generatedAt: clock.now,
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
        let pdfView = ReportPDFView(report: report)
        
        let pageSize = CGSize(width: 612, height: 792) // US Letter @ 72 DPI
        
        let hostingView = NSHostingView(rootView: pdfView)
        hostingView.frame = CGRect(origin: .zero, size: pageSize)
        
        // Force a layout pass
        hostingView.layout()

        // Create PDF context
        var box = CGRect(origin: .zero, size: pageSize)
        guard let pdfContext = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw AnalyticsError.pdfExportFailed(underlyingError: NSError(domain: "ReportService", code: -2))
        }

        // Render to PDF
        pdfContext.beginPDFPage(nil)
        
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: hostingView.isFlipped)
        NSGraphicsContext.current = nsContext
        hostingView.displayIgnoringOpacity(hostingView.bounds, in: nsContext)

        NSGraphicsContext.current = nil
        pdfContext.endPDFPage()
        pdfContext.closePDF()
    }

    func generateWeeklyReportIfNeeded(
        container: ModelContainer,
        now: Date? = nil
    ) async throws -> AnalyticsReport? {
        guard FeatureFlagService.shared.isEnabled(.analyticsAndInsights),
              FeatureFlagService.shared.isEnabled(.analyticsReports) else {
            return nil
        }

        let effectiveNow = now ?? clock.now
        guard shouldGenerateWeeklyReport(now: effectiveNow) else { return nil }

        let summary = try await AnalyticsService.shared.loadAnalyticsSummary(for: .week, container: container)
        let recs = FeatureFlagService.shared.isEnabled(.optimizationRecommendations) ? summary.healthScore.recommendations : []
        let report = generateReport(period: .weekly, analyticsSummary: summary, recommendations: recs)

        defaults.set(effectiveNow, forKey: Self.lastReportDateKey)
        return report
    }

    func shouldGenerateWeeklyReport(now: Date? = nil) -> Bool {
        let effectiveNow = now ?? clock.now
        guard let lastDate = defaults.object(forKey: Self.lastReportDateKey) as? Date else {
            return true
        }
        return !calendar.isDate(lastDate, equalTo: effectiveNow, toGranularity: .weekOfYear)
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
