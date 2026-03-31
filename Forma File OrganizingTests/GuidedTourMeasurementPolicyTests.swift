import Testing
@testable import Forma_File_Organizing

struct GuidedTourMeasurementPolicyTests {

    @Test func measurementStaysEnabledWhileTourIsActive() {
        #expect(GuidedTourMeasurementPolicy.shouldCollectFrames(isTourActive: true, hasSeenTour: true))
    }

    @Test func measurementStaysEnabledUntilTourHasBeenSeen() {
        #expect(GuidedTourMeasurementPolicy.shouldCollectFrames(isTourActive: false, hasSeenTour: false))
    }

    @Test func measurementDisablesAfterTourCompletes() {
        #expect(!GuidedTourMeasurementPolicy.shouldCollectFrames(isTourActive: false, hasSeenTour: true))
    }
}
