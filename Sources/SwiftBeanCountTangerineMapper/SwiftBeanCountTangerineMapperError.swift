import Foundation

/// Errors which can happen when using SwiftBeanCountTangerineMapper
public enum SwiftBeanCountTangerineMapperError: Error, Equatable {
    /// Account not found in ledger
    case missingAccount(account: String)
    /// invalid date in parsed transaction
    case invalidDate(date: String)
}

extension SwiftBeanCountTangerineMapperError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .missingAccount(account):
            return "Missing account in ledger: \(account)"
        case let .invalidDate(date):
            return "Found invalid date in parsed transaction: \(date)"
        }
    }
}
