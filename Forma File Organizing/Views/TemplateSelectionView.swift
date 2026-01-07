import SwiftUI

/// View for selecting an organization template during onboarding or in settings.
///
/// Displays cards for each available template with descriptions, icons,
/// folder structure previews, and target personas.
struct TemplateSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTemplate: OrganizationTemplate
    
    let onSelect: (OrganizationTemplate) -> Void
    
    @State private var hoveredTemplate: OrganizationTemplate?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    init(selectedTemplate: Binding<OrganizationTemplate>, onSelect: @escaping (OrganizationTemplate) -> Void) {
        self._selectedTemplate = selectedTemplate
        self.onSelect = onSelect
        
        // Pre-select template based on personality if available
        if let personality = OrganizationPersonality.load() {
            // Only apply personality preference if user hasn't explicitly chosen yet
            if selectedTemplate.wrappedValue == .minimal {
                selectedTemplate.wrappedValue = personality.suggestedTemplate
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: FormaSpacing.standard) {
                Image(systemName: "square.grid.2x2")
                    .font(.formaIcon)
                    .foregroundStyle(Color.formaSteelBlue)
                    .padding(.bottom, FormaSpacing.standard)

                Text("Choose Your Organization System")
                    .font(.formaH2)
                    .foregroundStyle(Color.formaLabel)
                
                Text(headerSubtitle)
                    .formaBodyStyle()
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            .padding(.vertical, FormaSpacing.huge)
            
            // Template Cards Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: FormaSpacing.large),
                    GridItem(.flexible(), spacing: FormaSpacing.large)
                ], spacing: FormaSpacing.large) {
                    ForEach(OrganizationTemplate.allCases.filter { $0 != .custom }, id: \.self) { template in
                        TemplateCard(
                            template: template,
                            isSelected: selectedTemplate == template,
                            isHovered: hoveredTemplate == template,
                            onSelect: {
                                selectedTemplate = template
                            }
                        )
                        .onHover { isHovered in
                            if isHovered {
                                hoveredTemplate = template
                            } else if hoveredTemplate == template {
                                hoveredTemplate = nil
                            }
                        }
                    }
                }
                .padding(FormaSpacing.huge)
                .padding(.bottom, FormaSpacing.extraLarge)
            }
            
            // Footer with action buttons
            VStack(spacing: FormaSpacing.standard) {
                Button(action: {
                    onSelect(selectedTemplate)
                }) {
                    HStack {
                        Text("Continue with \(selectedTemplate.displayName)")
                            .font(Font.formaBodyBold)
                        Image(systemName: "arrow.right")
                            .font(.formaBodySemibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.standard - FormaSpacing.micro)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaSteelBlue)
                    )
                    .foregroundColor(.formaBoneWhite)
                    .shadow(color: Color.formaSteelBlue.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("templateContinueButton")
                
                Button(action: {
                    selectedTemplate = .custom
                    onSelect(.custom)
                }) {
                    Text("Start with no rules (Custom)")
                }
                .buttonStyle(.plain)
                .font(.formaCaption)
                .foregroundStyle(Color.formaSecondaryLabel)
            }
            .padding(FormaSpacing.extraLarge)
            .background(Color.formaControlBackground)
        }
        .frame(width: 900, height: 700)
        .background(Color.formaBackground)
    }
    
    private var headerSubtitle: String {
        if let personality = OrganizationPersonality.load() {
            return "Based on your preferences, we recommend \(personality.suggestedTemplate.displayName). You can choose any system below or change it later."
        }
        return "Select a proven organization method that matches your workflow. You can always change this later or create custom rules."
    }
}

// MARK: - Template Card

/// Individual card for each organization template.
private struct TemplateCard: View {
    let template: OrganizationTemplate
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: FormaSpacing.large) {
                // Icon and title
                HStack(spacing: FormaSpacing.standard) {
                    Image(systemName: template.iconName)
                        .font(.formaHero)
                        .foregroundStyle(iconColor)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: FormaRadius.control + (FormaRadius.micro / 2), style: .continuous)
                                .fill(iconBackground)
                        )
                    
                    VStack(alignment: .leading, spacing: FormaSpacing.micro / 2) {
                        Text(template.displayName)
                            .font(.formaBodyLarge)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.formaLabel)
                        
                        Text(template.targetPersona)
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaSecondaryLabel)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.formaH1)
                            .foregroundStyle(Color.formaSteelBlue)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Description
                Text(template.description)
                    .font(.formaBody)
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                    .background(Color.formaSeparator)
                
                // Folder structure preview
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    Text("Folder Structure")
                        .font(.formaSmall)
                        .foregroundStyle(Color.formaSecondaryLabel)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(template.folderStructure.prefix(4), id: \.self) { folder in
                            HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                                Image(systemName: "folder.fill")
                                    .font(.formaCompact)
                                    .foregroundStyle(Color.formaSteelBlue.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))

                                Text(folder)
                                    .font(.formaMono)
                                    .foregroundStyle(Color.formaLabel)
                            }
                        }
                        
                        if template.folderStructure.count > 4 {
                            Text("+ \(template.folderStructure.count - 4) more...")
                                .font(.formaCaption)
                                .foregroundStyle(Color.formaSecondaryLabel)
                                .padding(.leading, FormaSpacing.standard + (FormaSpacing.micro / 2))
                        }
                    }
                }
            }
            .padding(FormaSpacing.large)
            .frame(height: 280)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            .scaleEffect(isHovered && !reduceMotion ? 1.02 : 1.0)
            .animation(reduceMotion ? .none : FormaAnimation.quickEnter, value: isHovered)
            .animation(reduceMotion ? .none : FormaAnimation.quickEnter, value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    private var iconColor: Color {
        if isSelected {
            return Color.formaSteelBlue
        } else {
            return Color.formaSecondaryLabel
        }
    }
    
    private var iconBackground: Color {
        if isSelected {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
        } else {
            return Color.formaControlBackground
        }
    }
    
    private var cardBackground: Color {
        if isSelected {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle)
        } else if isHovered {
            return Color.formaControlBackground
        } else {
            return Color.formaBoneWhite.opacity(Color.FormaOpacity.strong)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.formaSteelBlue
        } else if isHovered {
            return Color.formaSeparator.opacity(Color.FormaOpacity.prominent)
        } else {
            return Color.formaSeparator.opacity(Color.FormaOpacity.overlay)
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }
    
    private var shadowColor: Color {
        if isSelected {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle)
        } else if isHovered {
            return Color.formaObsidian.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle)
        } else {
            return Color.clear
        }
    }
    
    private var shadowRadius: CGFloat {
        (isSelected || isHovered) ? 8 : 0
    }
    
    private var shadowY: CGFloat {
        (isSelected || isHovered) ? 4 : 0
    }
}

// MARK: - Preview

#Preview("Template Selection") {
    TemplateSelectionView(
        selectedTemplate: .constant(.para),
        onSelect: { template in
            Log.debug("Preview selected template: \\(template.displayName)", category: .ui)
        }
    )
}

#Preview("Template Card") {
    HStack(spacing: FormaSpacing.generous - FormaSpacing.micro) {
        TemplateCard(
            template: .para,
            isSelected: false,
            isHovered: false,
            onSelect: {}
        )
        .frame(width: 400)
        
        TemplateCard(
            template: .academic,
            isSelected: true,
            isHovered: false,
            onSelect: {}
        )
        .frame(width: 400)
    }
    .padding(FormaSpacing.large + FormaSpacing.tight)
    .background(Color.formaBackground)
}
