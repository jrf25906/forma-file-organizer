import SwiftUI

struct BulkOperationProgressView: View {
    let totalFiles: Int
    let progress: Double
    let onCancel: () -> Void
    
    private var processedFiles: Int {
        Int(progress * Double(totalFiles))
    }
    
    var body: some View {
        VStack(spacing: FormaSpacing.large) {
            Text("Organizing \(totalFiles) files...")
                .font(.formaH2)
                .foregroundColor(.formaObsidian)
            
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
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: FormaSpacing.tight)
                
                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.formaBody.weight(.medium))
                        .foregroundColor(.formaObsidian)
                    
                    Spacer()
                    
                    Text("(\(processedFiles) of \(totalFiles))")
                        .font(.formaBody)
                        .foregroundColor(.formaObsidian.opacity(Color.FormaOpacity.high))
                }
            }
            
            SecondaryButton("Cancel", icon: "xmark") {
                onCancel()
            }
        }
        .padding(FormaSpacing.generous)
        .background(Color.formaControlBackground)
        .formaCornerRadius(FormaRadius.large)
        .shadow(
            color: Color.formaObsidian.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle),
            radius: FormaSpacing.generous,
            x: 0,
            y: FormaSpacing.tight
        )
        .frame(width: 400)
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
