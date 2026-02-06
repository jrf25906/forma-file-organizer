import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Welcome Animation Phase

/// State machine for the welcome screen animation choreography.
/// Transitions: idle -> scattered -> converging -> landed -> heroReveal
private enum WelcomePhase: Equatable {
    case idle       // Before onAppear
    case scattered  // Files visible and floating
    case converging // Files arcing toward folder
    case landed     // Folder pulse on impact
    case heroReveal // Text and CTA appearing
}

// MARK: - Scattered File Model

/// Represents a file icon scattered around the animation stage.
/// Each file has a depth value for parallax and a control point offset for arc convergence.
private struct ScatteredFile: Identifiable {
    let id = UUID()
    let fileExtension: String
    let label: String
    let startX: CGFloat
    let startY: CGFloat
    let rotation: Double
    let delay: Double
    let iconSize: CGFloat
    let depth: CGFloat             // 0.8-1.0; deeper files are smaller + blurred
    let controlPointOffset: CGFloat // 30-60pt for bezier arc curvature
    let floatPhaseOffset: Double   // Unique phase for ambient float
}

// MARK: - Scattered File Data

/// Pre-defined scattered files with positions spread across a 400x320 stage.
/// Each file has unique depth, control point offset, and float phase for visual variety.
private let scatteredFiles: [ScatteredFile] = [
    ScatteredFile(fileExtension: "pdf",  label: "Report_Q4.pdf",     startX: -150, startY: -110, rotation: -12,  delay: 0.00, iconSize: 40, depth: 1.0,  controlPointOffset: 45, floatPhaseOffset: 0.0),
    ScatteredFile(fileExtension: "docx", label: "Meeting_Notes.docx", startX:  160, startY:  -80, rotation:  8,  delay: 0.05, iconSize: 38, depth: 0.92, controlPointOffset: 35, floatPhaseOffset: 1.8),
    ScatteredFile(fileExtension: "jpg",  label: "Vacation.jpg",       startX: -120, startY:  100, rotation:  15, delay: 0.10, iconSize: 42, depth: 0.95, controlPointOffset: 55, floatPhaseOffset: 3.2),
    ScatteredFile(fileExtension: "zip",  label: "Archive_2024.zip",   startX:  140, startY:  120, rotation: -18, delay: 0.15, iconSize: 36, depth: 0.85, controlPointOffset: 40, floatPhaseOffset: 0.9),
    ScatteredFile(fileExtension: "xlsx", label: "Budget.xlsx",        startX:  -60, startY: -140, rotation:  10, delay: 0.08, iconSize: 40, depth: 0.98, controlPointOffset: 50, floatPhaseOffset: 2.5),
    ScatteredFile(fileExtension: "mp3",  label: "Podcast_Ep12.mp3",   startX:   90, startY: -130, rotation: -6,  delay: 0.12, iconSize: 38, depth: 0.88, controlPointOffset: 38, floatPhaseOffset: 4.1),
    ScatteredFile(fileExtension: "pptx", label: "Pitch_Deck.pptx",   startX: -170, startY:   20, rotation:  20, delay: 0.03, iconSize: 44, depth: 1.0,  controlPointOffset: 60, floatPhaseOffset: 1.3),
    ScatteredFile(fileExtension: "txt",  label: "todo.txt",           startX:  170, startY:   30, rotation: -14, delay: 0.18, iconSize: 36, depth: 0.82, controlPointOffset: 32, floatPhaseOffset: 5.0),
    ScatteredFile(fileExtension: "mov",  label: "Demo_Video.mov",     startX:  -40, startY:  130, rotation:   5, delay: 0.07, iconSize: 42, depth: 0.96, controlPointOffset: 48, floatPhaseOffset: 2.0),
    ScatteredFile(fileExtension: "csv",  label: "Contacts.csv",       startX:   50, startY:  110, rotation: -10, delay: 0.14, iconSize: 38, depth: 0.90, controlPointOffset: 42, floatPhaseOffset: 3.7),
    ScatteredFile(fileExtension: "png",  label: "Screenshot.png",     startX: -160, startY:  -40, rotation:  16, delay: 0.06, iconSize: 40, depth: 0.93, controlPointOffset: 52, floatPhaseOffset: 0.5),
    ScatteredFile(fileExtension: "key",  label: "Keynote_Talk.key",   startX:  130, startY:  -20, rotation: -8,  delay: 0.11, iconSize: 44, depth: 0.87, controlPointOffset: 36, floatPhaseOffset: 4.6),
]

// MARK: - Scattered File Icon View

