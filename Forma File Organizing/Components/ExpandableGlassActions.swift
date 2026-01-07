//
//  ExpandableGlassActions.swift
//  Forma File Organizing
//
//  Created by Warp AI on 11/25/25.
//  Expandable glass button cluster with liquid glass morphing animations
//

import SwiftUI

/// Expandable glass action button cluster with morphing animations
/// Inspired by Apple's WWDC 2025 Liquid Glass examples
struct ExpandableGlassActions: View {
    @Binding var isExpanded: Bool
    let onShare: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void
    
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let clusterSpacing: CGFloat = FormaSpacing.standard - FormaSpacing.micro
    private let buttonSize: CGFloat = FormaSpacing.extraLarge - FormaSpacing.micro
    
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: clusterSpacing) {
                HStack(spacing: clusterSpacing) {
                    // Always visible: Main toggle button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "xmark" : "ellipsis")
                            .font(.formaBodyMedium)
                            .foregroundColor(.formaBoneWhite)
                            .frame(width: buttonSize, height: buttonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        Circle()
                            .fill(Color.formaSteelBlue)
                            .glassEffect(.regular.tint(Color.glassBlue))
                            .glassEffectID("toggle", in: glassNamespace)
                            .shadow(color: Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay), radius: 8, x: 0, y: 4)
                    }
                    .help(isExpanded ? "Close actions" : "More actions")
                    
                    // Conditional: Action buttons (morph in/out)
                    if isExpanded {
                        actionButton(
                            icon: "square.and.arrow.up",
                            color: .formaSteelBlue,
                            glassID: "share",
                            help: "Share",
                            action: onShare
                        )
                        
                        actionButton(
                            icon: "arrow.down.doc",
                            color: .formaSage,
                            glassID: "move",
                            help: "Move to folder",
                            action: onMove
                        )
                        
                        actionButton(
                            icon: "trash",
                            color: .formaError,
                            glassID: "delete",
                            help: "Delete",
                            action: onDelete
                        )
                    }
                }
            }
        } else {
            // Fallback for macOS < 26.0 - standard buttons without glass morphing
            HStack(spacing: clusterSpacing) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "xmark" : "ellipsis")
                        .font(.formaBodyMedium)
                        .foregroundColor(.formaBoneWhite)
                        .frame(width: buttonSize, height: buttonSize)
                }
                .buttonStyle(.plain)
                .background {
                    Circle()
                        .fill(Color.formaSteelBlue)
                        .shadow(color: Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay), radius: 8, x: 0, y: 4)
                }
                
                if isExpanded {
                    fallbackActionButton(icon: "square.and.arrow.up", color: .formaSteelBlue, help: "Share", action: onShare)
                    fallbackActionButton(icon: "arrow.down.doc", color: .formaSage, help: "Move", action: onMove)
                    fallbackActionButton(icon: "trash", color: .formaError, help: "Delete", action: onDelete)
                }
            }
        }
    }
    
    // MARK: - Liquid Glass Action Button (macOS 26.0+)
    
    @available(macOS 26.0, *)
    @ViewBuilder
    private func actionButton(
        icon: String,
        color: Color,
        glassID: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
                isExpanded = false // Close after action
            }
        }) {
            Image(systemName: icon)
                .font(.formaBodyMedium)
                .foregroundColor(.formaBoneWhite)
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            Circle()
                .fill(color)
                .glassEffect(.regular.tint(color.opacity(Color.FormaOpacity.overlay + Color.FormaOpacity.light)))
                .glassEffectID(glassID, in: glassNamespace)
                .shadow(color: color.opacity(Color.FormaOpacity.overlay), radius: 8, x: 0, y: 4)
        }
        .help(help)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }
    
    // MARK: - Fallback Action Button (macOS < 26.0)
    
    @ViewBuilder
    private func fallbackActionButton(
        icon: String,
        color: Color,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
                isExpanded = false
            }
        }) {
            Image(systemName: icon)
                .font(.formaBodyMedium)
                .foregroundColor(.formaBoneWhite)
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.plain)
        .background {
            Circle()
                .fill(color)
                .shadow(color: color.opacity(Color.FormaOpacity.overlay), radius: 8, x: 0, y: 4)
        }
        .help(help)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.formaObsidian.opacity(Color.FormaOpacity.light)
            .ignoresSafeArea()
        
        VStack(spacing: FormaSpacing.large + FormaSpacing.tight) {
            ExpandableGlassActions(
                isExpanded: .constant(false),
                onShare: { Log.debug("Preview share action", category: .ui) },
                onMove: { Log.debug("Preview move action", category: .ui) },
                onDelete: { Log.debug("Preview delete action", category: .ui) }
            )
            
            ExpandableGlassActions(
                isExpanded: .constant(true),
                onShare: { Log.debug("Preview share action (expanded)", category: .ui) },
                onMove: { Log.debug("Preview move action (expanded)", category: .ui) },
                onDelete: { Log.debug("Preview delete action (expanded)", category: .ui) }
            )
        }
        .padding()
    }
    .frame(width: 400, height: 300)
}
