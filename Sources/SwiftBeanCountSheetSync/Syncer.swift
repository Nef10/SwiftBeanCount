//
//  Syncer.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-13.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
#if os(macOS) || os(iOS)
import GoogleAuthentication
#endif
import SwiftBeanCountModel
import SwiftBeanCountParser

/// Which way the sync is done
public enum SyncMode {
    /// Sync entries from the sheet into the ledger
    case download
    /// Sync new entries from the ledger to the sheet
    case upload
}

enum SyncError: LocalizedError, Equatable {
    case unknowError
    case missingSetting(String)
    case invalidSetting(String, String)
    case missingSheetLayout
    case missingOtherPersonName
    case unableToFormatTransaction(String)

    public var errorDescription: String? {
        switch self {
        case .missingSetting(let settingsName):
            return "Missing setting in your ledger: \(settingsName)"
        case let .invalidSetting(settingsName, settingsValue):
            return "Invalid setting in your ledger: \(settingsValue) is invalid for \(settingsName)"
        case .missingSheetLayout:
            return "Unable to determine the sheet format from the downloaded sheet"
        case .missingOtherPersonName:
            return "Unable to determine the other person's name from the sheet"
        case .unableToFormatTransaction(let message):
            return "Unable to format transaction for the sheet: \(message)"
        case .unknowError:
            return "An unknown Error occured"
        }
    }
}

/// Intermediate result grouping the output of downloading and parsing a sheet.
///
/// Avoids a three-element tuple return type and keeps the sync pipeline readable.
struct SheetParsedData {
    let rows: [SheetCellsFormatter.ParsedRow]
    let runningTotal: Decimal?
    let parserErrors: [SheetParserError]
    let layout: SheetCellsFormatter.Layout?
}

/// Intermediate result grouping the converted model transactions and related metadata.
///
/// Avoids a three-element tuple return type and keeps the sync pipeline readable.
struct SheetTransactionData {
    let transactions: [Transaction]
    let rows: [SheetCellsFormatter.MappedRow]
    let balance: Balance?
    let parserErrors: [SheetParserError]
    let layout: SheetCellsFormatter.Layout?
}

/// Result of the syncronization
public struct SyncResult {

    /// Mode in which the syncronization was performed
    public let mode: SyncMode
    /// Transactions which need to be added
    public let transactions: [Transaction]
    /// Errors collected while preparing the sync result, including unreadable sheet rows and unformattable upload rows
    public let parserErrors: [SheetParserError]
    /// Settings for the syncronization read from the ledger
    public let ledgerSettings: LedgerSettings
    /// Balance assertion derived from the sheet's `Running Total` column, or `nil` if that column is absent.
    public let balance: Balance?
    /// Sheet-shaped cells representing the synced rows, including the header row as the first entry.
    public let sheetCells: [[String]]

    /// Creates the syncroization result
    /// - Parameters:
    ///   - mode: Mode in which the syncronization was performed
    ///   - transactions: Transactions which need to be added
    ///   - parserErrors: Errors collected while preparing the sync result, including unreadable sheet rows and unformattable upload rows
    ///   - ledgerSettings: Settings for the syncronization read from the ledger
    ///   - balance: Balance assertion from the sheet's Running Total, if present
    ///   - sheetCells: Sheet-shaped rows representing the synced transactions, with the header row first
    public init(
        mode: SyncMode,
        transactions: [Transaction],
        parserErrors: [SheetParserError],
        ledgerSettings: LedgerSettings,
        balance: Balance? = nil,
        sheetCells: [[String]] = []
    ) {
        self.mode = mode
        self.transactions = transactions
        self.parserErrors = parserErrors
        self.ledgerSettings = ledgerSettings
        self.balance = balance
        self.sheetCells = sheetCells
    }
}

#if os(macOS) || os(iOS)

/// Base class with helpers for specific syncers
///
/// Not for initialization, just as base class
public class GenericSyncer {

    private enum LedgerInput {
        case url(URL)
        case ledger(Ledger)
    }

