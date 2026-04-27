import SwiftUI

/// Editorial automation beacon displayed in the right panel.
///
/// Shows:
/// - A live/paused status chip with schedule timing tucked into hover help
/// - One concise automation summary block
/// - Compact trust metrics
/// - A full-width split control for scan and pause/resume
struct AutomationStatusWidget: View {
    let pendingReviewCount: Int
    let activeScopeCount: Int
    let attentionScopeCount: Int
    let presentation: DashboardAutomationStatusPresentation?

    private let engine = AutomationEngine.shared
    private let automationState = AutomationEngine.shared.state
    private let isUITesting = CommandLine.arguments.contains("--uitesting")

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var hoveredControl: HoveredControl?

    private enum HoveredControl {
        case scan
        case pauseResume
    }

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

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(alignment: .firstTextBaseline, spacing: FormaSpacing.tight) {
                Text("AUTOMATION")
                    .font(.formaCaptionSemibold)
                    .tracking(0.8)
                    .foregroundStyle(Color.formaTertiaryLabelHigh)
                    .accessibilityIdentifier("defaultPanelAutomationTitle")

                Spacer()
            }

            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                HStack {
                    Spacer()
                    AutomationStatusBadge()
                }

                summarySection

                splitControl
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, 14)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(
                color: Color.formaObsidian.opacity(colorScheme == .dark ? 0.18 : 0.055),
                radius: 7,
                x: 0,
                y: 2
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("defaultPanelAutomationStatusCard")
        .accessibilityLabel(isUITesting ? "title=attached" : "")
        .accessibilityValue(isUITesting ? "title=attached" : "")
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .fill(Color.formaSurfaceWork.opacity(colorScheme == .dark ? 0.72 : 0.90))
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.10 : 0.055),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(
                        isHovered
                            ? Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.08 : 0.035)
                            : Color.clear
                    )
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .strokeBorder(
                Color.formaObsidian.opacity(colorScheme == .dark ? 0.24 : 0.085),
                lineWidth: 1
            )
    }

    private var isPaused: Bool {
        automationState.nextScheduledRun == nil && !automationState.isRunning
    }

    private var isLive: Bool {
        automationState.isWatchingFolders || automationState.nextScheduledRun != nil
    }

    private var headlineText: String {
        if let presentation {
            return presentation.headlineText
        }

        if automationState.isRunning {
            return "Automation is scanning now"
        }

        if isLive {
            return "Automation is watching your folders"
        }

        return "Automation is paused"
    }

    private var primaryStateText: String {
        if pendingReviewCount > 0 {
            return "\(pendingReviewCount) \(pendingReviewCount == 1 ? "file" : "files") waiting for review"
        }

        if let meaningfulRunSummary = presentation?.latestMeaningfulRunSummary {
            return meaningfulRunSummary
        }

        if let preflightSummary = presentation?.latestPreflightSummary {
            return preflightSummary
        }

        if isPaused {
            return "No automatic pass is scheduled right now"
        }

        return "Automation is ready for the next pass"
    }

    private var secondaryStateText: String? {
        var fragments: [String] = []

        if activeScopeCount > 0 {
            fragments.append("\(activeScopeCount) folder\(activeScopeCount == 1 ? "" : "s") on autopilot")
        }

        if attentionScopeCount > 0 {
            fragments.append("\(attentionScopeCount) folder\(attentionScopeCount == 1 ? "" : "s") blocked")
        }

        guard !fragments.isEmpty else { return nil }
        return fragments.joined(separator: " · ")
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headlineText)
                .font(.formaSmallSemibold)
                .foregroundStyle(Color.formaLabel)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("defaultPanelAutomationHeadline")

            Text(primaryStateText)
                .font(.formaBodySemibold)
                .foregroundStyle(Color.formaSecondaryLabelHigh)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("defaultPanelAutomationPrimaryState")

            if let secondaryStateText {
                Text(secondaryStateText)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaTertiaryLabelHigh)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("defaultPanelAutomationSecondaryState")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var splitControl: some View {
        HStack(spacing: 0) {
            splitSegment(
                title: "Scan now",
                systemImage: "bolt.fill",
                hoverState: .scan,
                action: triggerManualScan,
                fill: RightRailSemanticTone.progress.color.opacity(colorScheme == .dark ? 0.10 : 0.05),
                foreground: RightRailSemanticTone.progress.color,
                isCompact: false
            )
            .disabled(automationState.isRunning)
            .opacity(automationState.isRunning ? 0.55 : 1.0)
            .accessibilityIdentifier("defaultPanelAutomationScanButton")
            .help(automationState.isRunning ? "Automation is already scanning." : "Trigger an immediate scan.")

            Rectangle()
                .fill(Color.formaObsidian.opacity(colorScheme == .dark ? 0.16 : 0.10))
                .frame(width: 1)

            splitSegment(
                title: isPaused ? "Resume automation" : "Pause automation",
                systemImage: isPaused ? "play.fill" : "pause.fill",
                hoverState: .pauseResume,
                action: toggleAutomationState,
                fill: isPaused
                    ? RightRailSemanticTone.live.color.opacity(colorScheme == .dark ? 0.10 : 0.05)
                    : Color.formaObsidian.opacity(colorScheme == .dark ? 0.10 : 0.03),
                foreground: isPaused
                    ? RightRailSemanticTone.live.color
                    : Color.formaSecondaryLabelHigh,
                isCompact: true
            )
            .frame(width: 58)
            .accessibilityIdentifier("defaultPanelAutomationPauseResumeButton")
            .help(isPaused ? "Resume automation" : "Pause automation")
        }
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaObsidian.opacity(colorScheme == .dark ? 0.16 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaObsidian.opacity(colorScheme == .dark ? 0.20 : 0.095), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
    }

    private func splitSegment(
        title: String,
        systemImage: String,
        hoverState: HoveredControl,
        action: @escaping () -> Void,
        fill: Color,
        foreground: Color,
        isCompact: Bool
    ) -> some View {
        Button(action: action) {
            ZStack {
                fill

                if hoveredControl == hoverState {
                    Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.08 : 0.14)
                }

                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))

                    if !isCompact {
                        Text(title)
                            .font(.formaCaptionSemibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                    }
                }
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                hoveredControl = hoverState
            } else if hoveredControl == hoverState {
                hoveredControl = nil
            }
        }
    }

    private func triggerManualScan() {
        Task {
            await engine.triggerManualScan()
        }
    }

    private func toggleAutomationState() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if isPaused {
                engine.start()
            } else {
                engine.stop()
            }
        }
    }
}

