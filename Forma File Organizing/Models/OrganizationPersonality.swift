import Foundation
import SwiftUI

/// Represents a user's organization personality and preferences.
///
/// This model captures how a user naturally thinks about and organizes their files,
/// allowing Forma to customize the experience and suggest appropriate templates.
struct OrganizationPersonality: Codable, Equatable {
    
    // MARK: - Personality Dimensions
    
    /// How the user prefers to organize: visual/surface-level vs. hidden/hierarchical
    var organizationStyle: OrganizationStyle
    
    /// How the user thinks visually: everything visible vs. structured hierarchy
    var thinkingStyle: ThinkingStyle
    
    /// How the user mentally models their work
    var mentalModel: MentalModel
    
    // MARK: - Enums
    
    enum OrganizationStyle: String, Codable, CaseIterable {
        case piler = "Piler"
        case filer = "Filer"
        
        var description: String {
            switch self {
            case .piler:
                return "Visual organizer - prefers to see files on the surface"
            case .filer:
                return "Structured organizer - prefers hidden, deep hierarchies"
            }
        }
        
        var icon: String {
            switch self {
            case .piler:
                return "square.stack.3d.up"
            case .filer:
                return "folder.fill"
            }
        }
    }
    
    enum ThinkingStyle: String, Codable, CaseIterable {
        case visual = "Visual"
        case hierarchical = "Hierarchical"
        
        var description: String {
            switch self {
            case .visual:
                return "Needs to see everything at a glance"
            case .hierarchical:
                return "Comfortable with nested structure"
            }
        }
        
        var icon: String {
            switch self {
            case .visual:
                return "eye.fill"
            case .hierarchical:
                return "list.bullet.indent"
            }
        }
    }
    
    enum MentalModel: String, Codable, CaseIterable {
        case projectBased = "Project-Based"
        case timeBased = "Time-Based"
        case topicBased = "Topic-Based"
        
        var description: String {
            switch self {
            case .projectBased:
                return "Thinks in terms of projects and clients"
            case .timeBased:
                return "Organizes by time periods (weeks, months)"
            case .topicBased:
                return "Categorizes by subject or file type"
            }
        }
        
        var icon: String {
            switch self {
            case .projectBased:
                return "folder.badge.person.crop"
            case .timeBased:
                return "calendar"
            case .topicBased:
                return "square.grid.2x2"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Suggested organization template based on personality
    var suggestedTemplate: OrganizationTemplate {
        // Pilers generally prefer minimal/simple systems
        if organizationStyle == .piler {
            return .minimal
        }
        
        // Filers with project-based thinking
        if organizationStyle == .filer && mentalModel == .projectBased {
            return .creativeProf
        }
        
        // Filers with time-based thinking
        if organizationStyle == .filer && mentalModel == .timeBased {
            return .chronological
        }
        
        // Filers with topic-based thinking + hierarchical
        if organizationStyle == .filer && mentalModel == .topicBased && thinkingStyle == .hierarchical {
            return .johnnyDecimal
        }
        
        // Default to PARA - good general-purpose system
        return .para
    }
    
    // MARK: - Initialization
    
    init(
        organizationStyle: OrganizationStyle,
        thinkingStyle: ThinkingStyle,
        mentalModel: MentalModel
    ) {
        self.organizationStyle = organizationStyle
        self.thinkingStyle = thinkingStyle
        self.mentalModel = mentalModel
    }
    
    // MARK: - Default Personalities
    
    /// Default personality for new users (balanced)
    static let `default` = OrganizationPersonality(
        organizationStyle: .filer,
        thinkingStyle: .visual,
        mentalModel: .projectBased
    )
    
    /// Creative professional personality
    static let creative = OrganizationPersonality(
        organizationStyle: .piler,
        thinkingStyle: .visual,
        mentalModel: .projectBased
    )
    
    /// Academic/researcher personality
    static let academic = OrganizationPersonality(
        organizationStyle: .filer,
        thinkingStyle: .hierarchical,
        mentalModel: .topicBased
    )
    
    /// Business professional personality
    static let business = OrganizationPersonality(
        organizationStyle: .filer,
        thinkingStyle: .hierarchical,
        mentalModel: .timeBased
    )
}

// MARK: - AppStorage Helper

extension OrganizationPersonality {
    /// Key for storing personality in AppStorage
    static let storageKey = "userOrganizationPersonality"
    
    /// Save personality to AppStorage
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }
    
    /// Load personality from AppStorage
    static func load() -> OrganizationPersonality? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let personality = try? JSONDecoder().decode(OrganizationPersonality.self, from: data) else {
            return nil
        }
        return personality
    }
    
    /// Clear saved personality
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