    private let sheetURL: String
    private let ledgerInput: LedgerInput

    /// Creates a new Syncer
    /// - Parameters:
    ///   - sheetURL: HTTP URL of the Google sheet
    ///   - ledgerURL: File URL of the ledger file
    public required init(sheetURL: String, ledgerURL: URL) {
        self.sheetURL = sheetURL
        self.ledgerInput = .url(ledgerURL)
    }

    /// Creates a new Syncer
    /// - Parameters:
    ///   - sheetURL: HTTP URL of the Google sheet
    ///   - ledger: Ledger
    public required init(sheetURL: String, ledger: Ledger) {
        self.sheetURL = sheetURL
        self.ledgerInput = .ledger(ledger)
    }

    /// Downloads the sheet, parses its rows, and converts them to model transactions.
    ///
    /// Delegates the download and parsing to `getTransactionDataFromSheet`, then maps
    /// the parsed data through `TransactionMapper` and builds an optional `Balance`
    /// assertion from the running total if a `Running Total` column is present.
    /// - Parameters:
    ///   - authentication: Authenticated Google session.
    ///   - ledgerSettings: Sync configuration providing the owner's name, account, and commodity.
    /// - Returns: A `SheetTransactionData` on success, or a `DownloaderError` on failure.
    func getTransactionsFromSheet(authentication: Authentication, ledgerSettings: LedgerSettings)
            -> Result<SheetTransactionData, SheetDownloader.DownloaderError> {
        getTransactionDataFromSheet(authentication: authentication, name: ledgerSettings.name, negateRunningTotal: ledgerSettings.negateRunningTotal)
            .flatMap { parsed in
                let transactionData = parsed.rows.map(\.transactionData)
                let sheetTransactions = TransactionMapper.mapDataToTransactions(transactionData, ledgerSettings: ledgerSettings)
                let mappedRows = Array(zip(sheetTransactions, parsed.rows).map {
                    SheetCellsFormatter.MappedRow(transaction: $0.0, rawRow: $0.1.rawRow)
                })
                let balance = buildBalance(runningTotal: parsed.runningTotal, transactions: sheetTransactions, ledgerSettings: ledgerSettings)
                return .success(SheetTransactionData(
                    transactions: sheetTransactions,
                    rows: mappedRows,
                    balance: balance,
                    parserErrors: parsed.parserErrors,
                    layout: parsed.layout
                ))
            }
    }

    /// Creates a `Balance` assertion from a running total if one is available.
    ///
    /// Uses the day after the last transaction and the configured account and commodity
    /// to construct the assertion so the balance applies after same-day transactions.
    /// - Parameters:
    ///   - runningTotal: The running total extracted from the sheet, or `nil` if absent.
    ///   - transactions: The mapped sheet transactions.
    ///   - ledgerSettings: Sync configuration providing account name and commodity symbol.
    /// - Returns: A `Balance` if both `runningTotal` and at least one transaction exist; otherwise `nil`.
    private func buildBalance(runningTotal: Decimal?, transactions: [Transaction], ledgerSettings: LedgerSettings) -> Balance? {
        guard let runningTotal,
              let lastTransaction = transactions.last
        else {
            return nil
        }
        let amount = Amount(number: runningTotal, commoditySymbol: ledgerSettings.commoditySymbol, decimalDigits: 2)
        return Balance(
            date: balanceDate(after: lastTransaction.metaData.date),
            accountName: ledgerSettings.accountName,
            amount: amount
        )
    }

    func balanceDate(after transactionDate: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(byAdding: .day, value: 1, to: transactionDate) ?? transactionDate
    }

