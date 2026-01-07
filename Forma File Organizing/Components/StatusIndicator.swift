import SwiftUI

/// A 3D "bulb" status indicator with glossy appearance and depth
struct StatusIndicator: View {
    let status: FileItem.OrganizationStatus
    
    private var color: Color {
        switch status {
        case .ready:
            return .formaSteelBlue
        case .pending:
            return .formaObsidian.opacity(Color.FormaOpacity.overlay)
        case .skipped:
            return .formaWarning
        case .completed:
            return .formaSage
        }
    }
    
    var body: some View {
        ZStack {
            // Base circle with status color
            Circle()
                .fill(color)
                .frame(width: FormaSpacing.tight - (FormaSpacing.micro / 4), height: FormaSpacing.tight - (FormaSpacing.micro / 4))
            
            // Glossy highlight overlay (top-left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light),
                            Color.formaBoneWhite.opacity(Color.FormaOpacity.medium),
                            Color.clear
                        ],
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: 4
                    )
                )
                .frame(width: 7, height: 7)
            
            // Inner shadow for depth (simulated with darker gradient at bottom-right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.formaObsidian.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle)
                        ],
                        center: .init(x: 0.7, y: 0.7),
                        startRadius: 0,
                        endRadius: 3.5
                    )
                )
                .frame(width: FormaSpacing.tight - (FormaSpacing.micro / 4), height: FormaSpacing.tight - (FormaSpacing.micro / 4))
        }
        .shadow(color: color.opacity(Color.FormaOpacity.overlay), radius: 2, x: 0, y: 0.5)
        .accessibilityLabel(status.badgeText)
    }
}

#Preview("All Statuses") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            StatusIndicator(status: .ready)
            Text("Ready")
                .font(.formaBody)
        }
        
        HStack(spacing: 12) {
            StatusIndicator(status: .pending)
            Text("Pending")
                .font(.formaBody)
        }
        
        HStack(spacing: 12) {
            StatusIndicator(status: .skipped)
            Text("Skipped")
                .font(.formaBody)
        }
        
        HStack(spacing: 12) {
            StatusIndicator(status: .completed)
            Text("Completed")
                .font(.formaBody)
        }
    }
    .padding()
}
