import SwiftUI

struct SecondaryFilterTab: View {
    let filter: SecondaryFilter
    let isSelected: Bool
    let glassNamespace: Namespace.ID?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(filter.displayName)
                .font(isSelected ? .formaBodyMedium : .formaBody)
                .foregroundColor(isSelected ? .formaObsidian : .formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
                .padding(.vertical, FormaSpacing.micro)
                .background {
                    if isSelected {
                        if #available(macOS 26.0, *), let namespace = glassNamespace {
                            Capsule()
                                .glassEffect(.regular.tint(Color.formaSteelBlue.opacity(Color.FormaOpacity.medium + Color.FormaOpacity.subtle)))
                                .glassEffectID(filter.hashValue, in: namespace)
                        } else {
                            Capsule()
                                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle))
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

extension SecondaryFilter {
    var displayName: String {
        switch self {
        case .none: return "All"
        case .recent: return "Recent"
        case .largeFiles: return "Large Files"
        case .flagged: return "Flagged"
        }
    }
}