/// Individual file icon with macOS system icon, label, depth effects, and animated position.
/// During the converging phase, position is driven by ArcConvergence bezier interpolation.
private struct ScatteredFileIcon: View {
    let file: ScatteredFile
    let phase: WelcomePhase
    let convergenceProgress: CGFloat // 0...1 during converging phase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let icon = NSWorkspace.shared.icon(
            for: UTType(filenameExtension: file.fileExtension) ?? .data
        )

        let depthScale = file.depth
        let isDeep = file.depth < 0.9

        VStack(spacing: 2) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: file.iconSize * depthScale, height: file.iconSize * depthScale)

            Text(file.label)
                .font(.formaMicro)
                .foregroundColor(.formaSecondaryLabel)
                .lineLimit(1)
        }
        .blur(radius: isDeep ? 0.8 : 0)
        .opacity(iconOpacity)
        .scaleEffect(iconScale)
        .rotationEffect(.degrees(iconRotation))
        .offset(x: iconOffsetX, y: iconOffsetY)
    }

    // MARK: - Computed Animation Properties

    private var iconOpacity: Double {
        switch phase {
        case .idle:
            return 0
        case .scattered:
            return 1
        case .converging:
            // Fade out as files approach center
            return max(0, 1.0 - Double(convergenceProgress) * 1.2)
        case .landed, .heroReveal:
            return 0
        }
    }

    private var iconScale: CGFloat {
        switch phase {
        case .idle:
            return 0.5
        case .scattered:
            return 1.0
        case .converging:
            return max(0.3, 1.0 - convergenceProgress * 0.7)
        case .landed, .heroReveal:
            return 0.3
        }
    }

    private var iconRotation: Double {
        switch phase {
        case .idle:
            return file.rotation
        case .scattered:
            return file.rotation
        case .converging:
            return file.rotation * Double(1.0 - convergenceProgress)
        case .landed, .heroReveal:
            return 0
        }
    }

    private var iconOffsetX: CGFloat {
        switch phase {
        case .idle:
            return file.startX
        case .scattered:
            return file.startX
        case .converging:
            let arc = ArcConvergence(
                startX: file.startX,
                startY: file.startY,
                startRotation: file.rotation,
                controlPointOffset: file.controlPointOffset
            )
            let pos = arc.position(at: Double(convergenceProgress))
            return pos.x
        case .landed, .heroReveal:
            return 0
        }
    }

    private var iconOffsetY: CGFloat {
        switch phase {
        case .idle:
            return file.startY
        case .scattered:
            return file.startY
        case .converging:
            let arc = ArcConvergence(
                startX: file.startX,
                startY: file.startY,
                startRotation: file.rotation,
                controlPointOffset: file.controlPointOffset
            )
            let pos = arc.position(at: Double(convergenceProgress))
            return pos.y
        case .landed, .heroReveal:
            return 0
        }
    }
}

// MARK: - Welcome Step View

/// First step: Welcome screen with files-into-folder animation and display typography.
/// Uses a phased animation sequence driven by async/await instead of DispatchQueue chains.
struct WelcomeStepView: View {
    let onContinue: () -> Void

    // MARK: - Animation State

    @State private var phase: WelcomePhase = .idle
    @State private var convergenceProgress: CGFloat = 0
    @State private var folderVisible = false
    @State private var folderPulsing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animation stage (400x320)
            ZStack {
                // Living mesh gradient background
                AnimatedMeshBackground()
                    .frame(width: 400, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous))

                // Premium folder (SF Symbol with glow)
                PremiumFolderView(isPulsing: folderPulsing, size: 72, color: .formaSteelBlue)
                    .opacity(folderVisible ? 1 : 0)
                    .scaleEffect(folderVisible ? 1.0 : 0.6)

