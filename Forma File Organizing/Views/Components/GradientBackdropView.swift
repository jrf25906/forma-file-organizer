//
//  GradientBackdropView.swift
//  Forma - Gradient Backdrop for Glassmorphism
//
//  A subtle gradient backdrop that enhances the visibility of glass materials
//  by providing colorful content behind translucent panels.
//

import SwiftUI

/// A reusable gradient backdrop component that makes glass materials more visible
/// Uses Forma brand colors in strategic radial gradients with blur for a soft, atmospheric effect
struct GradientBackdropView: View {
    /// Overall opacity multiplier for the gradient (0.0-1.0)
    let intensity: Double
    
    /// Amount of blur to apply to the gradient layer
    let blurRadius: CGFloat
    
    /// Whether to animate the gradient subtly (not implemented yet)
    let animated: Bool
    
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool { colorScheme == .dark }
    
    init(
        intensity: Double = Color.FormaOpacity.high,
        blurRadius: CGFloat = FormaSpacing.huge + FormaSpacing.standard,
        animated: Bool = false
    ) {
        self.intensity = intensity
        self.blurRadius = blurRadius
        self.animated = animated
    }
    
    var body: some View {
        ZStack {
            // Top-left: Steel Blue radial gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.formaSteelBlue.opacity(isDarkMode ? Color.FormaOpacity.overlay : Color.FormaOpacity.strong),
                    Color.clear
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: 600
            )
            
            // Bottom-right: Sage green radial gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.formaSage.opacity(isDarkMode ? Color.FormaOpacity.overlay : Color.FormaOpacity.strong),
                    Color.clear
                ]),
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 650
            )
            
            // Center-bottom: Warm orange radial gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.formaWarmOrange.opacity(isDarkMode ? Color.FormaOpacity.medium : Color.FormaOpacity.overlay),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.5, y: 0.8),
                startRadius: 0,
                endRadius: 500
            )
            
            // Accent: Muted blue for additional depth
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.formaMutedBlue.opacity(isDarkMode ? Color.FormaOpacity.medium : Color.FormaOpacity.overlay),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.3, y: 0.4),
                startRadius: 0,
                endRadius: 450
            )
        }
        .blur(radius: blurRadius)
        .opacity(intensity)
        .ignoresSafeArea()
    }
}

// MARK: - View Extension

extension View {
    /// Apply Forma's gradient backdrop behind the view to enhance glass materials
    func formaGradientBackdrop(
        intensity: Double = Color.FormaOpacity.high,
        blurRadius: CGFloat = FormaSpacing.huge + FormaSpacing.standard
    ) -> some View {
        ZStack {
            GradientBackdropView(intensity: intensity, blurRadius: blurRadius)
            self
        }
    }
}

// MARK: - Preview

#Preview("Gradient Backdrop - Light Mode") {
    ZStack {
        GradientBackdropView()
        
        VStack(spacing: FormaSpacing.generous - FormaSpacing.micro) {
            // Sidebar simulation
            VStack {
                Text("Sidebar")
                    .font(.formaBodySemibold)
                Text("Glass panel over gradient")
                    .font(.formaSmall)
            }
            .frame(width: 200, height: 400)
            .formaPadding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.large + FormaRadius.micro, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.large + FormaRadius.micro, style: .continuous)
                    .stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1)
            )
            .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.medium), radius: 12, x: 0, y: 4)
            
            // Main content simulation
            VStack {
                Text("Main Content")
                    .font(.formaBodySemibold)
                Text("Ultra thin material")
                    .font(.formaSmall)
            }
            .frame(width: 400, height: 300)
            .formaPadding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous))
        }
    }
    .background(.thickMaterial)
    .frame(width: FormaSpacing.Window.preferredWidth, height: FormaSpacing.Window.preferredHeight)
}

#Preview("Gradient Backdrop - Dark Mode") {
    ZStack {
        GradientBackdropView()
        
        VStack(spacing: FormaSpacing.generous - FormaSpacing.micro) {
            // Sidebar simulation
            VStack {
                Text("Sidebar")
                    .font(.formaBodySemibold)
                Text("Glass panel over gradient")
                    .font(.formaSmall)
            }
            .frame(width: 200, height: 400)
            .formaPadding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.large + FormaRadius.micro, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.large + FormaRadius.micro, style: .continuous)
                    .stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1)
            )
            .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.medium), radius: 12, x: 0, y: 4)
            
            // Main content simulation
            VStack {
                Text("Main Content")
                    .font(.formaBodySemibold)
                Text("Ultra thin material")
                    .font(.formaSmall)
            }
            .frame(width: 400, height: 300)
            .formaPadding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous))
        }
    }
    .background(.thickMaterial)
    .frame(width: FormaSpacing.Window.preferredWidth, height: FormaSpacing.Window.preferredHeight)
    .preferredColorScheme(.dark)
}
