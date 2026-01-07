//
//  FormaMicroanimations.swift
//  Forma - Microanimation Components
//
//  Focused microanimations for Create Rule and Settings interactions
//

import SwiftUI

// MARK: - Animation Constants

extension FormaAnimation {
    /// Micro-interaction (120–180ms)
    static let microInteraction: Double = 0.15
    
    /// Quick transition (180–240ms)
    static let quickTransition: Double = 0.22
    
    /// Validation shake duration
    static let shakeDuration: Double = 0.18
    
    /// Spring for drags and interactive elements
    static let interactiveSpring: Animation = .interactiveSpring(response: 0.22, dampingFraction: 0.9)
    
    /// Quick easeOut for enters
    static let quickEnter: Animation = .easeOut(duration: quickTransition)
    
    /// Quick easeIn for exits
    static let quickExit: Animation = .easeIn(duration: microInteraction)
}

// MARK: - Validation Shake Animation

struct ValidationShakeModifier: ViewModifier {
    let trigger: Bool
    @State private var shakeOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: trigger) { _, newValue in
                guard newValue && !reduceMotion else { return }
                performShake()
            }
    }
    
    private func performShake() {
        // 3 oscillations over 180ms
        let amplitude: CGFloat = 3
        
        withAnimation(.linear(duration: 0.06)) {
            shakeOffset = amplitude
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.linear(duration: 0.06)) {
                shakeOffset = -amplitude
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.linear(duration: 0.06)) {
                shakeOffset = 0
            }
        }
    }
}

extension View {
    func validationShake(trigger: Bool) -> some View {
        self.modifier(ValidationShakeModifier(trigger: trigger))
    }
}

// MARK: - Toggle Ripple Effect

struct ToggleRippleModifier: ViewModifier {
    let trigger: Bool
    @State private var rippleScale: CGFloat = 0.01
    @State private var rippleOpacity: Double = 1
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(Color.formaLabel.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                performRipple()
            }
    }
    
    private func performRipple() {
        rippleScale = 0.01
        rippleOpacity = 1
        
        withAnimation(.easeOut(duration: 0.35)) {
            rippleScale = 1.2
            rippleOpacity = 0
        }
    }
}

extension View {
    func toggleRipple(trigger: Bool) -> some View {
        self.modifier(ToggleRippleModifier(trigger: trigger))
    }
}

// MARK: - Hover Lift Effect (macOS)

struct HoverLiftModifier: ViewModifier {
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    let scaleAmount: CGFloat
    let shadowRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered && !reduceMotion ? scaleAmount : 1.0)
            .shadow(
                color: Color.formaObsidian.opacity(
                    isHovered && !reduceMotion
                        ? (Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle)
                        : Color.FormaOpacity.ultraSubtle
                ),
                radius: isHovered && !reduceMotion ? shadowRadius : 2,
                x: 0,
                y: isHovered && !reduceMotion ? 2 : 1
            )
            .animation(FormaAnimation.quickEnter, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1.01, shadowRadius: CGFloat = 6) -> some View {
        self.modifier(HoverLiftModifier(scaleAmount: scale, shadowRadius: shadowRadius))
    }
}

// MARK: - Expand/Collapse Animation

// MARK: - Checkmark Draw Animation

struct CheckmarkDrawShape: Shape {
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let start = CGPoint(x: rect.width * 0.2, y: rect.height * 0.5)
        let middle = CGPoint(x: rect.width * 0.45, y: rect.height * 0.75)
        let end = CGPoint(x: rect.width * 0.85, y: rect.height * 0.25)
        
        if progress <= 0.5 {
            let segmentProgress = progress / 0.5
            path.move(to: start)
            path.addLine(to: CGPoint(
                x: start.x + (middle.x - start.x) * segmentProgress,
                y: start.y + (middle.y - start.y) * segmentProgress
            ))
        } else {
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

struct CheckmarkDrawView: View {
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    let color: Color
    let size: CGFloat
    
    init(color: Color = .formaSage, size: CGFloat = 16) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        CheckmarkDrawShape(progress: progress)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .onAppear {
                if reduceMotion {
                    progress = 1.0
                } else {
                    withAnimation(.easeOut(duration: 0.25)) {
                        progress = 1.0
                    }
                }
            }
    }
}

// MARK: - Progress Ring Animation

struct ProgressRingView: View {
    let progress: CGFloat
    let lineWidth: CGFloat
    let color: Color
    
    init(progress: CGFloat, lineWidth: CGFloat = 2, color: Color = .formaSteelBlue) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
    }
    
    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }
}

// MARK: - Button Morph State

enum ButtonMorphState {
    case normal
    case loading
    case success
    case error
}

struct MorphingButtonContent: View {
    let state: ButtonMorphState
    let title: String
    let iconColor: Color
    
    @State private var loadingProgress: CGFloat = 0
    @State private var showCheckmark = false
    @State private var checkScale: CGFloat = 0.8
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        ZStack {
            // Normal state
            if state == .normal {
                HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                    Image(systemName: "plus.circle.fill")
                        .font(.formaCompactMedium)
                    Text(title)
                        .font(.formaBodyBold)
                }
                .transition(.opacity)
            }
            
