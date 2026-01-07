import SwiftUI
import AppKit
import Quartz

/// SwiftUI wrapper for QuickLook preview on macOS
struct QuickLookPreview: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    
    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView(frame: .zero, style: .normal)
        previewView?.autostarts = true
        
        // Check if file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            DispatchQueue.main.async {
                errorMessage = "File not found at path"
                isLoading = false
            }
        }
        
        return previewView ?? QLPreviewView()
    }
    
    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        // Ensure file exists before setting preview item
        guard FileManager.default.fileExists(atPath: url.path) else {
            DispatchQueue.main.async {
                errorMessage = "File no longer exists"
                isLoading = false
            }
            return
        }
        
        nsView.previewItem = url as NSURL
        
        // Mark as loaded after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isLoading = false
        }
    }
}

/// Wrapper view that adds a toolbar for better UX
struct QuickLookSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(url.lastPathComponent)
                    .font(.formaBodySemibold)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }) {
                    Label("Show in Finder", systemImage: "folder")
                        .font(.formaBody)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.formaSecondaryLabel)
                        .font(.formaH2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.regularMaterial)
            
            // Preview content
            ZStack {
                if let error = errorMessage {
                    // Error state
                    VStack(spacing: FormaSpacing.standard) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.formaIcon)
                            .foregroundColor(.formaWarning)
                        
                        Text(error)
                            .font(.formaH3)
                            .foregroundColor(.formaSecondaryLabel)
                        
                        Text(url.path)
                            .font(.formaCaption)
                            .foregroundColor(.formaSecondaryLabel)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Close")
                                .frame(width: 100)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Preview
                    QuickLookPreview(url: url, isLoading: $isLoading, errorMessage: $errorMessage)
                    
                    // Loading overlay
                    if isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading preview...")
                                .font(.formaCaption)
                                .foregroundColor(.formaSecondaryLabel)
                                .padding(.top, FormaSpacing.tight)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    // For preview, use a sample file path
    let sampleURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns")
    QuickLookSheet(url: sampleURL)
}
