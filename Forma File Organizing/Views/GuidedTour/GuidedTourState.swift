import SwiftUI

/// Manages the state and progression of the guided tour overlay.
@Observable
@MainActor
final class GuidedTourState {

    // MARK: - Stored Properties

    private(set) var currentStepIndex: Int = 0
    private(set) var isActive: Bool = false
    var regionFrames: [GuidedTourRegion: CGRect] = [:]

    // MARK: - Computed Properties

    var currentStep: GuidedTourStep? {
        guard isActive,
              GuidedTourStep.allSteps.indices.contains(currentStepIndex) else {
            return nil
        }
        return GuidedTourStep.allSteps[currentStepIndex]
    }

    var currentFrame: CGRect? {
        guard let step = currentStep else { return nil }
        return regionFrames[step.region]
    }

    var totalSteps: Int {
        GuidedTourStep.allSteps.count
    }

    var hasSeenTour: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenGuidedTour") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenGuidedTour") }
    }

    // MARK: - Tour Lifecycle

    func startTour() {
        currentStepIndex = 0
        isActive = true
    }

    func nextStep() {
        guard isActive else { return }

        let allSteps = GuidedTourStep.allSteps

        guard allSteps.indices.contains(currentStepIndex) else {
            completeTour()
            return
        }

        if allSteps[currentStepIndex].isLastStep {
            completeTour()
            return
        }

        // Advance to the next step that has a registered frame, skipping any
        // steps whose region has not been measured yet.
        var nextIndex = currentStepIndex + 1
        while nextIndex < allSteps.count {
            let candidateRegion = allSteps[nextIndex].region
            if regionFrames[candidateRegion] != nil {
                currentStepIndex = nextIndex
                return
            }
            nextIndex += 1
        }

        // No remaining step has a visible frame -- finish the tour.
        completeTour()
    }

    func skipTour() {
        isActive = false
        hasSeenTour = true
    }

    func completeTour() {
        isActive = false
        hasSeenTour = true
    }

    func checkShouldShowTour() {
        if !hasSeenTour {
            startTour()
        }
    }

    func replayTour() {
        hasSeenTour = false
        startTour()
    }
}

// MARK: - Replay Notification

extension Notification.Name {
    static let replayGuidedTour = Notification.Name("replayGuidedTour")
}
