import SwiftUI
import Combine

/// Compact widget displaying automation status in the right panel.
///
/// Shows:
/// - Circular countdown ring showing time until next scan
/// - Quick pause/resume toggle
/// - Last run stats inline (always visible)
///
/// Designed to fit within DefaultPanelView's scrolling content area.
struct AutomationStatusWidget: View {
    let pendingReviewCount: Int
    let activeScopeCount: Int
    let attentionScopeCount: Int
    let presentation: DashboardAutomationStatusPresentation?
    private let engine = AutomationEngine.shared
    private let automationState = AutomationEngine.shared.state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rightPanelLayout) private var rightPanelLayout
    @State private var isHovered: Bool = false
    @State private var hoveredInlineControl: InlineControl?
    @State private var currentTime: Date = Date()

    private enum InlineControl {
        case scan
        case pauseResume
    }

    /// Timer to update countdown display
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        pendingReviewCount: Int = 0,
        activeScopeCount: Int = 0,
        attentionScopeCount: Int = 0,
        presentation: DashboardAutomationStatusPresentation? = nil
    ) {
        self.pendingReviewCount = pendingReviewCount
        self.activeScopeCount = activeScopeCount
        self.attentionScopeCount = attentionScopeCount
        self.presentation = presentation
    }

    /// Whether the automation is paused (neither running nor scheduled)
    private var isPaused: Bool {
        automationState.nextScheduledRun == nil && !automationState.isRunning
    }

    /// Calculate countdown progress (1.0 = full, depletes to 0.0)
    private var countdownProgress: Double {
        guard let nextRun = automationState.nextScheduledRun,
              let lastRun = automationState.lastRunDate else {
            return isPaused ? 0.0 : 1.0
        }

        let totalInterval = nextRun.timeIntervalSince(lastRun)
        let elapsed = currentTime.timeIntervalSince(lastRun)

        guard totalInterval > 0 else { return 1.0 }

        let remaining = max(0, 1.0 - (elapsed / totalInterval))
        return remaining
    }

    /// Formatted countdown string (e.g., "4:32")
    private var countdownText: String {
        guard let nextRun = automationState.nextScheduledRun else {
            return isPaused ? "—" : "..."
        }

        let remaining = max(0, nextRun.timeIntervalSince(currentTime))
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60

        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        } else {
            return "\(seconds)s"
        }
    }

    private var isCompactLayout: Bool {
        rightPanelLayout.isCompact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Section Header with status label
            HStack {
                Text("AUTOMATION")
                    .font(.formaCaption)
                    .tracking(0.8)
                    .foregroundStyle(Color.formaTertiaryLabel)

                Spacer()

                // Status label next to dot for clarity
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(Color.FormaOpacity.strong), radius: 2)

                    Text(statusLabel)
                        .font(.formaCaption)
                        .foregroundStyle(statusColor)
                }
            }

            // Main status card with countdown ring
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Group {
                    if isCompactLayout {
                        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                                countdownRing
                                    .frame(width: 40, height: 40)

                                statusTextBlock
                            }

                            compactControlStack
                        }
                    } else {
                        HStack(alignment: .center, spacing: FormaSpacing.standard) {
                            countdownRing
                                .frame(width: 40, height: 40)

                            statusTextBlock

                            Spacer(minLength: 0)

                            regularControlStrip
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPaused)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: automationState.isRunning)

                // Last run stats (always visible when available)
                if automationState.lastRunDate != nil && !automationState.isRunning {
                    lastRunStats
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(
                        isHovered
                            ? Color.formaObsidian.opacity(colorScheme == .dark ? 0.28 : Color.FormaOpacity.light)
                            : Color.formaObsidian.opacity(colorScheme == .dark ? 0.18 : Color.FormaOpacity.subtle)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        Color.formaObsidian.opacity(
                            isHovered
                                ? (colorScheme == .dark ? 0.35 : Color.FormaOpacity.medium)
                                : (colorScheme == .dark ? 0.25 : Color.FormaOpacity.light)
                        ),
                        lineWidth: 1
                    )
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { time in
            currentTime = time
        }
    }

    private var statusTextBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(statusMessage)
                .font(.formaBodyMedium)
                .foregroundStyle(Color.formaLabel)
                .lineLimit(isCompactLayout ? 3 : 2)

            if let statusDetailText {
                Text(statusDetailText)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabelHigh)
                    .lineLimit(isCompactLayout ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let lastRun = automationState.lastRunDate {
                Text(lastRun.relativeFormatted)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabelHigh)
                    .lineLimit(1)
            }

            if let preflightDetailText {
                Text(preflightDetailText)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaTertiaryLabelHigh)
                    .lineLimit(isCompactLayout ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if activeScopeCount > 0 || attentionScopeCount > 0 {
                scopeSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var scopeSummary: some View {
        if isCompactLayout {
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                if activeScopeCount > 0 {
                    Text("\(activeScopeCount) autopilot scope\(activeScopeCount == 1 ? "" : "s")")
                        .font(.formaCaption)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                }

                if attentionScopeCount > 0 {
                    Text("\(attentionScopeCount) attention")
                        .font(.formaCaptionBold)
                        .foregroundStyle(Color.formaWarmOrange)
                }
            }
        } else {
            HStack(spacing: FormaSpacing.tight) {
                if activeScopeCount > 0 {
                    Text("\(activeScopeCount) autopilot scope\(activeScopeCount == 1 ? "" : "s")")
                        .font(.formaCaption)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                }

                if attentionScopeCount > 0 {
                    Text("\(attentionScopeCount) attention")
                        .font(.formaCaptionBold)
                        .foregroundStyle(Color.formaWarmOrange)
                }
            }
            .lineLimit(1)
        }
    }

    private var regularControlStrip: some View {
        HStack(spacing: 0) {
            if !isPaused && !automationState.isRunning {
                scanNowButtonInline
                    .transition(.scale.combined(with: .opacity))

                Rectangle()
                    .fill(FormaControlChromePalette.separator(colorScheme))
                    .frame(width: 1, height: FormaControlChromeMetrics.dividerHeight)
            }

            pauseResumeButtonInline
        }
        .background(
            RoundedRectangle(
                cornerRadius: FormaControlChromeMetrics.containerCornerRadius,
                style: .continuous
            )
                .fill(controlStripFill)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: FormaControlChromeMetrics.containerCornerRadius,
                style: .continuous
            )
                .strokeBorder(controlStripBorder, lineWidth: 1)
        )
    }

    private var compactControlStack: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            if !isPaused && !automationState.isRunning {
                compactActionButton(
                    title: "Scan now",
                    systemImage: "bolt.fill",
                    tint: Color.formaSteelBlue,
                    action: {
                        Task {
                            await engine.triggerManualScan()
                        }
                    }
                )
            }

            compactActionButton(
                title: isPaused ? "Resume automation" : "Pause automation",
                systemImage: isPaused ? "play.fill" : "pause.fill",
                tint: isPaused ? Color.formaSage : Color.formaSecondaryLabelHigh,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if isPaused {
                            engine.start()
                        } else {
                            engine.stop()
                        }
                    }
                }
            )
        }
    }

    private func compactActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.formaSmallSemibold)
                Spacer()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Countdown Ring

    /// Gradient colors for the countdown ring (Steel Blue → Sage blend)
    private var ringGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color.formaSteelBlue,
                Color.formaSteelBlue.blend(with: Color.formaSage, ratio: 0.3),
                Color.formaSage,
                Color.formaSage.blend(with: Color.formaSteelBlue, ratio: 0.3),
                Color.formaSteelBlue
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    @ViewBuilder
    private var countdownRing: some View {
        ZStack {
            // Background ring (subtle, muted version of gradient)
            Circle()
                .stroke(
                    Color.formaObsidian.opacity(Color.FormaOpacity.light),
                    lineWidth: 3
                )

            // Progress ring with gradient (depletes clockwise)
            Circle()
                .trim(from: 0, to: automationState.isRunning ? 1.0 : countdownProgress)
                .stroke(
                    isPaused ? AnyShapeStyle(Color.formaWarmOrange) : AnyShapeStyle(ringGradient),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.3),
                    value: countdownProgress
                )

            // Center content
            if automationState.isRunning {
                // Scanning indicator
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.formaSteelBlue)
            } else {
                // Countdown text - use dominant color from gradient
                Text(countdownText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isPaused ? Color.formaWarmOrange : Color.formaSteelBlue)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Status Properties

    private var statusColor: Color {
        if automationState.isRunning {
            return Color.formaSteelBlue
        } else if automationState.isWatchingFolders {
            return Color.formaSage
        } else if automationState.nextScheduledRun != nil {
            return Color.formaSage
        } else {
            return Color.formaWarmOrange
        }
    }

    private var statusLabel: String {
        if automationState.isRunning {
            return "Scanning"
        } else if automationState.isWatchingFolders {
            return "Watching"
        } else if automationState.nextScheduledRun != nil {
            return "Scheduled"
        } else {
            return "Paused"
        }
    }

    private var statusMessage: String {
        if let presentation {
            return presentation.headlineText
        }

        if automationState.isRunning {
            return "Scanning files..."
        } else if automationState.isWatchingFolders {
            return "Watching folders"
        } else if automationState.nextScheduledRun != nil {
            return "Next scan"
        } else {
            return "Automation paused"
        }
    }

    private var statusDetailText: String? {
        presentation?.latestMeaningfulRunSummary
    }

    private var preflightDetailText: String? {
        guard let presentation else { return nil }
        guard presentation.latestPreflightSummary != presentation.latestMeaningfulRunSummary else {
            return nil
        }
        return presentation.latestPreflightSummary
    }

    // MARK: - Action Buttons

    /// Scan Now button - triggers immediate scan
    @ViewBuilder
    private var scanNowButton: some View {
        Button {
            Task {
                await engine.triggerManualScan()
            }
        } label: {
            HStack(spacing: FormaSpacing.micro) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Scan")
                    .font(.formaSmallSemibold)
            }
            .foregroundStyle(Color.formaSteelBlue)
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.medium), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(automationState.isRunning)
        .opacity(automationState.isRunning ? 0.5 : 1.0)
        .help("Trigger an immediate scan")
    }

    /// Pause/Resume toggle - larger touch target
    @ViewBuilder
    private var pauseResumeButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isPaused {
                    engine.start()
                } else {
                    engine.stop()
                }
            }
        }) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isPaused ? Color.formaSage : Color.formaSecondaryLabelHigh)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            isPaused
                                ? Color.formaSage.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle)
                                : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 3)
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isPaused
                                ? Color.formaSage.opacity(Color.FormaOpacity.medium)
                                : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 4),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(isPaused ? "Resume automation" : "Pause automation")
    }

    // MARK: - Grouped Control Strip Styling

    private var controlStripFill: Color {
        FormaControlChromePalette.containerFill(colorScheme)
    }

    private var controlStripBorder: Color {
        FormaControlChromePalette.containerBorder(colorScheme)
    }

    /// Scan button for inline control strip (no individual background)
    @ViewBuilder
    private var scanNowButtonInline: some View {
        let isHovered = hoveredInlineControl == .scan

        Button {
            Task {
                await engine.triggerManualScan()
            }
        } label: {
            ZStack {
                if isHovered {
                    RoundedRectangle(
                        cornerRadius: FormaControlChromeMetrics.selectedCornerRadius,
                        style: .continuous
                    )
                    .fill(FormaControlChromePalette.hoverFill(colorScheme, tint: Color.formaSteelBlue))
                    .padding(.vertical, FormaControlChromeMetrics.shellInset)
                    .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                }

                HStack(spacing: FormaSpacing.micro) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Scan")
                        .font(.formaSmallSemibold)
                }
                .foregroundStyle(Color.formaSteelBlue)
                .padding(.horizontal, FormaSpacing.standard)
                .frame(height: FormaControlChromeMetrics.segmentHeight)
            }
            .frame(height: FormaControlChromeMetrics.segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(FormaControlPressButtonStyle())
        .disabled(automationState.isRunning)
        .opacity(automationState.isRunning ? 0.5 : 1.0)
        .help("Trigger an immediate scan")
        .onHover { hovering in
            if hovering {
                hoveredInlineControl = .scan
            } else if hoveredInlineControl == .scan {
                hoveredInlineControl = nil
            }
        }
    }

    /// Pause/Resume button for inline control strip (no individual background)
    @ViewBuilder
    private var pauseResumeButtonInline: some View {
        let isSelected = isPaused
        let isHovered = hoveredInlineControl == .pauseResume

        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isPaused {
                    engine.start()
                } else {
                    engine.stop()
                }
            }
        }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius: FormaControlChromeMetrics.selectedCornerRadius,
                        style: .continuous
                    )
                    .fill(FormaControlChromePalette.activeFill(colorScheme, tint: Color.formaSage))
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: FormaControlChromeMetrics.selectedCornerRadius,
                            style: .continuous
                        )
                        .stroke(FormaControlChromePalette.activeBorder(colorScheme), lineWidth: 0.5)
                    )
                    .shadow(
                        color: FormaControlChromePalette.activeShadow(colorScheme),
                        radius: 1.5,
                        x: 0,
                        y: 0.5
                    )
                    .padding(.vertical, FormaControlChromeMetrics.shellInset)
                    .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                } else if isHovered {
                    RoundedRectangle(
                        cornerRadius: FormaControlChromeMetrics.selectedCornerRadius,
                        style: .continuous
                    )
                    .fill(FormaControlChromePalette.hoverFill(colorScheme, tint: Color.formaSage))
                    .padding(.vertical, FormaControlChromeMetrics.shellInset)
                    .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                }

                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? Color.formaSage
                            : FormaControlChromePalette.normalForeground(colorScheme)
                    )
                    .frame(width: 32, height: FormaControlChromeMetrics.segmentHeight)
            }
            .frame(width: 32, height: FormaControlChromeMetrics.segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(FormaControlPressButtonStyle())
        .help(isPaused ? "Resume automation" : "Pause automation")
        .onHover { hovering in
            if hovering {
                hoveredInlineControl = .pauseResume
            } else if hoveredInlineControl == .pauseResume {
                hoveredInlineControl = nil
            }
        }
    }

    // MARK: - Last Run Stats (Always Visible)

    @ViewBuilder
    private var lastRunStats: some View {
        Group {
            if isCompactLayout {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    statsContent
                }
            } else {
                HStack(spacing: FormaSpacing.standard) {
                    statsContent
                    Spacer()
                }
            }
        }
        .padding(.top, FormaSpacing.tight)
    }

    @ViewBuilder
    private var statsContent: some View {
        if automationState.lastRunSuccessCount > 0 {
            StatPill(
                value: automationState.lastRunSuccessCount,
                label: "organized",
                color: Color.formaSage
            )
        }

        if automationState.lastRunSkippedCount > 0 {
            StatPill(
                value: automationState.lastRunSkippedCount,
                label: "skipped",
                color: Color.formaSecondaryLabel
            )
        }

        if automationState.lastRunFailedCount > 0 {
            StatPill(
                value: automationState.lastRunFailedCount,
                label: "failed",
                color: Color.formaError
            )
        }

        if automationState.lastRunSuccessCount == 0 &&
           automationState.lastRunSkippedCount == 0 &&
           automationState.lastRunFailedCount == 0 {
            Text(lastRunContextMessage)
                .font(.formaCaption)
                .foregroundStyle(Color.formaTertiaryLabelHigh)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var lastRunContextMessage: String {
        if pendingReviewCount > 0 {
            return "\(pendingReviewCount) pending for review"
        }
        return "No files to organize"
    }
}

// MARK: - Stat Pill Component

private struct StatPill: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.formaBodyBold)
                .foregroundStyle(color)
            Text(label)
                .font(.formaCaption)
                .foregroundStyle(Color.formaSecondaryLabelHigh)
        }
    }
}

// MARK: - Date Extension

private extension Date {
    /// Relative formatted string for recent dates
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview("Active") {
    AutomationStatusWidget()
        .frame(width: 320)
        .padding()
        .background(.regularMaterial)
}
