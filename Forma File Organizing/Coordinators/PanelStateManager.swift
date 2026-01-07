import Foundation
import SwiftUI
import Combine

/// Manages UI panel visibility and state (right panel modes, bulk edit sheets, QuickLook, etc.)
///
/// # Right Panel State Machine
/// ```
/// ┌─────────────────────────────────────────────────────────────────────┐
/// │                        RightPanelMode                               │
/// │                                                                     │
/// │   ┌──────────┐  selection  ┌───────────┐                           │
/// │   │ .default │ ──────────▶ │.inspector │ ◀─────────────┐           │
/// │   └──────────┘             └───────────┘               │           │
/// │        ▲                         │                     │           │
/// │        │ clear selection         │ clear selection     │           │
/// │        │                         ▼                     │           │
/// │        └────────────────────────────                   │           │
/// │                                                        │           │
/// │   ┌────────────┐  "New Rule" button                    │           │
/// │   │.ruleBuilder│ ◀──────────────────────────────────────           │
/// │   └────────────┘                                                   │
/// │        │ save/cancel                                               │
/// │        └──────────▶ .default                                       │
/// │                                                                     │
/// │   ┌─────────────┐  batch organize success                          │
/// │   │.celebration │ ◀─────────────────────────────────────           │
/// │   └─────────────┘                                                   │
/// │        │ auto-dismiss (3s)                                          │
/// │        └──────────▶ .default                                       │
/// └─────────────────────────────────────────────────────────────────────┘
/// ```
///
/// # Sheet States (Independent, Modal)
/// - `showBulkEditSheet`: Bulk destination editing modal
/// - `showFailedFilesSheet`: Display files that failed during operation
/// - `showQuickLookSheet`: macOS QuickLook preview
/// - `showClustersView`: Project cluster detection results
///
/// # Transition Rules
/// - Celebration mode blocks inspector transitions (priority mode)
/// - RuleBuilder controls its own lifecycle (explicit dismiss)
/// - Inspector transitions automatically on selection changes
/// - Sheets are independent and can overlay any panel mode
@MainActor
class PanelStateManager: ObservableObject {
    // MARK: - Types
    
    enum RightPanelMode: Equatable {
        case `default`
        case inspector([FileItem])
        case ruleBuilder(editingRule: Rule?, fileContext: FileItem?)
        case celebration(String)
        case completionCelebration(filesOrganized: Int)  // Special celebration when ALL files are cleared
        case analytics

        static func == (lhs: RightPanelMode, rhs: RightPanelMode) -> Bool {
            switch (lhs, rhs) {
        case (.default, .default):
            return true
        case (.inspector(let lFiles), .inspector(let rFiles)):
            return lFiles.map { $0.path } == rFiles.map { $0.path }
        case (.ruleBuilder(let lRule, let lFile), .ruleBuilder(let rRule, let rFile)):
            return lRule?.id == rRule?.id && lFile?.path == rFile?.path
        case (.celebration(let lMsg), .celebration(let rMsg)):
            return lMsg == rMsg
        case (.completionCelebration(let lCount), .completionCelebration(let rCount)):
            return lCount == rCount
        case (.analytics, .analytics):
            return true
        default:
            return false
            }
        }
    }
    
    struct ToastState {
        var message: String
        var canUndo: Bool
        var isVisible: Bool
        var isError: Bool = false
        var action: (() -> Void)?
    }
    
    // MARK: - Published State
    
    /// Current right panel mode
    @Published var rightPanelMode: RightPanelMode = .default
    
    /// Whether bulk edit sheet is shown
    @Published var showBulkEditSheet: Bool = false

    /// Failed files sheet state
    @Published var showFailedFilesSheet: Bool = false
    @Published var lastBatchFailedFiles: [FileItem] = []

    /// QuickLook state
    @Published var quickLookURL: URL?
    @Published var showQuickLookSheet: Bool = false
    
    /// Toast notification state
    @Published var toastState: ToastState?
    
    /// File currently being edited for destination
    @Published var editingDestinationFile: FileItem?
    
    /// Cluster detection state
    @Published var detectedClusters: [ProjectCluster] = []
    @Published var showClustersView: Bool = false
    @Published var isDetectingClusters: Bool = false
    
    // MARK: - Configuration
    
    private static let celebrationDismissDelay = FormaConfig.Timing.celebrationDurationSec
    
    // MARK: - Right Panel Management
    
