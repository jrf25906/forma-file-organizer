import SwiftUI

enum ConfidenceTier: String {
    case high
    case medium
    case low

    static func forScore(_ score: Double) -> ConfidenceTier {
        if score >= 0.9 {
            return .high
        } else if score >= 0.6 {
            return .medium
        } else {
            return .low
        }
    }

    var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var icon: String {
        switch self {
        case .high: return "checkmark.shield.fill"
        case .medium: return "checkmark.circle.fill"
        case .low: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .high: return .formaSage
        case .medium: return .formaSteelBlue
        case .low: return .formaWarmOrange
        }
    }
}

enum ConfidenceMetrics {
    static func averageScore(from scores: [Double?]) -> Double {
        let values = scores.compactMap { $0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
