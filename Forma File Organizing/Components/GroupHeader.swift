import SwiftUI

/// Group header for file groupings (date-based or pattern-based)
struct GroupHeader: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.formaCompactSemibold)
                    .foregroundColor(Color.formaSecondaryLabel)
                    .kerning(0.5)
                
                Spacer()
            }
            .padding(.top, FormaSpacing.tight)
            .padding(.bottom, FormaSpacing.tight)
            .padding(.horizontal, FormaSpacing.standard)
            
            // Bottom border
            Rectangle()
                .fill(Color.formaSeparator)
                .frame(height: 1)
        }
        .padding(.bottom, FormaSpacing.tight)
    }
}

#Preview {
    VStack(spacing: 0) {
        GroupHeader(title: "Today")
        GroupHeader(title: "These look like screenshots")
        GroupHeader(title: "This Week")
    }
    .background(Color.formaBoneWhite)
}
