import Foundation
import SwiftData

/// Tracks ML model training history, evaluation metrics, and version management.
///
/// Each training run creates a record with metrics used for drift detection,
/// rollback decisions, and audit trails. Only models marked `accepted = true`
/// are deployed for predictions.
@Model
final class MLTrainingHistory {
    /// Unique identifier
    var id: UUID
    
    /// Model type identifier (e.g., "destinationPrediction")
    var modelName: String
    
    /// Version string (e.g., "1-2025-12-05T120000Z")
    var version: String
    
    /// When this model was trained
    var trainedAt: Date
    
    /// Number of training examples used
    var exampleCount: Int
    
    /// Number of distinct labels (destinations)
    var labelCount: Int
    
    /// Validation accuracy (0.0-1.0)
    var validationAccuracy: Double
    
    /// Optional validation loss
    var validationLoss: Double?
    
    /// False positive rate on validation set
    var falsePositiveRate: Double?
    
    /// Whether this model passed evaluation gates and was activated
    var accepted: Bool
    
    /// Optional notes for debugging or audit
    var notes: String?
    
    init(
        modelName: String,
        version: String,
        trainedAt: Date = Date(),
        exampleCount: Int,
        labelCount: Int,
        validationAccuracy: Double,
        validationLoss: Double? = nil,
        falsePositiveRate: Double? = nil,
        accepted: Bool,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.modelName = modelName
        self.version = version
        self.trainedAt = trainedAt
        self.exampleCount = exampleCount
        self.labelCount = labelCount
        self.validationAccuracy = validationAccuracy
        self.validationLoss = validationLoss
        self.falsePositiveRate = falsePositiveRate
        self.accepted = accepted
        self.notes = notes
    }
}

// MARK: - Mock Data

extension MLTrainingHistory {
    static var mocks: [MLTrainingHistory] {
        [
            MLTrainingHistory(
                modelName: "destinationPrediction",
                version: "1-2025-12-01T100000Z",
                exampleCount: 150,
                labelCount: 5,
                validationAccuracy: 0.78,
                falsePositiveRate: 0.15,
                accepted: true,
                notes: "Initial model after cold-start threshold"
            ),
            MLTrainingHistory(
                modelName: "destinationPrediction",
                version: "2-2025-12-02T120000Z",
                exampleCount: 250,
                labelCount: 7,
                validationAccuracy: 0.82,
                falsePositiveRate: 0.12,
                accepted: true,
                notes: "Retrained with additional data"
            )
        ]
    }
}