    /// Update right panel mode based on selection
    func updateRightPanelForSelection(_ selectedFiles: [FileItem]) {
        if !selectedFiles.isEmpty {
            // When a celebration is showing, keep it visible even if the user
            // clicks on files. The celebration panel has higher priority and
            // will auto-dismiss after a short delay.
            if case .celebration = rightPanelMode {
                return
            }
            rightPanelMode = .inspector(selectedFiles)
        } else {
            // Return to default only if we were previously showing the inspector.
            // Other special modes (celebration, rule builder) control their own
            // lifecycle.
            if case .inspector = rightPanelMode {
                rightPanelMode = .default
            }
        }
    }
    
    /// Show rule builder panel
    func showRuleBuilderPanel(editingRule: Rule? = nil, fileContext: FileItem? = nil) {
        rightPanelMode = .ruleBuilder(editingRule: editingRule, fileContext: fileContext)
    }
    
    /// Show celebration panel with auto-dismiss
    func showCelebrationPanel(message: String) {
        rightPanelMode = .celebration(message)

        // Auto-dismiss after configured delay
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.celebrationDismissDelay)
            guard let self else { return }
            if case .celebration(let msg) = self.rightPanelMode, msg == message {
                self.rightPanelMode = .default
            }
        }
    }

    /// Show completion celebration panel (special celebration when ALL files are cleared)
    /// This uses a longer dismiss delay since it's a bigger accomplishment
    func showCompletionCelebrationPanel(filesOrganized: Int) {
        rightPanelMode = .completionCelebration(filesOrganized: filesOrganized)

        // Auto-dismiss after longer delay (this is a bigger accomplishment!)
        let completionDelay = Self.celebrationDismissDelay * 2  // Double the standard duration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: completionDelay)
            guard let self else { return }
            if case .completionCelebration = self.rightPanelMode {
                self.rightPanelMode = .default
            }
        }
    }
    
    /// Return to default panel
    func returnToDefaultPanel() {
        rightPanelMode = .default
    }
    
    // MARK: - Toast Management
    
    /// Show a success toast
    func showToast(message: String, canUndo: Bool, undoAction: (() -> Void)? = nil) {
        toastState = ToastState(
            message: message,
            canUndo: canUndo,
            isVisible: true,
            action: canUndo ? undoAction : nil
        )
    }
    
    /// Show an error toast
    func showErrorToast(_ message: String) {
        toastState = ToastState(
            message: message,
            canUndo: false,
            isVisible: true,
            isError: true,
            action: nil
        )
    }
    
    /// Dismiss current toast
    func dismissToast() {
        toastState = nil
    }
    
    // MARK: - QuickLook Management
    
    /// Show QuickLook for a file
    func showQuickLook(for file: FileItem, errorHandler: @escaping (String) -> Void) {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: file.path) else {
            errorHandler("File not found: \(file.name)")
            return
        }
        
        // Ensure proper file:// URL format
        let fileURL = URL(fileURLWithPath: file.path)
        quickLookURL = fileURL
        showQuickLookSheet = true
    }
    
    /// Dismiss QuickLook
    func dismissQuickLook() {
        showQuickLookSheet = false
        quickLookURL = nil
    }
    
    // MARK: - Destination Editing
    
    /// Begin editing destination for a file
    func beginEditingDestination(for file: FileItem) {
        editingDestinationFile = file
    }
    
    /// Update destination for a file using unified Destination type
    func updateDestination(for file: FileItem, to newDestination: Destination) {
        file.destination = newDestination
    }
    
    /// End destination editing
    func endEditingDestination() {
        editingDestinationFile = nil
    }
    
    // MARK: - Sheet Management

    /// Show bulk edit sheet
    func showBulkEdit() {
        showBulkEditSheet = true
    }

    /// Dismiss bulk edit sheet
    func dismissBulkEdit() {
        showBulkEditSheet = false
    }

    /// Show failed files sheet with the given files
    func showFailedFiles(_ files: [FileItem]) {
        lastBatchFailedFiles = files
        showFailedFilesSheet = true
    }

    /// Dismiss failed files sheet
    func dismissFailedFiles() {
        showFailedFilesSheet = false
        // Clear the list after a short delay to allow animation
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.lastBatchFailedFiles = []
        }
    }

    /// Dismiss all sheets (useful for clean state resets)
    func dismissAllSheets() {
        showBulkEditSheet = false
        showFailedFilesSheet = false
        showQuickLookSheet = false
        showClustersView = false
        quickLookURL = nil
        editingDestinationFile = nil
    }

    // MARK: - Clusters

    /// Show clusters view
    func showClusters(_ clusters: [ProjectCluster]) {
        detectedClusters = clusters
        showClustersView = true
    }

    /// Hide clusters view
    func hideClusters() {
        showClustersView = false
    }
}