struct AutomationStatusBadge: View {
    private let automationState = AutomationEngine.shared.state

    @Environment(\.colorScheme) private var colorScheme

    private var descriptor: AutomationStatusDescriptor {
        AutomationStatusDescriptor(state: automationState)
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(descriptor.color)
                .frame(width: 8, height: 8)
                .shadow(color: descriptor.color.opacity(Color.FormaOpacity.strong), radius: 2)

            Text(descriptor.label)
                .font(.formaCaptionSemibold)
        }
        .foregroundStyle(descriptor.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(descriptor.color.opacity(colorScheme == .dark ? 0.12 : 0.08))
        )
        .overlay(
            Capsule()
                .strokeBorder(descriptor.color.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
        )
        .help(descriptor.helpText)
        .accessibilityIdentifier("defaultPanelAutomationStatusChip")
    }
}

struct AutomationStatusDescriptor {
    let color: Color
    let label: String
    let helpText: String

    init(state: AutomationState) {
        if state.isRunning {
            color = RightRailSemanticTone.progress.color
            label = "Scanning"
            helpText = "Automation is scanning right now."
            return
        }

        if state.nextScheduledRun == nil, !state.isRunning {
            color = RightRailSemanticTone.blocked.color
            label = "Paused"
            helpText = "Automation is paused."
            return
        }

        color = RightRailSemanticTone.live.color
        label = "Live"

        if let nextRun = state.nextScheduledRun {
            helpText = "Next automatic pass \(nextRun.relativeFormatted)."
        } else if state.isWatchingFolders {
            helpText = "Automation is watching the selected folders for new activity."
        } else {
            helpText = "Automation is live."
        }
    }
}

private extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview("Automation Beacon") {
    AutomationStatusWidget(
        pendingReviewCount: 66,
        activeScopeCount: 3,
        attentionScopeCount: 1
    )
    .frame(width: 320)
    .padding()
    .background(.regularMaterial)
}
