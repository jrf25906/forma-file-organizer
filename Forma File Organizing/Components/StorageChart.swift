import SwiftUI

struct StorageChart: View {
    let analytics: StorageAnalytics
    /// Optional historical snapshot analytics to render instead of live analytics.
    var historicalAnalytics: StorageAnalytics? = nil
    let size: CGFloat
    @State private var animationProgress: CGFloat = 0

    private let categories: [FileTypeCategory] = [.documents, .images, .videos, .audio, .archives]

    var body: some View {
        let activeAnalytics = historicalAnalytics ?? analytics
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.light), lineWidth: FormaSpacing.standard - FormaSpacing.micro)

            // Segmented progress rings
            ForEach(Array(categories.enumerated()), id: \.offset) { _, category in
                let percentage = activeAnalytics.percentageForCategory(category)
                if percentage > 0 {
                    SegmentShape(
                        startAngle: startAngle(for: category, analytics: activeAnalytics),
                        endAngle: endAngle(for: category, analytics: activeAnalytics),
                        progress: animationProgress
                    )
                    .stroke(category.color, lineWidth: 12)
                }
            }

            // Center content
            VStack(spacing: FormaSpacing.micro) {
                Text(activeAnalytics.totalSize)
                    .font(.formaH1)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundColor(.formaLabel)

                Text("Used")
                    .font(.formaCompact)
                    .foregroundColor(.formaSecondaryLabel)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animationProgress = 1.0
            }
        }
    }

    private func startAngle(for category: FileTypeCategory, analytics: StorageAnalytics) -> Angle {
        var accumulatedPercentage: Double = 0

        for cat in categories {
            if cat == category {
                break
            }
            accumulatedPercentage += analytics.percentageForCategory(cat)
        }

        // Convert percentage to angle (0% = -90°, 100% = 270°)
        let degrees = -90 + (accumulatedPercentage * 3.6)
        return Angle(degrees: degrees)
    }

    private func endAngle(for category: FileTypeCategory, analytics: StorageAnalytics) -> Angle {
        let startDegrees = startAngle(for: category, analytics: analytics).degrees
        let categoryPercentage = analytics.percentageForCategory(category)
        let endDegrees = startDegrees + (categoryPercentage * 3.6)
        return Angle(degrees: endDegrees)
    }
}

struct SegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        let actualEndAngle = Angle(degrees: startAngle.degrees + (endAngle.degrees - startAngle.degrees) * progress)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: actualEndAngle,
            clockwise: false
        )

        return path
    }
}

// MARK: - Preview
#Preview {
    StorageChart(
        analytics: StorageAnalytics(
            totalBytes: 158_273_331,
            categoryBreakdown: [
                .documents: 1_509_171,
                .images: 4_718_592,
                .videos: 0,
                .audio: 0,
                .archives: 152_043_520
            ],
            fileCount: 5,
            categoryFileCounts: [
                .documents: 2,
                .images: 1,
                .archives: 1
            ]
        ),
        size: 180
    )
    .padding()
}
