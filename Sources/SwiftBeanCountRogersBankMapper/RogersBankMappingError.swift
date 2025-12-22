import Foundation
import RogersBankDownloader

/// Error while mapping the downloaded data into BeanCount format
public enum RogersBankMappingError: Error {
    /// An account with the given last 4 digits was not found
    case missingAccount(lastFour: String)
    /// Missing data on a downloaded transaction
    case missingActivityData(activity: Activity, key: String)

}

extension RogersBankMappingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .missingAccount(lastFour): // swiftlint:disable:next line_length
            return "The account with the last four digits \(lastFour) was not found in your ledger. Please make sure you add \(MetaDataKeys.importerType): \"\(MetaDataKeys.importerTypeValue)\" and \(MetaDataKeys.lastFour): \"\(lastFour)\" to it."
        case let .missingActivityData(activity: activity, key: key):
            return "A downloaded activty ist missing \(key) data: \(activity)"
        }
    }
}
