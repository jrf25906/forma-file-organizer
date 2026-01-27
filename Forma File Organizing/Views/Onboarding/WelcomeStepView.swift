import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Scattered File Model

/// Represents a file icon scattered around the animation stage
private struct ScatteredFile: Identifiable {
    let id = UUID()
    let fileExtension: String
    let label: String
    let startX: CGFloat
    let startY: CGFloat
    let rotation: Double
    let delay: Double
    let iconSize: CGFloat
}

// MARK: - Scattered File Data

/// Pre-defined scattered files with realistic names and positions spread across a 400x320 stage
private let scatteredFiles: [ScatteredFile] = [
    ScatteredFile(fileExtension: "pdf",  label: "Report_Q4.pdf",     startX: -150, startY: -110, rotation: -12,  delay: 0.00, iconSize: 40),
    ScatteredFile(fileExtension: "docx", label: "Meeting_Notes.docx", startX:  160, startY:  -80, rotation:  8,  delay: 0.05, iconSize: 38),
    ScatteredFile(fileExtension: "jpg",  label: "Vacation.jpg",       startX: -120, startY:  100, rotation:  15, delay: 0.10, iconSize: 42),
    ScatteredFile(fileExtension: "zip",  label: "Archive_2024.zip",   startX:  140, startY:  120, rotation: -18, delay: 0.15, iconSize: 36),
    ScatteredFile(fileExtension: "xlsx", label: "Budget.xlsx",        startX:  -60, startY: -140, rotation:  10, delay: 0.08, iconSize: 40),
    ScatteredFile(fileExtension: "mp3",  label: "Podcast_Ep12.mp3",   startX:   90, startY: -130, rotation: -6,  delay: 0.12, iconSize: 38),
    ScatteredFile(fileExtension: "pptx", label: "Pitch_Deck.pptx",   startX: -170, startY:   20, rotation:  20, delay: 0.03, iconSize: 44),
    ScatteredFile(fileExtension: "txt",  label: "todo.txt",           startX:  170, startY:   30, rotation: -14, delay: 0.18, iconSize: 36),
    ScatteredFile(fileExtension: "mov",  label: "Demo_Video.mov",     startX:  -40, startY:  130, rotation:   5, delay: 0.07, iconSize: 42),
    ScatteredFile(fileExtension: "csv",  label: "Contacts.csv",       startX:   50, startY:  110, rotation: -10, delay: 0.14, iconSize: 38),
    ScatteredFile(fileExtension: "png",  label: "Screenshot.png",     startX: -160, startY:  -40, rotation:  16, delay: 0.06, iconSize: 40),
    ScatteredFile(fileExtension: "key",  label: "Keynote_Talk.key",   startX:  130, startY:  -20, rotation: -8,  delay: 0.11, iconSize: 44),
]

// MARK: - Central Folder View

/// CSS-style folder icon rendered in Forma's steel blue
private struct CentralFolderView: View {
    let isPulsing: Bool

    var body: some View {
        ZStack {
            // Folder tab
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.formaSteelBlue)
                .frame(width: 38, height: 18)
                .offset(x: -21, y: -28)

            // Folder back
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.formaSteelBlue)
                .frame(width: 80, height: 56)

            // Folder front (slightly lighter)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.formaSteelBlue.opacity(0.75))
                .frame(width: 80, height: 48)
                .offset(y: 4)
        }
        .scaleEffect(isPulsing ? 1.08 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isPulsing)
    }
}

// MARK: - Scattered File Icon View

/// Individual file icon with macOS system icon, label, and animated position
private struct ScatteredFileIcon: View {
    let file: ScatteredFile
    let filesVisible: Bool
    let filesConverged: Bool
    let driftOffset: CGFloat

    var body: some View {
        let icon = NSWorkspace.shared.icon(
            for: UTType(filenameExtension: file.fileExtension) ?? .data
        )

        VStack(spacing: 2) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: file.iconSize, height: file.iconSize)

