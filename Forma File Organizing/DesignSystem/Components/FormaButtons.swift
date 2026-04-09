//
//  FormaButtons.swift
//  Forma - Reusable UI Components
//
//  Primary and secondary button components
//  Extracted from FormaComponents.swift
//

import SwiftUI

// MARK: - Primary Button

struct FormaPrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var isEnabled: Bool = true
    var tint: Color = .formaSteelBlue
    var cornerRadius: CGFloat = FormaRadius.control

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.formaBodySemibold)
                }
                Text(title)
                    .font(.formaPrimaryButton)
            }
            .foregroundColor(.formaBoneWhite)
            .formaButtonPadding()
            .frame(maxWidth: .infinity)
        }
        .background(isEnabled ? tint : tint.opacity(Color.FormaOpacity.light * 4))
        .formaCornerRadius(cornerRadius)
        .formaShadow(.button)
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Secondary Button

struct FormaSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var isEnabled: Bool = true
    var cornerRadius: CGFloat = FormaRadius.control

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.formaBodyMedium)
                }
                Text(title)
                    .font(.formaSecondaryButton)
            }
            .foregroundColor(.formaObsidian)
            .formaButtonPadding()
            .frame(maxWidth: .infinity)
        }
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.formaObsidian.opacity(Color.FormaOpacity.medium), lineWidth: 1)
        )
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview("Primary Button") {
    VStack(spacing: 20) {
        FormaPrimaryButton(title: "Organize Now", action: {})
        FormaPrimaryButton(title: "Disabled Button", action: {}, isEnabled: false)
    }
    .padding()
    .frame(width: 300)
}

#Preview("Secondary Button") {
    VStack(spacing: 20) {
        FormaSecondaryButton(title: "Choose Different", action: {})
        FormaSecondaryButton(title: "Disabled Button", action: {}, isEnabled: false)
    }
    .padding()
    .frame(width: 300)
}
