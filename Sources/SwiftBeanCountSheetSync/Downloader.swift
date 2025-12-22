//
//  Downloader.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-13.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

#if os(macOS) || os(iOS)

import Foundation
import GoogleAuthentication
import SwiftBeanCountModel

/// Downloads transactions from the Sheet and merges them into transactions in the ledgers
public class Downloader: GenericSyncer, Syncer {

    public func start(authentication: Authentication, completion: @escaping (Result<SyncResult, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = readLedgerSettingsAndTransactions()
                .flatMap { ledgerTransactions, ledgerSettings -> Result<SyncResult, Error> in
                    let sheetTransactions = getTransactionsFromSheet(authentication: authentication, ledgerSettings: ledgerSettings)
                    switch sheetTransactions {
                    case .success(let (sheetTransactions, sheetParserErrors)):
                        let filteredLedgerTransactions = ledgerTransactionForCorrectMonth(ledgerTransactions: ledgerTransactions, sheetTransactions: sheetTransactions)
                        let filteredSheetTransactions = removeExistingTransactions(from: sheetTransactions,
                                                                                   existingTransactions: filteredLedgerTransactions,
                                                                                   ledgerSettings: ledgerSettings)
                        let mergedTransactions = mergeExisting(transactions: filteredSheetTransactions, into: filteredLedgerTransactions, ledgerSettings: ledgerSettings)
                        return .success(SyncResult(mode: .download,
                                                   transactions: mergedTransactions,
                                                   parserErrors: sheetParserErrors,
                                                   ledgerSettings: ledgerSettings))
                    case .failure(let error):
                        return .failure(error)
                    }
                }
            completion(result)
        }
    }

    private func mergeExisting(transactions: [Transaction], into ledgerTransactions: [Transaction], ledgerSettings: LedgerSettings) -> [Transaction] {
        transactions.map { transaction -> Transaction in
            let ledgerTransactionMatch = ledgerTransactions.first { ledgerTransaction in
                transaction.metaData.payee == ledgerTransaction.metaData.payee
                    && transaction.metaData.date + ledgerSettings.dateTolerance >= ledgerTransaction.metaData.date
                    && transaction.metaData.date - ledgerSettings.dateTolerance <= ledgerTransaction.metaData.date
                    && sharedAccountPosting(ledgerTransaction, ledgerSettings: ledgerSettings) == nil
                    && ownAccountPosting(transaction)?.amount == moneySpend(ledgerTransaction, ledgerSettings: ledgerSettings)
            }
            guard let ledgerTransaction = ledgerTransactionMatch else {
                return transaction
            }
            return merge(sheetTransaction: transaction, into: ledgerTransaction, ledgerSettings: ledgerSettings)
        }
    }

    private func merge(sheetTransaction: Transaction, into ledgerTransaction: Transaction, ledgerSettings: LedgerSettings) -> Transaction {
        guard ledgerTransaction.postings.filter({ $0.accountName.accountType == .expense }).count == 1 else {
            return sheetTransaction
        }
        let sharedPosting = sharedAccountPosting(sheetTransaction, ledgerSettings: ledgerSettings)!
        let expensePosting = ledgerTransaction.postings.first { $0.accountName.accountType == .expense }!
        let newExpenseAmount = Amount(number: expensePosting.amount.number - sharedPosting.amount.number,
                                      commoditySymbol: expensePosting.amount.commoditySymbol,
                                      decimalDigits: expensePosting.amount.decimalDigits)
        let newExpensePosting = Posting(accountName: expensePosting.accountName, amount: newExpenseAmount, metaData: expensePosting.metaData)
        let untouchedPostings = ledgerTransaction.postings.filter { $0 != expensePosting }
        return Transaction(metaData: ledgerTransaction.metaData, postings: untouchedPostings + [newExpensePosting, sharedPosting])
    }

}

#endif
