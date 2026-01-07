import SwiftUI

struct StatusBadge: View {
    enum Status {
        case success
        case warning
        case error
        case neutral
        
        var color: Color {
            switch self {
            case .success: return .formaSage
            case .warning: return .formaWarning
            case .error: return .formaError
            case .neutral: return .formaSecondaryLabel
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark"
            case .neutral: return "minus"
            }
        }
    }
    
    let status: Status
    let text: String
    
    var body: some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: status.icon)
                .font(.formaMicro)
                .fontWeight(.bold)
            Text(text)
                .formaMetadataStyle()
        }
        .foregroundColor(status.color)
        .padding(.vertical, FormaSpacing.micro)
        .padding(.horizontal, FormaSpacing.tight)
        .background(status.color.opacity(Color.FormaOpacity.light))
        .formaCornerRadius(FormaRadius.micro)
    }
}

extension String {
    func camelCaseToTitleCase() -> String {
        // fileExtension -> File Extension
        // nameStartsWith -> Name Starts With
        let result = self.reduce(into: "") { result, character in
            if character.isUppercase && !result.isEmpty {
                result.append(" ")
            }
            result.append(character)
        }
        return result.capitalized
    }
}