            Text(file.label)
                .font(.formaMicro)
                .foregroundColor(.formaSecondaryLabel)
                .lineLimit(1)
        }
        .opacity(iconOpacity)
        .scaleEffect(iconScale)
        .rotationEffect(.degrees(iconRotation))
        .offset(x: iconOffsetX, y: iconOffsetY)
        .animation(
            filesConverged
                ? .easeInOut(duration: 0.8).delay(file.delay)
                : .spring(response: 0.6, dampingFraction: 0.7),
            value: filesVisible
        )
        .animation(
            .easeInOut(duration: 0.8).delay(file.delay),
            value: filesConverged
        )
    }

    // MARK: - Computed Animation Properties

    private var iconOpacity: Double {
        if !filesVisible { return 0 }
        if filesConverged { return 0 }
        return 1
    }

    private var iconScale: CGFloat {
        if !filesVisible { return 0.5 }
        if filesConverged { return 0.3 }
        return 1.0
    }

    private var iconRotation: Double {
        if !filesVisible { return file.rotation }
        if filesConverged { return 0 }
        return file.rotation
    }

    private var iconOffsetX: CGFloat {
        if !filesVisible { return file.startX }
        if filesConverged { return 0 }
        return file.startX + driftOffset * (file.rotation > 0 ? 1 : -1)
    }

    private var iconOffsetY: CGFloat {
        if !filesVisible { return file.startY }
        if filesConverged { return 0 }
        return file.startY + driftOffset * (file.rotation > 0 ? -1 : 1)
    }
}

// MARK: - Welcome Step View

/// First step: Welcome screen with files-into-folder animation and display typography
struct WelcomeStepView: View {
    let onContinue: () -> Void

    // MARK: - Animation State

    @State private var filesVisible = false
    @State private var filesConverged = false
    @State private var folderPulsing = false
    @State private var heroVisible = false
    @State private var folderVisible = false
    @State private var driftOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animation stage (400x320)
            ZStack {
                // Subtle radial gradient for depth
                RadialGradient(
                    colors: [Color.formaSteelBlue.opacity(0.06), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )

                // Central folder
                CentralFolderView(isPulsing: folderPulsing)
                    .opacity(folderVisible ? 1 : 0)
                    .scaleEffect(folderVisible ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: folderVisible)

                // Scattered file icons
                ForEach(scatteredFiles) { file in
                    ScatteredFileIcon(
                        file: file,
                        filesVisible: filesVisible,
                        filesConverged: filesConverged,
                        driftOffset: driftOffset
                    )
                }
            }
            .frame(width: 400, height: 320)

            // Hero text (fades up after animation completes)
            VStack(spacing: FormaSpacing.tight) {
                Text("Your files, finally organized.")
                    .font(.formaDisplayHero)
                    .foregroundColor(.formaLabel)

                Text("Forma learns how you work and keeps your folders tidy — automatically.")
                    .font(.formaBodyLarge)
                    .foregroundColor(.formaSecondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FormaSpacing.extraLarge)
            }
            .opacity(heroVisible ? 1 : 0)
            .offset(y: heroVisible ? 0 : 16)

            Spacer()

            // CTA button
            WelcomeCTAButton(action: onContinue)
                .padding(.horizontal, FormaSpacing.huge)
                .padding(.bottom, FormaSpacing.large)
                .opacity(heroVisible ? 1 : 0)
                .offset(y: heroVisible ? 0 : 12)
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        // Phase 1: Scatter in (0-0.5s) — files and folder fade in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            filesVisible = true
            folderVisible = true
        }

        // Phase 2: Drift (0.5-2s) — subtle floating movement
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            driftOffset = 4
        }

        // Phase 3: Converge (2-3s) — files animate toward folder center
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                filesConverged = true
            }
        }

        // Folder pulse when files "land"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            folderPulsing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                folderPulsing = false
            }
        }

        // Phase 4: Hero reveal (3-3.5s) — text and CTA fade up
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.6)) {
                heroVisible = true
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

// MARK: - Preview

#Preview("Welcome Step") {
    WelcomeStepView(onContinue: {})
        .frame(width: 650, height: 720)
        .background(Color.formaBackground)
}
