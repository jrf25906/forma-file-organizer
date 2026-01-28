import Foundation

// MARK: - Training Data

/// Training record extracted from ActivityItem history.
/// Plain struct for easy serialization and testing without SwiftData complexity.
struct DestinationTrainingRecord: Codable, Equatable, Sendable {
    /// Normalized file name (lowercased, whitespace-trimmed)
    var fileName: String
    
    /// File extension without dot (e.g., "pdf")
    var fileExtension: String
    
    /// Source location (e.g., "Desktop", "Downloads")
    var sourceLocation: String?
    
    /// Destination path (normalized, e.g., tilde-ified)
    var destinationPath: String
    
    /// When this move occurred
    var timestamp: Date
    
    /// Optional project cluster identifier if file was part of a detected cluster
    var projectCluster: String?
}

// MARK: - Prediction Features

/// Ephemeral feature representation for a file being predicted.
/// These tokens are combined into a text string for ML classification.
struct DestinationFeatures: Equatable, Sendable {
    /// File extension
    var fileExtension: String
    
    /// Extracted name keywords (split on _, -, space, numbers)
    var nameKeywords: [String]
    
    /// File type category token (e.g., "image", "document")
    var fileTypeCategory: String
    
    /// Time bucket (e.g., "hour_09", "weekday", "weekend")
    var timeBucket: String
    
    /// Source folder (e.g., "Desktop", "Downloads")
    var sourceFolder: String?
    
    /// Optional project cluster identifier
    var projectCluster: String?
    
    /// Combine all features into a single text string for ML classifier input
    func combinedText() -> String {
        var tokens: [String] = []
        
        // Extension
        tokens.append("ext_\(fileExtension.lowercased())")
        
        // Keywords
        tokens.append(contentsOf: nameKeywords.map { "kw_\($0)" })
        
        // Category
        tokens.append("cat_\(fileTypeCategory)")
        
        // Time
        tokens.append(timeBucket)
        
        // Source
        if let source = sourceFolder {
            tokens.append("src_\(source)")
        }
        
        // Cluster
        if let cluster = projectCluster {
            tokens.append("cluster_\(cluster)")
        }
        
        return tokens.joined(separator: " ")
    }
}

// MARK: - Prediction Results

/// Source of a file organization suggestion
enum SuggestionSource: String, Codable, Sendable {
    case rule           // From RuleEngine match
    case pattern        // From LearnedPattern
    case mlPrediction   // From ML model
}

/// Explanation for why a prediction was made
struct PredictionExplanation: Codable, Equatable, Sendable {
    /// Short human-readable summary (e.g., "Similar to 12 past invoice PDFs")
    var summary: String
    
    /// Detailed reasons (1-3 key factors)
    var reasons: [String]
    
    /// Example file names or patterns (up to 3, anonymized if needed)
    var exampleFiles: [String]
    
    init(summary: String, reasons: [String] = [], exampleFiles: [String] = []) {
        self.summary = summary
        self.reasons = reasons
        self.exampleFiles = exampleFiles
    }
}

/// Result of a destination prediction
struct PredictedDestination: Equatable, Sendable {
    /// Predicted destination path
    var path: String

    /// Confidence score (0.0-1.0)
    var confidence: Double

    /// Source of this suggestion
    var source: SuggestionSource

    /// Explanation of why this destination was predicted
    var explanation: PredictionExplanation

    /// Model version that produced this prediction
    var modelVersion: String

    /// Security-scoped bookmark data for the predicted destination folder.
    /// When present, allows direct file operations without additional user prompts.
    /// When nil, the prediction is informational only (user must approve destination access).
    var bookmarkData: Data?
}

// MARK: - Prediction Context

/// Context for making predictions (allowed destinations, user settings)
struct PredictionContext: Sendable {
    /// List of destination paths the model is allowed to suggest
    /// Empty means no restrictions
    var allowedDestinations: [String]
    
    /// Whether ML predictions are enabled for this user
    var mlEnabled: Bool
    
    /// Minimum confidence threshold to show predictions
    var minimumConfidence: Double
    
    init(
        allowedDestinations: [String] = [],
        mlEnabled: Bool = true,
        minimumConfidence: Double = 0.7
    ) {
        self.allowedDestinations = allowedDestinations
        self.mlEnabled = mlEnabled
        self.minimumConfidence = minimumConfidence
    }
}

// MARK: - Model Metadata

/// Metadata about the current active model
struct DestinationModelMetadata: Codable, Sendable {
    /// Model version string
    var version: String
    
    /// When the model was trained
    var trainedAt: Date
    
    /// Number of training examples
    var exampleCount: Int
    
    /// Number of distinct destinations
    var labelCount: Int
    
    /// Validation accuracy
    var accuracy: Double
    
    /// Whether this model is currently active
    var isActive: Bool
}
