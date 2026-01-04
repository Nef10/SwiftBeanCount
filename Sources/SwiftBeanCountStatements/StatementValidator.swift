//
//  StatementValidator.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-11-11.
//

import Foundation
import SwiftBeanCountModel

/// Result of the validation of an account
public struct AccountResult: Hashable, Identifiable {
    /// unique ID
    public let id = UUID()
    /// Results for the individial statements found
    public let statementResults: [StatementResult]
    /// Readable name of the folder with the statements. Does include the last path item of the root folder
    public let folderName: String
    /// Full URL of the folder with the statements
    public let folderURL: URL
}

/// Validates all statements are present in the file system based on meta data in a ledger
public enum StatementValidator {

    private enum StatementValidatorKeys {
        static let settings = "statements-settings"
        static let rootFolder = "root-folder"
        static let fileNames = "file-names"
        static let folder = "folder"
        static let statements = "statements"
        static let disable = "disable"
    }

    /// Gets the root folder from a settings of a ledger
    /// - Parameter ledger: ledger to read
    /// - Returns: string with the root folder. Returns nil if none found
    public static func getRootFolder(from ledger: Ledger) throws -> String {
        let settings = ledger.custom.filter { $0.name == StatementValidatorKeys.settings && $0.values.first == StatementValidatorKeys.rootFolder }
        guard let result = settings.max(by: { $0.date > $1.date })?.values[1] else {
            throw StatementValidatorError.noRootFolder
        }
        return result
    }

    /// Validates all account in a ledger
    /// - Parameters:
    ///   - ledger: ledger to get accounts and meta data from
    ///   - securityScopedRootURL: correctly security scoped root URL. Retrive the security URL with getRootFolder first, get the security scope and then pass it in.
    ///   - includeClosedAccounts: if accounts already closed in the ledger should be included in the result
    ///   - includeStartEndDateWarning: if the account opening date from the ledger should be verified against the date of the earliest statement
    ///   - includeCurrentStatementWarning: if open accounts should be checked for a statement of the last closed period
    /// - Returns: Dictionary of AccountNames to the corresponding AccountResult
    public static func validate(
        _ ledger: Ledger,
        securityScopedRootURL: URL,
        includeClosedAccounts: Bool,
        includeStartEndDateWarning: Bool,
        includeCurrentStatementWarning: Bool
    ) async throws -> [AccountName: AccountResult] {
        var result = [AccountName: AccountResult]()
        let settings = ledger.custom.filter { $0.name == StatementValidatorKeys.settings && $0.values.first == StatementValidatorKeys.fileNames }
        let statementNames = settings.max { $0.date > $1.date }?.values[1].split(separator: " ").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        let accounts = ledger.accounts.filter {
            $0.metaData[StatementValidatorKeys.folder] != nil && $0.metaData[StatementValidatorKeys.statements] != StatementValidatorKeys.disable
        }
        for account in accounts {
            guard includeClosedAccounts || account.closing == nil else {
                continue
            }
            let url = URL(filePath: account.metaData[StatementValidatorKeys.folder]!, directoryHint: .isDirectory, relativeTo: securityScopedRootURL)
            var statementResults = try await StatementFileValidator.checkStatementsFrom(folder: url, statementNames: statementNames)
            if includeStartEndDateWarning {
                statementResults = statementResults.map { AccountStartEndDateValidator.validate(account, result: $0) }
            }
            if includeCurrentStatementWarning {
                statementResults = statementResults.map { LatestStatementValidator.validate(account, result: $0) }
            }
            result[account.name] = AccountResult(statementResults: statementResults,
                                                 folderName: "\(securityScopedRootURL.lastPathComponent)/\(account.metaData[StatementValidatorKeys.folder]!)",
                                                 folderURL: url)
        }
        return result
    }

}
