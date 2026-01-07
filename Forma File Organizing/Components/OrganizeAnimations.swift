import SwiftUI
import AVFoundation
import AppKit  // For NSSound

// MARK: - Sound Effect Support (Optional)

/// Sound effect manager for micro-interactions
@MainActor
final class FormaSoundEffects {
    static let shared = FormaSoundEffects()
    private var player: AVAudioPlayer?
    
    private init() {}
    
    /// Play a subtle "swoosh" sound when organizing files
    func playOrganizeSound() {
        // Play macOS system sound for organizing action
        NSSound(named: "Hero")?.play()
    }
    
    /// Play a subtle success sound
    func playSuccessSound() {
        // Play macOS system sound for success
        NSSound(named: "Glass")?.play()
    }
}

// MARK: - Animated Checkmark (Drawing Animation)

/// A checkmark that draws itself for a delightful completion effect
struct AnimatedCheckmark: View {
    @State private var drawProgress: CGFloat = 0.0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.formaSage)
                .frame(width: 64, height: 64)
                .scaleEffect(scale)
                .opacity(opacity)
            
            // Checkmark path
            CheckmarkShape(progress: drawProgress)
                .stroke(Color.formaBoneWhite, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 32, height: 32)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            if reduceMotion {
                // Instant appearance for reduced motion
                drawProgress = 1.0
                scale = 1.0
                opacity = 1.0
            } else {
                // Animate the checkmark drawing itself
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
                
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    drawProgress = 1.0
                }
                
                // Fade out after display
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        opacity = 0.0
                    }
                }
            }
        }
    }
}

/// Custom shape for drawing checkmark path
struct CheckmarkShape: Shape {
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Checkmark path points
        let start = CGPoint(x: width * 0.2, y: height * 0.5)
        let middle = CGPoint(x: width * 0.45, y: height * 0.75)
        let end = CGPoint(x: width * 0.85, y: height * 0.25)
        
        // Draw based on progress
        if progress <= 0.5 {
            // First segment (start to middle)
            let segmentProgress = progress / 0.5
            path.move(to: start)
            path.addLine(to: CGPoint(
                x: start.x + (middle.x - start.x) * segmentProgress,
                y: start.y + (middle.y - start.y) * segmentProgress
            ))
        } else {
            // Complete first segment, draw second
            let segmentProgress = (progress - 0.5) / 0.5
            path.move(to: start)
            path.addLine(to: middle)
            path.addLine(to: CGPoint(
                x: middle.x + (end.x - middle.x) * segmentProgress,
                y: middle.y + (end.y - middle.y) * segmentProgress
            ))
        }
        
        return path
    }
}

// MARK: - Enhanced Organize Animation Overlay

/// Animation effect when a file is organized
struct OrganizeAnimationOverlay: View {
    @State private var showCheckmark = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        ZStack {
            if showCheckmark {
                AnimatedCheckmark()
            }
        }
        .onAppear {
            showCheckmark = true
            
            // Optional: Play success sound
            if !reduceMotion {
                FormaSoundEffects.shared.playSuccessSound()
            }
        }
    }
}

// MARK: - Particle Burst Effect

/// Celebratory particle burst effect when file is organized
struct ParticleBurstEffect: View {
    @State private var particles: [Particle] = []
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    struct Particle: Identifiable {
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
                    .frame(width: FormaSpacing.tight - (FormaSpacing.micro / 2), height: FormaSpacing.tight - (FormaSpacing.micro / 2))
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .offset(x: particle.offsetX, y: particle.offsetY)
            }
        }
        .onAppear {
            if !reduceMotion {
                generateParticles()
                animateParticles()
            }
        }
    }
    
    private func generateParticles() {
        let colors: [Color] = [
            .formaSage,
            .formaSteelBlue,
            .formaSage.opacity(Color.FormaOpacity.high),
            .formaSteelBlue.opacity(Color.FormaOpacity.high),
        ]
        let particleCount = 6
        
        for i in 0..<particleCount {
            let angle = (Double(i) / Double(particleCount)) * 360.0
            let speed = CGFloat.random(in: 40...60)
            
            particles.append(Particle(
                angle: angle,
                color: colors[i % colors.count],
                speed: speed
            ))
        }
    }
    
    private func animateParticles() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
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

/// View modifier that adds "sucked into folder" organize animation to file cards
struct OrganizeAnimationModifier: ViewModifier {
    let isOrganizing: Bool
    let onComplete: () -> Void
    