    /// Determines whether the sheet behaves as a single-month sheet for **upload** purposes.
    ///
    /// Returns `true` when 90% or more of the transactions fall in the same calendar
    /// month, in which case only ledger transactions from that month are candidates for
    /// upload. Returns `true` for empty or single-transaction sheets.
    ///
    /// Download is not affected by this heuristic — all sheet transactions are always
    /// compared against the full ledger regardless of the result.
    ///
    /// This check is independent of the column format used in the sheet: both total amount
    /// and share amount formats can be monthly or long-running.
    /// - Parameter transactions: The transactions parsed from the sheet.
    /// - Returns: `true` if the sheet is treated as monthly; `false` if it spans multiple months.
    func isMonthlySheet(_ transactions: [Transaction]) -> Bool {
        guard transactions.count >= 2
        else {
            return true
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var monthCounts = [DateComponents: Int]()
        for transaction in transactions {
            let components = calendar.dateComponents([.year, .month], from: transaction.metaData.date)
            monthCounts[components, default: 0] += 1
        }
        let maxCount = monthCounts.values.max() ?? 0
        return Double(maxCount) / Double(transactions.count) >= 0.9
    }

    func readLedgerSettingsAndTransactions() -> Result<([Transaction], LedgerSettings), Error> {
        switch ledgerInput {
        case .url(let ledgerURL):
            return LedgerReader.readLedger(from: ledgerURL).flatMap { ledger -> Result<([Transaction], LedgerSettings), Error> in
                LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)
            }

        case .ledger(let ledger):
            return LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)
        }
    }

    func ledgerTransactionForCorrectMonth(ledgerTransactions: [Transaction], sheetTransactions: [Transaction]) -> [Transaction] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var monthCounts = [DateComponents: Int]()
        for transaction in sheetTransactions {
            let components = calendar.dateComponents([.year, .month], from: transaction.metaData.date)
            monthCounts[components, default: 0] += 1
        }
        let month = monthCounts.max { $0.value < $1.value }?.key
        let date = month.flatMap(calendar.date(from:)) ?? Date()
        return ledgerTransactions.filter {
            calendar.isDate(date, equalTo: $0.metaData.date, toGranularity: .month)
        }
    }

    func removeExistingTransactions(from transactions: [Transaction], existingTransactions: [Transaction], ledgerSettings: LedgerSettings) -> [Transaction] {
        transactions.filter { transaction in
            !matchesExistingTransaction(transaction, existingTransactions: existingTransactions, ledgerSettings: ledgerSettings)
        }
    }

    func removeExistingRows(
        from rows: [SheetCellsFormatter.MappedRow],
        existingTransactions: [Transaction],
        ledgerSettings: LedgerSettings
    ) -> [SheetCellsFormatter.MappedRow] {
        rows.filter { row in
            !matchesExistingTransaction(row.transaction, existingTransactions: existingTransactions, ledgerSettings: ledgerSettings)
        }
    }

    func postingsMatch(
            transaction: SwiftBeanCountModel.Transaction,
            existingTransaction: SwiftBeanCountModel.Transaction,
            ledgerSettings: LedgerSettings
    ) -> Bool {
        guard let sharedAmount = sharedAccountPosting(transaction, ledgerSettings: ledgerSettings)?.amount else {
            return false
        }
        return existingTransaction.postings.contains { $0.accountName == ledgerSettings.accountName && $0.amount == sharedAmount }
    }

    func sharedAccountPosting(_ transaction: SwiftBeanCountModel.Transaction, ledgerSettings: LedgerSettings) -> Posting? {
        transaction.postings.first { $0.accountName == ledgerSettings.accountName }
    }

    func ownAccountPosting(_ transaction: SwiftBeanCountModel.Transaction) -> Posting? {
        transaction.postings.first { $0.accountName == LedgerSettings.ownAccountName }
    }

    func moneySpend(_ transaction: SwiftBeanCountModel.Transaction, ledgerSettings: LedgerSettings) -> Amount? {
        let multiCurrencyAmount: MultiCurrencyAmount = transaction.postings.compactMap {
            ($0.accountName.accountType == .asset || $0.accountName.accountType == .liability) ? $0.amount.multiCurrencyAmount : nil
        }
        .reduce(MultiCurrencyAmount(), +)
        return multiCurrencyAmount.amountFor(symbol: ledgerSettings.commoditySymbol)
    }

    /// Returns `true` when the sheet transaction's payment amount matches the ledger transaction.
    ///
    /// Accepts an exact match (total amount format) or a share amount format match, where the
    /// sheet derives the total as `2 × shareOtherPerson` but the actual ledger total may differ.
    /// In the share format case the method verifies that the share amount is covered by the actual
    /// total and that the commodities agree.
    /// - Parameters:
    ///   - transaction: The sheet-derived transaction being merged.
    ///   - ledgerTransaction: The unreconciled ledger transaction to match against.
    ///   - ledgerSettings: Sync configuration providing account names and commodity.
    /// - Returns: `true` if the transactions are a payment match; `false` otherwise.
    func paymentMatches(transaction: Transaction, ledgerTransaction: Transaction, ledgerSettings: LedgerSettings) -> Bool {
        if ownAccountPosting(transaction)?.amount == moneySpend(ledgerTransaction, ledgerSettings: ledgerSettings) {
            return true
        }
        guard let sharedPosting = sharedAccountPosting(transaction, ledgerSettings: ledgerSettings),
              let ownPosting = ownAccountPosting(transaction),
              let spend = moneySpend(ledgerTransaction, ledgerSettings: ledgerSettings),
              ownPosting.amount.number == -(sharedPosting.amount.number * 2),
              sharedPosting.amount.number > 0,
              sharedPosting.amount.commoditySymbol == spend.commoditySymbol
        else {
            return false
        }
        return sharedPosting.amount.number <= abs(spend.number)
    }

    private func matchesExistingTransaction(
        _ transaction: Transaction,
        existingTransactions: [Transaction],
        ledgerSettings: LedgerSettings
    ) -> Bool {
        existingTransactions.contains { existingTransaction in
            transaction.metaData.payee.caseInsensitiveCompare(existingTransaction.metaData.payee) == .orderedSame
                && postingsMatch(transaction: transaction, existingTransaction: existingTransaction, ledgerSettings: ledgerSettings)
                && transaction.metaData.date + ledgerSettings.dateTolerance >= existingTransaction.metaData.date
                && transaction.metaData.date - ledgerSettings.dateTolerance <= existingTransaction.metaData.date
        }
    }

    /// Downloads the raw sheet data and parses it into transaction data using `SheetParser`.
    ///
    /// Blocks the calling thread using a semaphore until the asynchronous download
    /// and parse operations complete.
    /// - Parameters:
    ///   - authentication: Authenticated Google session.
    ///   - name: The ledger owner's name, forwarded to `SheetParser`.
    ///   - negateRunningTotal: Whether to negate the running total, forwarded to `SheetParser`.
    /// - Returns: A `SheetParsedData` on success, or a `DownloaderError` on failure.
    private func getTransactionDataFromSheet(authentication: Authentication, name: String, negateRunningTotal: Bool)
            -> Result<SheetParsedData, SheetDownloader.DownloaderError> {
        var result: Result<SheetParsedData, SheetDownloader.DownloaderError>!
        let semaphore = DispatchSemaphore(value: 0)

        SheetDownloader.download(authentication: authentication, url: sheetURL) {
            switch $0 {
            case .success(let data):
                let parsed = SheetParser.parseSheetData(data, name: name, negateRunningTotal: negateRunningTotal)
                result = .success(SheetParsedData(rows: parsed.rows, runningTotal: parsed.runningTotal, parserErrors: parsed.errors, layout: parsed.layout))
                semaphore.signal()
            case .failure(let error):
                result = .failure(error)
                semaphore.signal()
            }
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
        return result
    }

}

/// Syncer which can sync transactions between the sheet and ledger
public protocol Syncer: GenericSyncer {

    /// Start the sync process
    /// - Parameters:
    ///   - authentication: valid authentication for the Google Sheet API
    ///   - completion: result of the sync
    func start(authentication: Authentication, completion: @escaping (Result<SyncResult, Error>) -> Void)
}

#endif
