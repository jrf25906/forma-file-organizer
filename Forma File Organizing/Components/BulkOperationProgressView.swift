import SwiftUI

struct BulkOperationProgressView: View {
    let totalFiles: Int
    let progress: Double
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var processedFiles: Int {
        Int(progress * Double(totalFiles))
    }
    
    var body: some View {
        VStack(spacing: FormaSpacing.large) {
            Text("Organizing \(totalFiles) \(totalFiles == 1 ? "file" : "files")...")
                .font(.formaH2)
                .foregroundColor(.formaLabel)
            
            // Progress bar
            VStack(spacing: FormaSpacing.tight) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                            .fill(Color.formaObsidian.opacity(Color.FormaOpacity.light))
                            .frame(height: FormaSpacing.tight)
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                            .fill(Color.formaSteelBlue)
                            .frame(width: geometry.size.width * CGFloat(progress), height: FormaSpacing.tight)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: FormaSpacing.tight)
                
                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.formaBody.weight(.medium))
                        .foregroundColor(.formaLabel)
                    
                    Spacer()
                    
                    Text("(\(processedFiles) of \(totalFiles))")
                        .font(.formaBody)
                        .foregroundColor(.formaSecondaryLabel)
                }
            }
            
            SecondaryButton("Cancel", icon: "xmark") {
                onCancel()
            }
        }
        .padding(FormaSpacing.generous)
        .background(colorScheme == .dark ? Color.formaControlBackground.opacity(0.46) : Color.formaBoneWhite.opacity(0.78))
        .formaCornerRadius(FormaRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.52 : 0.34), lineWidth: 1)
        )
        .shadow(
            color: Color.formaObsidian.opacity(colorScheme == .dark ? 0.20 : 0.08),
            radius: 14,
            x: 0,
            y: 6
        )
        .frame(minWidth: 360, idealWidth: 400, maxWidth: 500)
    }
}

#Preview {
    ZStack {
        Color.formaObsidian.opacity(Color.FormaOpacity.overlay)
        BulkOperationProgressView(
            totalFiles: 47,
            progress: 0.6,
            onCancel: {}
        )
    }
}
