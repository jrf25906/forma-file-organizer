import SwiftUI

/// GitHub-style calendar heatmap showing file staleness over 365 days.
struct CalendarHeatmap: View {
    let data: [DayStaleness]
    var onNudgeCleanup: (() -> Void)?

    @State private var hoveredDay: DayStaleness?

    /// Grid dimensions
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let weeksToShow = 52

    /// Organize data into a grid (52 weeks x 7 days)
    private var gridData: [[DayStaleness?]] {
        let calendar = Calendar.current
        let today = Date().startOfDayLocal

        // Start from 52 weeks ago, on a Sunday
        guard var startDate = calendar.date(byAdding: .weekOfYear, value: -51, to: today) else {
            return []
        }
        // Adjust to Sunday
        let weekday = calendar.component(.weekday, from: startDate)
        if weekday != 1 {
            startDate = calendar.date(byAdding: .day, value: -(weekday - 1), to: startDate) ?? startDate
        }

        // Build lookup dictionary
        var dataLookup: [Date: DayStaleness] = [:]
        for item in data {
            let dayStart = calendar.startOfDay(for: item.date)
            dataLookup[dayStart] = item
        }

        // Build grid
        var grid: [[DayStaleness?]] = []
        var currentDate = startDate

        for _ in 0..<weeksToShow {
            var week: [DayStaleness?] = []
            for _ in 0..<7 {
                if currentDate <= today {
                    let dayStart = calendar.startOfDay(for: currentDate)
                    week.append(dataLookup[dayStart])
                } else {
                    week.append(nil)
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            grid.append(week)
        }

        return grid
    }

    /// Total "Digital Dust" count
    private var digitalDustCount: Int {
        data.map(\.digitalDustCount).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Month labels
            monthLabels

            HStack(alignment: .top, spacing: 4) {
                // Weekday labels
                weekdayLabels

                // Calendar grid
                calendarGrid
            }

            HStack {
                // Legend
                legend

                Spacer()

                // Digital dust callout
                if digitalDustCount > 0 {
                    digitalDustBadge
                }
            }
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaObsidian.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var monthLabels: some View {
        let calendar = Calendar.current
        let today = Date().startOfDayLocal

        HStack(spacing: 0) {
            // Offset for weekday labels
            Color.clear.frame(width: 24)

            // Generate month labels
            HStack(spacing: 0) {
                ForEach(0..<12, id: \.self) { monthOffset in
                    if let monthDate = calendar.date(byAdding: .month, value: -(11 - monthOffset), to: today) {
                        let monthName = monthDate.formatted(.dateTime.month(.abbreviated))
                        Text(monthName)
                            .font(.formaMicro)
                            .foregroundColor(.formaSecondaryLabel)
                            .frame(width: (cellSize + cellSpacing) * 4.33, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weekdayLabels: some View {
        let days = ["", "M", "", "W", "", "F", ""]

        VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { index in
                Text(days[index])
                    .font(.formaMicro)
                    .foregroundColor(.formaSecondaryLabel)
                    .frame(width: 20, height: cellSize)
            }
        }
    }

    @ViewBuilder
    private var calendarGrid: some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<gridData.count, id: \.self) { weekIndex in
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        if weekIndex < gridData.count && dayIndex < gridData[weekIndex].count {
                            if let dayData = gridData[weekIndex][dayIndex] {
                                CalendarCell(
                                    staleness: dayData,
                                    size: cellSize,
                                    isHovered: hoveredDay?.id == dayData.id
                                )
                                .onHover { isHovering in
                                    hoveredDay = isHovering ? dayData : nil
                                }
                            } else {
                                // Empty cell (future or no data)
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color.formaObsidian.opacity(0.05))
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var legend: some View {
        HStack(spacing: FormaSpacing.tight) {
            Text("Fresh")
                .font(.formaMicro)
                .foregroundColor(.formaSecondaryLabel)

            HStack(spacing: 2) {
                ForEach(StalenessLevel.allCases, id: \.rawValue) { level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colorForStaleness(level))
                        .frame(width: cellSize, height: cellSize)
                }
            }

            Text("Digital Dust")
                .font(.formaMicro)
                .foregroundColor(.formaSecondaryLabel)
        }
    }

    @ViewBuilder
    private var digitalDustBadge: some View {
        Button(action: { onNudgeCleanup?() }) {
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .font(.formaSmall)
                Text("\(digitalDustCount) \(digitalDustCount == 1 ? "file needs" : "files need") attention")
                    .font(.formaSmallSemibold)
            }
            .foregroundColor(.formaError)
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight)
            .background(Color.formaError.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func colorForStaleness(_ level: StalenessLevel) -> Color {
        switch level {
        case .fresh:
            return Color.formaSoftGreen.opacity(0.9)
        case .recent:
            return Color.formaSage.opacity(0.8)
        case .aging:
            return Color.formaWarning.opacity(0.7)
        case .stale:
            return Color.orange.opacity(0.8)
        case .digitalDust:
            return Color.formaError.opacity(0.9)
        }
    }
}

// MARK: - Calendar Cell

private struct CalendarCell: View {
    let staleness: DayStaleness
    let size: CGFloat
    let isHovered: Bool

    private var backgroundColor: Color {
        let level = staleness.dominantLevel
        switch level {
        case .fresh:
            return Color.formaSoftGreen.opacity(0.9)
        case .recent:
            return Color.formaSage.opacity(0.8)
        case .aging:
            return Color.formaWarning.opacity(0.7)
        case .stale:
            return Color.orange.opacity(0.8)
        case .digitalDust:
            return Color.formaError.opacity(0.9)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(staleness.totalFiles > 0 ? backgroundColor : Color.formaObsidian.opacity(0.05))
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(isHovered ? Color.formaObsidian.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.2 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
            .help(tooltipText)
    }

    private var tooltipText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if staleness.totalFiles == 0 {
            return "\(formatter.string(from: staleness.date)): No file activity"
        }

        let dustCount = staleness.fileCounts[.digitalDust] ?? 0
        if dustCount > 0 {
            return "\(formatter.string(from: staleness.date)): \(staleness.totalFiles) files (\(dustCount) need attention)"
        }

        return "\(formatter.string(from: staleness.date)): \(staleness.totalFiles) files"
    }
}

// MARK: - Preview

#Preview("Calendar Heatmap") {
    let calendar = Calendar.current
    let today = Date()

    // Generate sample data for 365 days
    let sampleData = (0..<365).map { dayOffset -> DayStaleness in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!

        // Random staleness distribution
        var fileCounts: [StalenessLevel: Int] = [:]
        var byteCounts: [StalenessLevel: Int64] = [:]

        let hasActivity = Bool.random()
        if hasActivity {
            let level = StalenessLevel.allCases.randomElement() ?? .fresh
            fileCounts[level] = Int.random(in: 1...20)
            byteCounts[level] = Int64.random(in: 1_000_000...100_000_000)
        }

        return DayStaleness(
            date: date,
            fileCounts: fileCounts,
            byteCounts: byteCounts
        )
    }

    VStack(alignment: .leading) {
        Text("File Activity Heatmap")
            .font(.formaH2)
            .foregroundColor(.formaObsidian)

        CalendarHeatmap(data: sampleData) {
            Log.debug("CalendarHeatmap: nudge cleanup tapped", category: .ui)
        }
    }
    .padding()
    .background(Color.formaBoneWhite)
    .frame(width: 900)
}
