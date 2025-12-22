import Foundation

/// Errors which can happen when using SwiftBeanCountCompassCardMapper
public enum SwiftBeanCountCompassCardMapperError: Error, Equatable {
    /// Account for the Compass Card not found in ledger
    case missingAccount(cardNumber: String)
}

extension SwiftBeanCountCompassCardMapperError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .missingAccount(cardNumber):
            return "Missing account in ledger for compass card: \(cardNumber). Make sure to add importer-type: \"compass-card\" and card-number: \"\(cardNumber)\" to it."
        }
    }
}
