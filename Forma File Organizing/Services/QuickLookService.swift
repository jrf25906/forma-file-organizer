import Foundation
import AppKit
import Quartz

/// Service responsible for presenting Quick Look for files.
@MainActor
final class QuickLookService: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookService()
    
    private var currentURL: URL?
    
    // MARK: - Public API
    func previewFile(at url: URL) {
        currentURL = url
        guard QLPreviewPanel.shared().isVisible else {
            QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
            QLPreviewPanel.shared().dataSource = self
            QLPreviewPanel.shared().delegate = self
            return
        }
        QLPreviewPanel.shared().reloadData()
    }
    
    // MARK: - QLPreviewPanelDataSource
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        currentURL == nil ? 0 : 1
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return currentURL as NSURL?
    }
}