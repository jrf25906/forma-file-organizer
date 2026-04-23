import Foundation
@preconcurrency import CoreML

struct PredictionOutcome: Equatable, Sendable {
    let label: String
    let confidence: Double
    let top2Confidence: Double?
}

protocol PredictionEngine: Sendable {
    var requiresModel: Bool { get }
    func predict(features: DestinationFeatures, model: MLModel?) async throws -> PredictionOutcome
}

struct CoreMLPredictionEngine: PredictionEngine {
    let requiresModel = true

    func predict(features: DestinationFeatures, model: MLModel?) async throws -> PredictionOutcome {
        guard let model else {
            throw DestinationPredictionService.PredictionError.noModelAvailable
        }

        let input = try MLDictionaryFeatureProvider(dictionary: ["text": features.combinedText()])
        let prediction = try await model.prediction(from: input)

        return try Self.outcome(from: prediction)
    }

    static func outcome(from prediction: MLFeatureProvider) throws -> PredictionOutcome {
        let predictedLabel = try predictedLabel(from: prediction)
        let probabilities = try labelProbabilities(from: prediction)
        let sorted = probabilities.sorted { $0.probability > $1.probability }
        let top1 = sorted.first?.probability ?? 0.0
        let top2 = sorted.count > 1 ? sorted[1].probability : nil

        return PredictionOutcome(label: predictedLabel, confidence: top1, top2Confidence: top2)
    }

    static func predictedLabel(from prediction: MLFeatureProvider) throws -> String {
        if let label = prediction.featureValue(for: "label")?.stringValue {
            return label
        }

        if let label = prediction.featureValue(for: "classLabel")?.stringValue {
            return label
        }

        throw DestinationPredictionService.PredictionError.predictionFailed
    }

    static func confidence(
        for predictedLabel: String,
        from prediction: MLFeatureProvider
    ) -> Double? {
        guard let probabilities = try? labelProbabilities(from: prediction) else {
            return nil
        }

        let sorted = probabilities.sorted { $0.probability > $1.probability }
        return sorted.first { $0.label == predictedLabel }?.probability
    }

    private static func labelProbabilities(
        from prediction: MLFeatureProvider
    ) throws -> [(label: String, probability: Double)] {
        let probabilityFeatureNames = ["labelProbability", "classProbability"]
        let rawProbabilities = probabilityFeatureNames
            .lazy
            .compactMap { prediction.featureValue(for: $0)?.dictionaryValue }
            .first

        guard let rawProbabilities else {
            throw DestinationPredictionService.PredictionError.predictionFailed
        }

        let probabilities = rawProbabilities.compactMap { key, value -> (label: String, probability: Double)? in
            guard let label = key as? String else { return nil }
            return (label, value.doubleValue)
        }

        guard !probabilities.isEmpty else {
            throw DestinationPredictionService.PredictionError.predictionFailed
        }

        return probabilities
    }
}
