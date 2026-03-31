struct GuidedTourMeasurementPolicy {
    static func shouldCollectFrames(isTourActive: Bool, hasSeenTour: Bool) -> Bool {
        isTourActive || !hasSeenTour
    }
}
