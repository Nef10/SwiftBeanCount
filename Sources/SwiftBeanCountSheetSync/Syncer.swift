//
//  Syncer.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-13.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import GoogleAuthentication
import SwiftBeanCountModel
import SwiftBeanCountParser

/// Which way the sync is done
public enum SyncMode {
    /// Sync entries from the sheet into the ledger
    case download
    /// Sync new entries from the ledger to the sheet
    case upload
}

enum SyncError: LocalizedError {
    case unknowError
    case missingSetting(String)
    case invalidSetting(String, String)

    public var errorDescription: String? {
        switch self {
        case .missingSetting(let settingsName):
            return "Missing setting in your ledger: \(settingsName)"
        case let .invalidSetting(settingsName, settingsValue):
            return "Invalid setting in your ledger: \(settingsValue) is invalid for \(settingsName)"
        case .unknowError:
            return "An unknown Error occured"
        }
    }
}

/// Result of the syncronization
public struct SyncResult {
    /// Mode in which the syncronization was performed
    public let mode: SyncMode
    /// Transactions which need to be added
    public let transactions: [Transaction]
    /// Lines in the Sheet which could not be read
    public let parserErrors: [SheetParserError]
    /// Settings for the syncronization read from the ledger
    public let ledgerSettings: LedgerSettings
}

/// Base class with helpers for specific syncers
///
/// Not for initialization, just as base class
public class GenericSyncer {

    private let sheetURL: String
    private let ledgerURL: URL

    /// Creates a new Syncer
    /// - Parameters:
    ///   - sheetURL: HTTP URL of the Google sheet
    ///   - ledgerURL: File URL of the ledger file
    public required init(sheetURL: String, ledgerURL: URL) {
        self.sheetURL = sheetURL
        self.ledgerURL = ledgerURL
    }

    func getTransactionsFromSheet(authentication: Authentication, ledgerSettings: LedgerSettings)
            -> Result<([Transaction], [SheetParserError]), SheetDownloader.DownloaderError> {
        getTransactionDataFromSheet(authentication: authentication, name: ledgerSettings.name)
            .flatMap { sheetTransactionData, sheetParserErrors in
                let sheetTransactions = TransactionMapper.mapDataToTransactions(sheetTransactionData, ledgerSettings: ledgerSettings)
                return .success((sheetTransactions, sheetParserErrors))
            }
    }

    func readLedgerSettingsAndTransactions() -> Result<([Transaction], LedgerSettings), Error> {
        LedgerReader.readLedger(from: ledgerURL).flatMap { ledger -> Result<([Transaction], LedgerSettings), Error> in
            LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)
        }
    }

    func ledgerTransactionForCorrectMonth(ledgerTransactions: [Transaction], sheetTransactions: [Transaction]) -> [Transaction] {
        let date = sheetTransactions.first?.metaData.date ?? Date()
        return ledgerTransactions.filter {
            Calendar.current.isDate(date, equalTo: $0.metaData.date, toGranularity: .month)
        }
    }

    func removeExistingTransactions(from transactions: [Transaction], existingTransactions: [Transaction], ledgerSettings: LedgerSettings) -> [Transaction] {
        transactions.filter { transaction -> Bool in
            !existingTransactions.contains { existingTransaction -> Bool in
                transaction.metaData.payee == existingTransaction.metaData.payee
                    && postingsMatch(transaction: transaction, existingTransaction: existingTransaction, ledgerSettings: ledgerSettings)
                    && transaction.metaData.date + ledgerSettings.dateTolerance >= existingTransaction.metaData.date
                    && transaction.metaData.date - ledgerSettings.dateTolerance <= existingTransaction.metaData.date
            }
        }
    }

    func postingsMatch(
            transaction: SwiftBeanCountModel.Transaction,
            existingTransaction: SwiftBeanCountModel.Transaction,
            ledgerSettings: LedgerSettings
    ) -> Bool {
        sharedAccountPosting(transaction, ledgerSettings: ledgerSettings)?.amount == sharedAccountPosting(existingTransaction, ledgerSettings: ledgerSettings)?.amount
    }

    func sharedAccountPosting(_ transaction: SwiftBeanCountModel.Transaction, ledgerSettings: LedgerSettings) -> Posting? {
        transaction.postings.first { $0.accountName == ledgerSettings.accountName }
    }

    func ownAccountPosting(_ transaction: SwiftBeanCountModel.Transaction) -> Posting? {
        transaction.postings.first { $0.accountName == LedgerSettings.ownAccountName }
    }

    func moneySpend(_ transaction: SwiftBeanCountModel.Transaction, ledgerSettings: LedgerSettings) -> Amount? {
        let multiCurrencyAmount = transaction.postings.compactMap {
            ($0.accountName.accountType == .asset || $0.accountName.accountType == .liability) ? $0.amount.multiCurrencyAmount : nil
        }
        .reduce(MultiCurrencyAmount(), +)
        return multiCurrencyAmount.amountFor(symbol: ledgerSettings.commoditySymbol)
    }

    private func getTransactionDataFromSheet(authentication: Authentication, name: String)
            -> Result<([SheetParser.TransactionData], [SheetParserError]), SheetDownloader.DownloaderError> {
        var result: Result<([SheetParser.TransactionData], [SheetParserError]), SheetDownloader.DownloaderError>!
        let semaphore = DispatchSemaphore(value: 0)

        SheetDownloader.download(authentication: authentication, url: sheetURL) {
            switch $0 {
            case .success(let data):
                SheetParser.parseSheet(data, name: name) { transactionData, parserErrors in
                    result = .success((transactionData, parserErrors))
                    semaphore.signal()
                }
            case .failure(let error):
                result = .failure(error)
                semaphore.signal()
            }
        }
        _ = semaphore.wait(wallTimeout: .distantFuture)
       return result
    }

}

public protocol Syncer: GenericSyncer {
    func start(authentication: Authentication, completion: @escaping (Result<SyncResult, Error>) -> Void)
}
