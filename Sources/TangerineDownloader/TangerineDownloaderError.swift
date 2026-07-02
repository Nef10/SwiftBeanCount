import Foundation

/// Errors which can happen when using TangerineDownloadImporter
public enum TangerineDownloaderError: Error {
    /// no proper response from the accounts API
    case accountsLoadingFailed
    /// no proper response from the transaction API
    case transactionLoadingFailed
}

extension TangerineDownloaderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .accountsLoadingFailed:
            return "Could not parse the accounts from the server"
        case .transactionLoadingFailed:
            return "Could not parse the transactions from the server"
        }
    }
}
