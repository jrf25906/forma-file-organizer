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
    @ObservedObject private var engine = AutomationEngine.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false
    @State private var currentTime: Date = Date()

    /// Timer to update countdown display
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Whether the automation is paused (neither running nor scheduled)
    private var isPaused: Bool {
        engine.state.nextScheduledRun == nil && !engine.state.isRunning
    }

    /// Calculate countdown progress (1.0 = full, depletes to 0.0)
    private var countdownProgress: Double {
        guard let nextRun = engine.state.nextScheduledRun,
              let lastRun = engine.state.lastRunDate else {
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
        guard let nextRun = engine.state.nextScheduledRun else {
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

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Section Header with status label
            HStack {
                Text("AUTOMATION")
                    .font(.formaBodySemibold)
                    .tracking(0.5)
                    .foregroundStyle(Color.formaSecondaryLabel)

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
                // Top row: Countdown ring + status + actions
                HStack(alignment: .center, spacing: FormaSpacing.standard) {
                    // Countdown ring
                    countdownRing
                        .frame(width: 52, height: 52)

                    // Status text
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusMessage)
                            .font(.formaBodyMedium)
                            .foregroundStyle(Color.formaLabel)

                        if let lastRun = engine.state.lastRunDate {
                            Text("Last run \(lastRun.relativeFormatted)")
                                .font(.formaCaption)
                                .foregroundStyle(Color.formaSecondaryLabel)
                        }
                    }

                    Spacer()

                    // Scan Now button (hidden when running or paused)
                    if !isPaused && !engine.state.isRunning {
                        scanNowButton
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Pause/Resume toggle
                    pauseResumeButton
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPaused)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: engine.state.isRunning)

                // Last run stats (always visible when available)
                if engine.state.lastRunDate != nil && !engine.state.isRunning {
                    lastRunStats
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(
                        isHovered
                            ? Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 2)
                            : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        Color.formaObsidian.opacity(
                            isHovered
                                ? Color.FormaOpacity.light
                                : (Color.FormaOpacity.ultraSubtle * 3)
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
        .onReceive(timer) { time in
            currentTime = time
        }
    }

    // MARK: - Countdown Ring

    @ViewBuilder
    private var countdownRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    statusColor.opacity(Color.FormaOpacity.light),
                    lineWidth: 4
                )

            // Progress ring (depletes clockwise)
            Circle()
                .trim(from: 0, to: engine.state.isRunning ? 1.0 : countdownProgress)
                .stroke(
                    statusColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.3),
                    value: countdownProgress
                )

            // Center content
            if engine.state.isRunning {
                // Scanning indicator
                ProgressView()
                    .controlSize(.small)
                    .tint(statusColor)
            } else {
                // Countdown text
                Text(countdownText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Status Properties

    private var statusColor: Color {
        if engine.state.isRunning {
            return Color.formaSteelBlue
        } else if engine.state.nextScheduledRun != nil {
            return Color.formaSage
        } else {
            return Color.formaWarmOrange
        }
    }

    private var statusLabel: String {
        if engine.state.isRunning {
            return "Scanning"
        } else if engine.state.nextScheduledRun != nil {
            return "Active"
        } else {
            return "Paused"
        }
    }

    private var statusMessage: String {
        if engine.state.isRunning {
            return "Scanning files..."
        } else if engine.state.nextScheduledRun != nil {
            return "Next scan"
        } else {
            return "Automation paused"
        }
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
            .fixedSize()
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
        .disabled(engine.state.isRunning)
        .opacity(engine.state.isRunning ? 0.5 : 1.0)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isPaused ? Color.formaSage : Color.formaSecondaryLabel)
                .frame(width: 36, height: 36)
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

    // MARK: - Last Run Stats (Always Visible)

    @ViewBuilder
    private var lastRunStats: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Organized count
            if engine.state.lastRunSuccessCount > 0 {
                StatPill(
                    value: engine.state.lastRunSuccessCount,
                    label: "organized",
                    color: Color.formaSage
                )
            }

            // Skipped count (if any)
            if engine.state.lastRunSkippedCount > 0 {
                StatPill(
                    value: engine.state.lastRunSkippedCount,
                    label: "skipped",
                    color: Color.formaSecondaryLabel
                )
            }

            // Failed count (if any)
            if engine.state.lastRunFailedCount > 0 {
                StatPill(
                    value: engine.state.lastRunFailedCount,
                    label: "failed",
                    color: Color.formaError
                )
            }

            // Show "No changes" if nothing happened
            if engine.state.lastRunSuccessCount == 0 &&
               engine.state.lastRunSkippedCount == 0 &&
               engine.state.lastRunFailedCount == 0 {
                Text("No files to organize")
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaTertiaryLabel)
            }

            Spacer()
        }
        .padding(.top, FormaSpacing.tight)
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
                .foregroundStyle(Color.formaSecondaryLabel)
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
