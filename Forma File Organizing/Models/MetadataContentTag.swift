import Foundation

enum MetadataContentTag: String, CaseIterable, Hashable, Sendable {
    case screenshot
    case invoice
    case receipt
    case contract
    case statement
    case presentation

    var displayName: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .invoice: return "Invoice"
        case .receipt: return "Receipt"
        case .contract: return "Contract"
        case .statement: return "Statement"
        case .presentation: return "Presentation"
        }
    }
}
