import Foundation

/// Defines the three view modes for displaying files in the dashboard
enum ViewMode: String, Codable, CaseIterable, Identifiable {
    case card = "card"
    case list = "list" 
    case grid = "grid"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .card: return "Card"
        case .list: return "List"
        case .grid: return "Grid"
        }
    }
    
    var iconName: String {
        switch self {
        case .card: return "rectangle.portrait.fill"
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

/// Global density preference for file cards/rows/tiles.
enum FileDisplayDensity: String, Codable, CaseIterable, Identifiable {
    case tight = "tight"
    case balanced = "balanced"
    case spacious = "spacious"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tight: return "Tight"
        case .balanced: return "Balanced"
        case .spacious: return "Spacious"
        }
    }
}
