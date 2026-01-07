import SwiftUI

/// Compact widget displaying automation status in the right panel.
///
/// Shows:
/// - Current status (scanning, next scan time, or paused)
/// - Quick pause/resume toggle
/// - Last run stats when available
///
/// Designed to fit within DefaultPanelView's scrolling content area.
struct AutomationStatusWidget: View {
    @ObservedObject private var engine = AutomationEngine.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false
    @State private var isPulsing: Bool = false

    /// Whether the automation is paused (neither running nor scheduled)
    private var isPaused: Bool {
        engine.state.nextScheduledRun == nil && !engine.state.isRunning
    }

    /// Whether the widget should show the "alive" pulse
    private var shouldPulse: Bool {
        !reduceMotion && (engine.state.isRunning || engine.state.nextScheduledRun != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Section Header
            HStack {
                Text("AUTOMATION")
                    .font(.formaBodySemibold)
                    .tracking(0.5)
                    .foregroundStyle(Color.formaSecondaryLabel)

                Spacer()

                // Status indicator dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(Color.FormaOpacity.strong), radius: 2)
            }

            // Main status card
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                // Status message + actions
                HStack(alignment: .center, spacing: FormaSpacing.standard) {
                    // Status icon with pulse
                    statusIcon
                        .frame(width: 32, height: 32)

                    // Status text
                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.state.statusMessage)
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

                // Expanded stats (when tapped)
                if isExpanded && engine.state.lastRunDate != nil {
                    Divider()
                        .foregroundColor(Color.formaSeparator.opacity(Color.FormaOpacity.strong))
                        .padding(.vertical, FormaSpacing.tight)

                    lastRunStats
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
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            // Pulse ring (only when automation is active)
            if shouldPulse {
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)
            }

            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .fill(statusColor.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle))

            if engine.state.isRunning {
                // Animated scanning indicator
                ProgressView()
                    .controlSize(.small)
                    .tint(statusColor)
            } else {
                Image(systemName: statusIconName)
                    .font(.formaBodyMedium)
                    .foregroundStyle(statusColor)
            }
        }
        .onAppear {
            isPulsing = shouldPulse
        }
        .onChange(of: shouldPulse) { _, newValue in
            isPulsing = newValue
        }
        .animation(
            shouldPulse
                ? .easeInOut(duration: 1.8).repeatForever(autoreverses: false)
                : .default,
            value: isPulsing
        )
    }

    private var statusIconName: String {
        if engine.state.nextScheduledRun != nil {
            return "clock.arrow.circlepath"
        } else {
            return "pause.circle"
        }
    }

    private var statusColor: Color {
        if engine.state.isRunning {
            return Color.formaSteelBlue
        } else if engine.state.nextScheduledRun != nil {
            return Color.formaSage
        } else {
            return Color.formaWarmOrange
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
                Text("Scan Now")
                    .font(.formaSmallSemibold)
            }
            .foregroundStyle(Color.formaSteelBlue)
            .padding(.horizontal, FormaSpacing.tight)
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
                .frame(width: 40, height: 40)
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

    // MARK: - Last Run Stats

    @ViewBuilder
    private var lastRunStats: some View {
        HStack(spacing: FormaSpacing.large) {
            // Organized count
            StatPill(
                value: engine.state.lastRunSuccessCount,
                label: "organized",
                color: Color.formaSage
            )

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

            Spacer()
        }
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
