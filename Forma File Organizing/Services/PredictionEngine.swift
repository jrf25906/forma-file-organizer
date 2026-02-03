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

        guard let predictedLabel = prediction.featureValue(for: "label")?.stringValue,
              let probabilities = prediction.featureValue(for: "labelProbability")?.dictionaryValue as? [String: Double] else {
            throw DestinationPredictionService.PredictionError.predictionFailed
        }

        let sorted = probabilities.sorted { $0.value > $1.value }
        let top1 = sorted.first?.value ?? 0.0
        let top2 = sorted.count > 1 ? sorted[1].value : nil

        return PredictionOutcome(label: predictedLabel, confidence: top1, top2Confidence: top2)
    }
}
