import SwiftUI

/// A button that morphs through different states for delightful feedback
/// States: Normal → Processing (with progress) → Success → Resets
struct MorphingActionButton: View {
    let title: String
    let icon: String
    let action: () async -> Void
    
    @State private var buttonState: ButtonState = .normal
    @State private var progress: Double = 0.0
    @State private var buttonWidth: CGFloat? = nil
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    enum ButtonState {
        case normal
        case processing
        case success
    }
    
    var body: some View {
        Button {
            performAction()
        } label: {
            buttonContent
                .frame(width: buttonWidth)
                .frame(height: FormaSpacing.large + FormaSpacing.tight)
                .background(buttonBackground)
                .clipShape(Capsule())
                .shadow(color: Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(buttonState != .normal)
    }
    
    @ViewBuilder
    private var buttonContent: some View {
        ZStack {
            // Normal state: Icon + Text
            if buttonState == .normal {
                HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                    Image(systemName: icon)
                        .font(.formaBodyMedium)
                    Text(title)
                        .font(.formaBodySemibold)
                }
                .foregroundColor(.formaBoneWhite)
                .padding(.horizontal, FormaSpacing.standard + (FormaSpacing.micro / 2))
                .transition(.opacity)
            }
            
            // Processing state: Spinner
            if buttonState == .processing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .formaBoneWhite))
                    .scaleEffect(0.9)
                    .transition(.opacity)
            }
            
            // Success state: Checkmark
            if buttonState == .success {
                Image(systemName: "checkmark")
                    .font(.formaBodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.formaBoneWhite)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: buttonState)
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        Group {
            if buttonState == .success {
                // Success: Green circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.formaSage,
                                Color.formaSage.opacity(Color.FormaOpacity.prominent + Color.FormaOpacity.light)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                // Normal/Processing: Blue capsule
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.formaSteelBlue,
                                Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent + Color.FormaOpacity.light)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: buttonState)
    }
    
    private func performAction() {
        guard buttonState == .normal else { return }
        
        // Capture initial width
        if buttonWidth == nil {
            // Estimate width based on text
            let textWidth = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]).width
            buttonWidth = textWidth + 60 // Add padding and icon space
        }
        
        Task {
            // PHASE 1: Morph to processing state
            if !reduceMotion {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    buttonState = .processing
                    buttonWidth = 40 // Shrink to circle
                }
                
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            }
            
            // PHASE 2: Execute action
            await action()
            
            // PHASE 3: Show success state
            if !reduceMotion {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    buttonState = .success
                }
                
                // Optional: Play success sound
                FormaSoundEffects.shared.playSuccessSound()
                
                // PHASE 4: Reset after delay
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    buttonState = .normal
                    buttonWidth = nil
                }
            } else {
                // For reduced motion, just reset immediately
                buttonState = .normal
                buttonWidth = nil
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct MorphingButtonPreview: View {
        var body: some View {
            VStack(spacing: FormaSpacing.large + FormaSpacing.tight) {
                Text("Micro-Interaction Demo")
                    .font(.formaH2)
                
                MorphingActionButton(
                    title: "Organize All",
                    icon: "arrow.down.doc.fill"
                ) {
                    // Simulate work
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
                
                MorphingActionButton(
                    title: "Apply Rules",
                    icon: "sparkles"
                ) {
                    // Simulate work
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }
            .frame(width: 400, height: 300)
            .background(Color.formaBoneWhite.opacity(Color.FormaOpacity.overlay))
        }
    }
    
    return MorphingButtonPreview()
}
