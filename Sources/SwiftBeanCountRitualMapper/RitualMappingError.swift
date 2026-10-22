import Foundation

/// Configuration, financial reconciliation or duplicate-matching failure.
public enum RitualMappingError: LocalizedError, Equatable {
    /// Each required role must identify exactly one appropriate CAD account.
    case invalidRole(String)
    /// Invalid financial or description data in a receipt.
    case invalidReceipt(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRole(let role):
            return "Configure exactly one CAD account with ritual-role: \"\(role)\" and the correct account type."
        case .invalidReceipt(let receipt):
            return "Ritual receipt could not be reconciled: \(receipt)"
        }
    }
}
