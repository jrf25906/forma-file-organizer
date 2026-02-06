import SwiftUI

// MARK: - Preview Step View

/// Fifth step: Final preview showing complete folder structure before completion
struct OnboardingPreviewStepView: View {
    let folderSelection: OnboardingFolderSelection
    @Binding var templateSelection: FolderTemplateSelection
    let personality: OrganizationPersonality?
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var animateIn = false
    @State private var showCustomize = false
    @State private var showCelebration = false
    @State private var showShimmer = false
    @State private var animateGradient = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedFolders: [OnboardingFolder] {
        var folders: [OnboardingFolder] = []
        if folderSelection.desktop { folders.append(.desktop) }
        if folderSelection.downloads { folders.append(.downloads) }
        if folderSelection.documents { folders.append(.documents) }
        if folderSelection.pictures { folders.append(.pictures) }
        if folderSelection.music { folders.append(.music) }
        return folders
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: FormaSpacing.generous) {
                    // Header with celebration
                    headerSection

                    // Complete folder structure preview
                    folderPreviewSection

                    // Customize templates (collapsible)
                    customizeSection

                    // Note about lazy folder creation
                    lazyCreationNote
                }
                .padding(.bottom, FormaSpacing.extraLarge)
            }

            // Footer with celebration button
            celebrationFooter
        }
        .overlay(alignment: .top) {
            // Particle burst at top center
            if showCelebration {
                OnboardingCelebrationBurst(
                    particleCount: 4,
                    colors: [.formaSteelBlue, .formaSage, .formaMutedBlue, .formaWarmOrange]
                )
                .frame(width: 200, height: 100)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, FormaSpacing.extraLarge)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            if reduceMotion {
                animateIn = true
                showCelebration = true
                showShimmer = true
                animateGradient = true
            } else {
                withAnimation(FormaAnimation.onboardingEntrance.delay(0.1)) {
                    animateIn = true
                }

                Task { @MainActor in
                    // Start gradient animation on CTA (0.3s)
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(
                        .easeInOut(duration: 3.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        animateGradient = true
                    }

                    // Trigger celebration burst (0.5s from appear)
                    try? await Task.sleep(for: .milliseconds(200))
                    showCelebration = true

                    // Trigger sequential shimmer (1.5s from appear)
                    try? await Task.sleep(for: .milliseconds(1000))
                    showShimmer = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: FormaSpacing.standard) {
            Text("\u{2728}")
                .font(.formaIcon)
                .scaleEffect(animateIn ? 1.0 : 0.5)
                .opacity(animateIn ? 1.0 : 0)
                .animation(
                    reduceMotion ? nil : FormaAnimation.onboardingBounce.delay(0.05),
                    value: animateIn
                )

            Text("Your Organization System")
                .font(.formaDisplayHeading)
                .foregroundColor(.formaLabel)
                .progressiveReveal(isVisible: animateIn, index: 0, baseDelay: 0.12)

            Text("Here's how Forma will organize your files.\nFolders are created automatically when files need them.")
                .font(.formaBodyLarge)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
                .progressiveReveal(isVisible: animateIn, index: 1, baseDelay: 0.12)
        }
        .padding(.top, FormaSpacing.huge)
    }

    // MARK: - Folder Preview Cards

    private var folderPreviewSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            ForEach(Array(selectedFolders.enumerated()), id: \.element) { index, folder in
                let template = templateSelection.template(for: folder, personality: personality)
                FolderStructurePreview(
                    rootFolderName: folder.title,
                    template: template,
                    showAnnotations: true,
                    accentColor: folder.color
                )
                .padding(FormaSpacing.standard)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .stroke(folder.color.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                )
                // Waterfall entrance: scale from 0.95 to 1.0
                .scaleEffect(reduceMotion || animateIn ? 1.0 : 0.95)
                // Subtle 3D rotation settling to flat
                .rotation3DEffect(
                    .degrees(reduceMotion || animateIn ? 0 : 4),
                    axis: (x: 1, y: 0, z: 0)
                )
                // Opacity and offset via progressiveReveal timing
                .opacity(animateIn ? 1.0 : 0)
                .offset(y: animateIn ? 0 : 20)
                // Sequential shimmer sweep
                .gradientShimmerSweep(trigger: showShimmer, delay: Double(index) * 0.15)
                .animation(
                    reduceMotion ? nil :
                        FormaAnimation.onboardingEntrance
                        .delay(FormaAnimation.staggerDelay(index: index + 2, base: 0.12)),
                    value: animateIn
                )
            }
        }
        .padding(.horizontal, FormaSpacing.large)
    }

    // MARK: - Customize Section

    private var customizeSection: some View {
        VStack(spacing: FormaSpacing.standard) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showCustomize.toggle()
                }
            }) {
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: showCustomize ? "chevron.down" : "chevron.right")
                        .font(.formaCompactSemibold)
                        .frame(width: 12)
                        .contentTransition(.symbolEffect(.replace))
                    Text("Customize templates")
                        .font(.formaBodyMedium)
                    Spacer()
                }
                .foregroundColor(.formaSteelBlue)
            }
            .buttonStyle(.plain)

            if showCustomize {
                VStack(spacing: FormaSpacing.standard) {
                    ForEach(selectedFolders, id: \.self) { folder in
                        FolderTemplateCard(
                            folder: folder,
                            selectedTemplate: templateBinding(for: folder),
                            personality: personality
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, FormaSpacing.large)
    }

    // MARK: - Lazy Creation Note

    private var lazyCreationNote: some View {
        HStack(spacing: FormaSpacing.tight) {
            Image(systemName: "sparkles")
                .font(.formaBodySemibold)
                .foregroundColor(.formaSage)

            Text("These folders will be created as files are sorted.\nNo empty folders\u{2014}just what you need, when needed.")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.leading)
        }
        .padding(FormaSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaSage.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
        )
        .padding(.horizontal, FormaSpacing.large)
        .opacity(animateIn ? 1.0 : 0)
    }

    // MARK: - Celebration Footer (Custom CTA)

    private var celebrationFooter: some View {
        VStack(spacing: FormaSpacing.standard) {
            HStack(spacing: FormaSpacing.standard) {
                // Back button
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.formaCompactSemibold)
                        Text("Back")
                            .font(.formaBodyLarge).fontWeight(.medium)
                    }
                    .foregroundColor(.formaSecondaryLabel)
                    .padding(.vertical, FormaSpacing.standard - (FormaSpacing.micro / 2))
                    .padding(.horizontal, FormaSpacing.large)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .stroke(Color.formaSeparator, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Primary CTA: animated gradient + sparkles icon
                Button(action: onComplete) {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "sparkles")
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                        Text("Start Organizing")
                            .font(.formaBodyLarge).fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.formaBodySemibold)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .foregroundColor(.formaBoneWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.standard - (FormaSpacing.micro / 2))
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.formaSteelBlue, Color.formaSage],
                                    startPoint: animateGradient ? .topLeading : .bottomLeading,
                                    endPoint: animateGradient ? .bottomTrailing : .topTrailing
                                )
                            )
                    )
                    .shadow(
                        color: Color.formaSteelBlue.opacity(Color.FormaOpacity.medium),
                        radius: 4, x: 0, y: 2
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
                }
                .buttonStyle(.plain)
                .formaPressEffect()
            }
        }
        .padding(FormaSpacing.large)
        .background(
            Rectangle()
                .fill(Color.formaControlBackground)
                .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle), radius: 8, x: 0, y: -4)
        )
    }

    // MARK: - Helpers

    private func templateBinding(for folder: OnboardingFolder) -> Binding<OrganizationTemplate> {
        Binding(
            get: { templateSelection.template(for: folder, personality: personality) },
            set: { newValue in templateSelection.setTemplate(newValue, for: folder) }
        )
    }
}