                // Scattered file icons with per-file ambient float
                ForEach(scatteredFiles) { file in
                    fileIconView(for: file)
                }
            }
            .frame(width: 400, height: 320)

            // Hero text section with progressive reveal
            VStack(spacing: FormaSpacing.tight) {
                Text("Your files, finally organized.")
                    .font(.formaDisplayHero)
                    .foregroundColor(.formaLabel)
                    .progressiveReveal(isVisible: phase == .heroReveal, index: 0, baseDelay: 0.12, offsetY: 16)

                Text("Forma learns how you work and keeps your folders tidy \u{2014} automatically.")
                    .font(.formaBodyLarge)
                    .foregroundColor(.formaSecondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FormaSpacing.extraLarge)
                    .progressiveReveal(isVisible: phase == .heroReveal, index: 1, baseDelay: 0.12, offsetY: 16)
            }

            Spacer()

            // CTA button with shimmer
            WelcomeCTAButton(action: onContinue)
                .padding(.horizontal, FormaSpacing.huge)
                .padding(.bottom, FormaSpacing.large)
                .progressiveReveal(isVisible: phase == .heroReveal, index: 2, baseDelay: 0.12, offsetY: 12)
                .gradientShimmerSweep(trigger: phase == .heroReveal, delay: 0.5)
        }
        .onAppear {
            if reduceMotion {
                skipToFinalState()
            } else {
                startAnimationSequence()
            }
        }
    }

    // MARK: - File Icon with Ambient Float

    @ViewBuilder
    private func fileIconView(for file: ScatteredFile) -> some View {
        let shouldFloat = phase == .scattered

        ScatteredFileIcon(
            file: file,
            phase: phase,
            convergenceProgress: convergenceProgress
        )
        .ambientFloat(
            xAmplitude: shouldFloat ? 3 : 0,
            yAmplitude: shouldFloat ? 4 : 0,
            duration: 3.0,
            phaseOffset: file.floatPhaseOffset
        )
    }

    // MARK: - Reduce Motion: Skip to Final State

    private func skipToFinalState() {
        folderVisible = true
        folderPulsing = false
        convergenceProgress = 1.0
        phase = .heroReveal
    }

    // MARK: - Animation Sequence (async/await)

    private func startAnimationSequence() {
        Task { @MainActor in
            // Phase 1 (0s): Files scatter in + folder scale-up
            withAnimation(FormaAnimation.onboardingEntrance) {
                phase = .scattered
                folderVisible = true
            }

            // Phase 2 (0-1.2s): Files float with ambient float (handled by ambientFloat modifier)
            // Wait for floating phase
            try? await Task.sleep(for: .milliseconds(1200))

            // Phase 3 (1.2s): Begin arc convergence
            phase = .converging

            // Animate convergence progress from 0 to 1 over 0.8s
            // Use a timer-driven approach for smooth bezier interpolation
            let convergenceDuration: Double = 0.8
            let steps = 60 // ~60fps
            let stepDuration = convergenceDuration / Double(steps)

            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(Int(stepDuration * 1000)))
                let t = CGFloat(step) / CGFloat(steps)
                // Ease-in-out curve for smoother motion
                let eased = t < 0.5
                    ? 2 * t * t
                    : 1 - pow(-2 * t + 2, 2) / 2
                convergenceProgress = eased
            }

            // Phase 4 (2.0s): Files have landed, folder bounce pulse
            withAnimation(FormaAnimation.onboardingBounce) {
                phase = .landed
                folderPulsing = true
            }

            try? await Task.sleep(for: .milliseconds(400))

            withAnimation(FormaAnimation.onboardingSettle) {
                folderPulsing = false
            }

            // Phase 5 (2.4s): Hero text springs in with progressive reveal
            try? await Task.sleep(for: .milliseconds(100))

            withAnimation(FormaAnimation.onboardingEntrance) {
                phase = .heroReveal
            }
        }
    }
}

// MARK: - Welcome CTA Button

struct WelcomeCTAButton: View {
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("Get Started")
                    .font(.formaBodyLarge)
                    .fontWeight(.semibold)

                // Animated arrow
                Image(systemName: "arrow.right")
                    .font(.formaBodySemibold)
                    .offset(x: isHovered ? 4 : 0)
            }
            .foregroundColor(.formaBoneWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FormaSpacing.standard)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: FormaRadius.large - (FormaRadius.micro / 2), style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.formaSteelBlue, Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Subtle shine on hover
                    if isHovered {
                        RoundedRectangle(cornerRadius: FormaRadius.large - (FormaRadius.micro / 2), style: .continuous)
                            .fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.light))
                    }
                }
            )
            .shadow(
                color: Color.formaSteelBlue.opacity(isHovered ? Color.FormaOpacity.overlay : Color.FormaOpacity.medium),
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 6 : 4
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
        }
    }
}

// MARK: - Press Events Modifier

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - Previews

#Preview("Welcome Step") {
    WelcomeStepView(onContinue: {})
        .frame(width: 650, height: 720)
        .background(Color.formaBackground)
}

#Preview("Welcome Step - Static") {
    // To test reduce motion: enable in System Settings > Accessibility > Display
    WelcomeStepView(onContinue: {})
        .frame(width: 650, height: 720)
        .background(Color.formaBackground)
}