    @State private var showCheckmark = false
    @State private var showParticleBurst = false
    @State private var cardOpacity: Double = 1.0
    @State private var cardScale: CGFloat = 1.0
    @State private var cardRotation: Double = 0.0
    @State private var cardOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(cardScale)
            .rotationEffect(.degrees(cardRotation))
            .offset(cardOffset)
            .opacity(cardOpacity)
            .overlay {
                if showCheckmark {
                    OrganizeAnimationOverlay()
                }
            }
            .overlay {
                if showParticleBurst {
                    ParticleBurstEffect()
                }
            }
            .onChange(of: isOrganizing) { _, organizing in
                if organizing {
                    performOrganizeAnimation()
                }
            }
    }
    
    private func performOrganizeAnimation() {
        if reduceMotion {
            // Instant transition for reduced motion
            showCheckmark = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                cardOpacity = 0.0
                onComplete()
            }
        } else {
            // Optional: Play organize sound
            FormaSoundEffects.shared.playOrganizeSound()
            
            // PHASE 1: Show checkmark and slight pulse (0.0s - 0.3s)
            showCheckmark = true
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                cardScale = 1.05 // Slight grow
            }
            
            // PHASE 2: Return to normal size (0.3s - 0.5s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    cardScale = 1.0
                }
            }
            
            // PHASE 3: "Sucked into folder" - shrink, rotate, move (0.6s - 1.0s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeIn(duration: 0.4)) {
                    // Shrink and fade
                    cardScale = 0.3
                    cardOpacity = 0.0
                    
                    // Slight rotation for dynamic feel
                    cardRotation = -8.0
                    
                    // Move towards top-right (folder destination)
                    cardOffset = CGSize(width: 200, height: -100)
                }
                
                // Trigger particle burst near the end of shrink animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showParticleBurst = true
                }
                
                // PHASE 4: Complete callback (1.0s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onComplete()
                }
            }
        }
    }
}

extension View {
    /// Apply organize animation to file card with "sucked into folder" effect
    func organizeAnimation(isOrganizing: Bool, onComplete: @escaping () -> Void) -> some View {
        self.modifier(OrganizeAnimationModifier(isOrganizing: isOrganizing, onComplete: onComplete))
    }
}

/// Flash animation for rule applied
struct RuleAppliedFlash: ViewModifier {
    let isApplied: Bool
    @State private var flashOpacity: Double = 0.0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if flashOpacity > 0 {
                    RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                        .fill(Color.formaSage.opacity(flashOpacity * Color.FormaOpacity.overlay))
                }
            }
            .onChange(of: isApplied) { _, applied in
                if applied && !reduceMotion {
                    // Quick flash
                    withAnimation(.easeOut(duration: 0.1)) {
                        flashOpacity = 1.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            flashOpacity = 0.0
                        }
                    }
                }
            }
    }
}

extension View {
    /// Apply green flash when rule is applied
    func ruleAppliedFlash(isApplied: Bool) -> some View {
        self.modifier(RuleAppliedFlash(isApplied: isApplied))
    }
}

/// Celebration animation for empty state
struct CelebrationAnimation: View {
    @State private var confettiItems: [ConfettiItem] = []
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    struct ConfettiItem: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var color: Color
        var delay: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiItems) { item in
                    if !reduceMotion {
                        Text("✨")
                            .font(.formaH2)
                            .position(x: item.x, y: isAnimating ? geometry.size.height + 50 : item.y)
                            .rotationEffect(.degrees(isAnimating ? item.rotation + 360 : item.rotation))
                            .opacity(isAnimating ? 0 : 1)
                            .animation(
                                .easeIn(duration: 1.5).delay(item.delay),
                                value: isAnimating
                            )
                    }
                }
            }
            .onAppear {
                if !reduceMotion {
                    generateConfetti(in: geometry.size)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isAnimating = true
                    }
                }
            }
        }
    }
    
    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [.formaSage, .formaSteelBlue, .formaWarning]
        
        for i in 0..<8 {
            confettiItems.append(ConfettiItem(
                x: size.width * 0.3 + CGFloat.random(in: 0...(size.width * 0.4)),
                y: size.height * 0.3 - CGFloat(i * 20),
                rotation: Double.random(in: 0...360),
                color: colors.randomElement() ?? .formaSage,
                delay: Double(i) * 0.05
            ))
        }
    }
}

/// Card removal transition (swoosh effect)
extension AnyTransition {
    static var organizeCard: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: .move(edge: .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.8))
        )
    }
}

// MARK: - Conditional Matched Geometry

/// Performance-optimized modifier that only applies matchedGeometryEffect when actively needed.
/// This avoids the overhead of geometry tracking for all 1000+ files when only a few are animating.
struct ConditionalMatchedGeometry: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let isActive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        // Use matchedGeometryEffect with isSource to control tracking
        // When isSource=false and no matching source exists, the effect is essentially a no-op
        content.matchedGeometryEffect(id: id, in: namespace, isSource: isActive)
    }
}

extension View {
    /// Apply matchedGeometryEffect only when the file is actively being organized.
    /// PERF: When isActive=false, uses isSource=false which minimizes geometry tracking overhead.
    func conditionalMatchedGeometry(id: String, in namespace: Namespace.ID, isActive: Bool) -> some View {
        self.modifier(ConditionalMatchedGeometry(id: id, namespace: namespace, isActive: isActive))
    }
}

private struct OrganizeAnimationPreviewView: View {
    @State private var isOrganizing = false

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaBoneWhite)
                .frame(width: 400, height: 80)
                .overlay {
                    Text("File Card")
                        .font(.formaBody)
                }
                .organizeAnimation(isOrganizing: isOrganizing) {
                    Log.debug("Preview organize animation complete", category: .ui)
                }

            Button("Organize File") {
                isOrganizing = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isOrganizing = false
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 500, height: 300)
        .background(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong))
    }
}

#Preview("Organize Animation") {
    OrganizeAnimationPreviewView()
}

#Preview("Celebration Animation") {
    ZStack {
        Color.formaBoneWhite
        
        CelebrationAnimation()
            .frame(width: 400, height: 400)
    }
}
