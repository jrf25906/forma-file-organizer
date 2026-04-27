//
//  GuidedTourOverlay.swift
//  Forma File Organizing
//
//  Main overlay that composes a dimmed spotlight background with
//  a positioned tooltip card for the guided tour walkthrough.
//

import SwiftUI

struct GuidedTourOverlay: View {

    // MARK: - Properties

    var tourState: GuidedTourState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed Helpers

    private var activeAnimation: Animation? {
        reduceMotion
            ? nil
            : FormaAnimation.premiumSpring
    }

    // MARK: - Body

    var body: some View {
        if tourState.isActive,
           let currentStep = tourState.currentStep,
           let currentFrame = tourState.currentFrame {
            GeometryReader { geometry in
                ZStack {
                    // Layer 1 -- Dimmed backdrop with spotlight cutout
                    SpotlightCutoutShape(targetFrame: currentFrame)
                        .fill(
                            Color.formaObsidian.opacity(0.55),
                            style: FillStyle(eoFill: true)
                        )
                        .animation(activeAnimation, value: currentFrame)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            tourState.nextStep()
                        }

                    // Layer 2 -- Tooltip card positioned relative to spotlight
                    tooltipCard(
                        step: currentStep,
                        spotlightFrame: currentFrame,
                        windowSize: geometry.size
                    )
                    .animation(activeAnimation, value: currentFrame)
                }
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .zIndex(200)
        }
    }

    // MARK: - Tooltip Positioning

    // MARK: - Card dimensions (used for edge-anchored positioning + clamping)

    private let cardWidth: CGFloat = 300
    private let cardEstimatedHeight: CGFloat = 260
    private let windowPadding: CGFloat = 20

    @ViewBuilder
    private func tooltipCard(
        step: GuidedTourStep,
        spotlightFrame: CGRect,
        windowSize: CGSize
    ) -> some View {
        let position = tooltipPosition(
            for: step.tooltipPlacement,
            spotlightFrame: spotlightFrame,
            windowSize: windowSize
        )

        GuidedTourCard(
            step: step,
            currentStepIndex: tourState.currentStepIndex,
            totalSteps: tourState.totalSteps,
            onNext: { tourState.nextStep() },
            onSkip: { tourState.skipTour() }
        )
        .fixedSize()
        .position(x: position.x, y: position.y)
    }

    /// Returns the absolute point at which the tooltip CENTER should be placed.
    /// Accounts for card dimensions so the card edge (not center) aligns with
    /// the spotlight edge, then clamps to keep the card within the window.
    private func tooltipPosition(
        for placement: TooltipPlacement,
        spotlightFrame: CGRect,
        windowSize: CGSize
    ) -> CGPoint {
        let gap = FormaSpacing.standard // 16pt gap between spotlight and card
        let halfW = cardWidth / 2
        let halfH = cardEstimatedHeight / 2

        var x: CGFloat
        var y: CGFloat

        switch placement {
        case .trailing:
            // Card's leading edge at spotlight's trailing edge + gap
            x = spotlightFrame.maxX + gap + halfW
            y = spotlightFrame.midY

        case .leading:
            // Card's trailing edge at spotlight's leading edge - gap
            x = spotlightFrame.minX - gap - halfW
            y = spotlightFrame.midY

        case .bottom:
            // Card's top edge at spotlight's bottom edge + gap
            x = spotlightFrame.midX
            y = spotlightFrame.maxY + gap + halfH

        case .top:
            // Card's bottom edge at spotlight's top edge - gap
            x = spotlightFrame.midX
            y = spotlightFrame.minY - gap - halfH
        }

        // Clamp to keep card fully within window bounds
        x = max(windowPadding + halfW, min(x, windowSize.width - halfW - windowPadding))
        y = max(windowPadding + halfH, min(y, windowSize.height - halfH - windowPadding))

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview

#if DEBUG
private struct GuidedTourOverlayPreview: View {
    @State private var tourState = GuidedTourState()

    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
                .ignoresSafeArea()

            // Simulate a region for the first step
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.white)
                .frame(width: 200, height: 60)
                .overlay(Text("Watched Folders"))
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                tourState.regionFrames[.sidebarLocations] =
                                    proxy.frame(in: .global)
                            }
                    }
                )

            GuidedTourOverlay(tourState: tourState)
        }
        .frame(width: 800, height: 600)
        .onAppear {
            tourState.startTour()
        }
    }
}

#Preview("Guided Tour Overlay") {
    GuidedTourOverlayPreview()
}
#endif