// MARK: - Onboarding Celebration Burst

/// Radial particle burst for the onboarding completion celebration.
/// Customizable particle count and colors, respects reduce motion.
private struct OnboardingCelebrationBurst: View {
    let particleCount: Int
    let colors: [Color]

    @State private var particles: [CelebrationParticle] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct CelebrationParticle: Identifiable {
        let id = UUID()
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        var opacity: Double = 1.0
        var scale: CGFloat = 1.0
        let angle: Double
        let color: Color
        let speed: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(
                        width: FormaSpacing.tight - (FormaSpacing.micro / 2),
                        height: FormaSpacing.tight - (FormaSpacing.micro / 2)
                    )
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .offset(x: particle.offsetX, y: particle.offsetY)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            generateParticles()
            animateParticles()
        }
    }

    private func generateParticles() {
        for i in 0..<particleCount {
            let angle = (Double(i) / Double(particleCount)) * 360.0
            let speed = CGFloat.random(in: 40...60)
            particles.append(CelebrationParticle(
                angle: angle,
                color: colors[i % colors.count],
                speed: speed
            ))
        }
    }

    private func animateParticles() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeOut(duration: 0.5)) {
                for i in particles.indices {
                    let radians = particles[i].angle * .pi / 180.0
                    particles[i].offsetX = cos(radians) * particles[i].speed
                    particles[i].offsetY = sin(radians) * particles[i].speed
                    particles[i].opacity = 0.0
                    particles[i].scale = 0.5
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Preview Step") {
    OnboardingPreviewStepView(
        folderSelection: OnboardingFolderSelection(
            desktop: true,
            downloads: true,
            documents: false,
            pictures: true,
            music: false
        ),
        templateSelection: .constant(FolderTemplateSelection(
            desktop: .minimal,
            downloads: .para,
            pictures: .chronological
        )),
        personality: nil,
        onComplete: {},
        onBack: {}
    )
    .frame(width: 650, height: 720)
    .background(Color.formaBackground)
}
