//
//  Uploader.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-13.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import GoogleAuthentication
import SwiftBeanCountModel

/// Uploads transactions from the ledger to the sheet
public class Uploader: GenericSyncer, Syncer {

    public func start(authentication: Authentication, completion: @escaping (Result<SyncResult, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = readLedgerSettingsAndTransactions()
                .flatMap { ledgerTransactions, ledgerSettings -> Result<SyncResult, Error> in
                    let sheetTransactions = getTransactionsFromSheet(authentication: authentication, ledgerSettings: ledgerSettings)
                    switch sheetTransactions {
                    case .success(let (sheetTransactions, sheetParserErrors)):
                        var filteredLedgerTransactions = ledgerTransactionForCorrectMonth(ledgerTransactions: ledgerTransactions, sheetTransactions: sheetTransactions)
                        filteredLedgerTransactions = removeExistingTransactions(from: filteredLedgerTransactions,
                                                                                existingTransactions: sheetTransactions,
                                                                                ledgerSettings: ledgerSettings)
                        return .success(SyncResult(mode: .upload,
                                                   transactions: filteredLedgerTransactions,
                                                   parserErrors: sheetParserErrors,
                                                   ledgerSettings: ledgerSettings))
                    case .failure(let error):
                        return .failure(error)
                    }
                }
            completion(result)
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
