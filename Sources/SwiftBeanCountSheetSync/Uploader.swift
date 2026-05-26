//
//  Uploader.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-13.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

#if os(macOS) || os(iOS)

import Foundation
import GoogleAuthentication
import SwiftBeanCountModel

/// Uploads transactions from the ledger to the sheet
public class Uploader: GenericSyncer, Syncer {

    public func start(authentication: Authentication, completion: @escaping (Result<SyncResult, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = readLedgerSettingsAndTransactions()
                .flatMap { ledgerTransactions, ledgerSettings in
                    self.uploadResult(
                        authentication: authentication,
                        ledgerTransactions: ledgerTransactions,
                        ledgerSettings: ledgerSettings
                    )
                }
            completion(result)
        }
    }

    private func uploadResult(
        authentication: Authentication,
        ledgerTransactions: [Transaction],
        ledgerSettings: LedgerSettings
    ) -> Result<SyncResult, Error> {
        let sheetTransactions = getTransactionsFromSheet(authentication: authentication, ledgerSettings: ledgerSettings)
        switch sheetTransactions {
        case .success(let sheetData):
            let scopedLedgerTransactions = isMonthlySheet(sheetData.transactions)
                ? ledgerTransactionForCorrectMonth(ledgerTransactions: ledgerTransactions, sheetTransactions: sheetData.transactions)
                : ledgerTransactions
            let filteredLedgerTransactions = removeExistingTransactions(from: scopedLedgerTransactions,
                                                                        existingTransactions: sheetData.transactions,
                                                                        ledgerSettings: ledgerSettings)
            do {
                let uploadData = try SheetCellsFormatter.buildUploadSheetCells(
                    syncer: self,
                    layout: sheetData.layout,
                    transactions: filteredLedgerTransactions,
                    ledgerSettings: ledgerSettings
                )
                return .success(SyncResult(mode: .upload,
                                           transactions: uploadData.transactions,
                                           parserErrors: sheetData.parserErrors + uploadData.errors,
                                           ledgerSettings: ledgerSettings,
                                           balance: sheetData.balance,
                                           sheetCells: uploadData.sheetCells))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    override func postingsMatch(
        transaction: SwiftBeanCountModel.Transaction,
        existingTransaction: SwiftBeanCountModel.Transaction,
        ledgerSettings: LedgerSettings
    ) -> Bool {
        super.postingsMatch(transaction: transaction, existingTransaction: existingTransaction, ledgerSettings: ledgerSettings)
            || (sharedAccountPosting(transaction, ledgerSettings: ledgerSettings) == nil
                    && ownAccountPosting(existingTransaction)?.amount == moneySpend(transaction, ledgerSettings: ledgerSettings))
    }

}

#endif