            // Loading state
            if state == .loading {
                ProgressRingView(progress: loadingProgress)
                    .frame(width: 20, height: 20)
                    .transition(.opacity)
                    .onAppear {
                        if !reduceMotion {
                            withAnimation(.linear(duration: 0.5)) {
                                loadingProgress = 0.9
                            }
                        }
                    }
            }
            
            // Success state
            if state == .success {
                CheckmarkDrawView(color: iconColor, size: 16)
                    .scaleEffect(checkScale)
                    .transition(.opacity)
                    .onAppear {
                        if !reduceMotion {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                checkScale = 1.0
                            }
                        } else {
                            checkScale = 1.0
                        }
                    }
            }
            
            // Error state
            if state == .error {
                Image(systemName: "xmark")
                    .font(.formaCompactMedium)
                    .foregroundColor(.formaError)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.12) : FormaAnimation.quickEnter, value: state)
    }
}

// MARK: - Floating Label Animation

// MARK: - Condition Row Expand Animation

struct ConditionRowContainer<Content: View>: View {
    let isVisible: Bool
    let content: Content
    @State private var offset: CGFloat = 4
    @State private var opacity: Double = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    init(isVisible: Bool, @ViewBuilder content: () -> Content) {
        self.isVisible = isVisible
        self.content = content()
    }
    
    var body: some View {
        content
            .offset(x: offset)
            .opacity(opacity)
            .onAppear {
                guard isVisible else { return }
                
                if reduceMotion {
                    offset = 0
                    opacity = 1
                } else {
                    withAnimation(FormaAnimation.interactiveSpring) {
                        offset = 0
                        opacity = 1
                    }
                }
            }
    }
}

// MARK: - Icon Swap Animation

// MARK: - Permission Status Animation

struct PermissionStatusView: View {
    enum Status {
        case pending
        case granted
        case error
    }
    
    let status: Status
    @State private var rotationDegrees: Double = 0
    @State private var checkProgress: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        ZStack {
            switch status {
            case .pending:
                // Rotating dashed ring
                Circle()
                    .stroke(
                        Color.formaSecondaryLabel,
                        style: StrokeStyle(lineWidth: 2, dash: [4, 4])
                    )
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(rotationDegrees))
                    .overlay(
                        Circle()
                            .fill(Color.formaSecondaryLabel)
                            .frame(width: 6, height: 6)
                            .scaleEffect(pulseScale)
                    )
                    .onAppear {
                        guard !reduceMotion else { return }
                        
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotationDegrees = 360
                        }
                        
                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                            pulseScale = 1.3
                        }
                    }
                
            case .granted:
                // Ring completes then checkmark
                Circle()
                    .trim(from: 0, to: checkProgress)
                    .stroke(Color.formaSage, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
                    .overlay(
                        Group {
                            if checkProgress >= 1.0 {
                                CheckmarkDrawView(color: .formaSage, size: 14)
                            }
                        }
                    )
                    .onAppear {
                        if reduceMotion {
                            checkProgress = 1.0
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) {
                                checkProgress = 1.0
                            }
                        }
                    }
                
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.formaBodyLarge)
                    .foregroundColor(.formaWarning)
                    .validationShake(trigger: true)
            }
        }
    }
}

// MARK: - Previews

private struct ValidationShakePreviewView: View {
    @State private var triggerShake = false

    var body: some View {
        VStack(spacing: 20) {
            TextField("Test Field", text: .constant(""))
                .textFieldStyle(.plain)
                .padding(FormaSpacing.tight + (FormaSpacing.micro / 2))
                .background(Color.formaObsidian.opacity(Color.FormaOpacity.subtle - Color.FormaOpacity.ultraSubtle))
                .formaCornerRadius(FormaRadius.micro)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                        .stroke(Color.formaWarning, lineWidth: 1)
                )
                .validationShake(trigger: triggerShake)
                .padding()

            Button("Trigger Shake") {
                triggerShake.toggle()
            }
        }
        .frame(width: 300)
    }
}

#Preview("Validation Shake") {
    ValidationShakePreviewView()
}

private struct ToggleRipplePreviewView: View {
    @State private var isOn = false

    var body: some View {
        Toggle("Test Toggle", isOn: $isOn)
            .toggleStyle(.switch)
            .padding()
            .toggleRipple(trigger: isOn)
    }
}

#Preview("Toggle Ripple") {
    ToggleRipplePreviewView()
}

private struct MorphingButtonPreviewView: View {
    @State private var state: ButtonMorphState = .normal

    var body: some View {
        VStack(spacing: 20) {
            MorphingButtonContent(state: state, title: "Save Rule", iconColor: .formaSteelBlue)
                .padding()
                .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                .formaCornerRadius(FormaRadius.control)

            HStack {
                Button("Normal") { state = .normal }
                Button("Loading") { state = .loading }
                Button("Success") { state = .success }
                Button("Error") { state = .error }
            }
        }
        .padding()
    }
}

#Preview("Morphing Button") {
    MorphingButtonPreviewView()
}

#Preview("Permission Status") {
    HStack(spacing: FormaSpacing.large + FormaSpacing.tight) {
        VStack {
            PermissionStatusView(status: .pending)
            Text("Pending")
        }
        VStack {
            PermissionStatusView(status: .granted)
            Text("Granted")
        }
        VStack {
            PermissionStatusView(status: .error)
            Text("Error")
        }
    }
    .padding()
}
