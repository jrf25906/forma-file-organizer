import SwiftUI
import Charts

struct TrendChart: View {
    let points: [StorageTrendPoint]
    var highlightedDate: Date?

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Storage", point.totalBytes)
            )
            .foregroundStyle(Color.formaSteelBlue)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

            AreaMark(
                x: .value("Date", point.date),
                y: .value("Storage", point.totalBytes)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay + Color.FormaOpacity.subtle), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
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
                    if let bytes = value.as(Int64.self) {
                        Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    }
                }
            }
        }

    }
}
