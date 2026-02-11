//
//  WealthsimpleLedgerMapper+Helpers.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by GitHub Copilot on 2026-02-11.
//

import Foundation
import SwiftBeanCountModel
import Wealthsimple

// MARK: - Helper Methods for Transaction Processing

extension WealthsimpleLedgerMapper {

    func processRegularTransactions(_ regular: [WTransaction], nrwt: [WTransaction]) throws -> RegularTransactionsResult {
        var prices = [Price](), transactions = [STransaction]()
        var mergedNRWTIds = Set<String>()
        let regularByAccount = Dictionary(grouping: regular) { $0.accountId }
        for (accountId, accountTransactions) in regularByAccount {
            guard let account = accounts.first(where: { $0.id == accountId }) else {
                throw WealthsimpleConversionError.accountNotFound(accountId)
            }
            var nrwtTransactions = nrwt.filter { $0.accountId == accountId }
            let originalNRWTCount = nrwtTransactions.count
            let (accountPrices, accountTx) = try mapRegularTransactions(accountTransactions, nrwtTransactions: &nrwtTransactions, in: account)
            // Track which NRWT transactions were merged (removed from the list)
            let mergedCount = originalNRWTCount - nrwtTransactions.count
            if mergedCount > 0 {
                let accountNRWT = nrwt.filter { $0.accountId == accountId }
                let remainingIds = Set(nrwtTransactions.map(\.id))
                for transaction in accountNRWT where !remainingIds.contains(transaction.id) {
                    mergedNRWTIds.insert(transaction.id)
                }
            }
            prices.append(contentsOf: accountPrices)
            transactions.append(contentsOf: accountTx)
        }
        return RegularTransactionsResult(prices: prices, transactions: transactions, mergedNRWTIds: mergedNRWTIds)
    }

    func processNRWTTransactions(_ nrwt: [WTransaction]) throws -> [STransaction] {
        var transactions = [STransaction]()
        let nrwtByAccount = Dictionary(grouping: nrwt) { $0.accountId }
        for (accountId, accountNRWT) in nrwtByAccount {
            guard let account = accounts.first(where: { $0.id == accountId }) else {
                throw WealthsimpleConversionError.accountNotFound(accountId)
            }
            transactions.append(contentsOf: try accountNRWT.map { try mapNonResidentWithholdingTax($0, in: account) }
                .filter { !lookup.doesTransactionExistInLedger($0) })
        }
        return transactions
    }

    func processStockSplits(_ stockSplits: [WTransaction]) throws -> [STransaction] {
        var transactions = [STransaction]()
        let stockSplitsByAccount = Dictionary(grouping: stockSplits) { $0.accountId }
        for (accountId, accountStockSplits) in stockSplitsByAccount {
            guard let account = accounts.first(where: { $0.id == accountId }) else {
                throw WealthsimpleConversionError.accountNotFound(accountId)
            }
            transactions.append(contentsOf: try mapStockSplits(accountStockSplits, in: account).filter { !lookup.doesTransactionExistInLedger($0) })
        }
        return transactions
    }

    func processCashback(_ cashback: [WTransaction]) throws -> [STransaction] {
        var transactions = [STransaction]()
        let cashbackByAccount = Dictionary(grouping: cashback) { $0.accountId }
        for (accountId, accountCashback) in cashbackByAccount {
            guard let account = accounts.first(where: { $0.id == accountId }) else {
                throw WealthsimpleConversionError.accountNotFound(accountId)
            }
            transactions.append(contentsOf: try mergeCashbackTransactions(accountCashback, in: account)
                .filter { !lookup.doesTransactionExistInLedger($0) })
        }
        return transactions
    }

    func tryMergeTransferPair(_ group: [WTransaction]) -> STransaction? {
        let transferIn = group.filter { $0.transactionType == .transferIn }
        let transferOut = group.filter { $0.transactionType == .transferOut }
        guard transferIn.count == 1 && transferOut.count == 1,
              let inTransaction = transferIn.first,
              let outTransaction = transferOut.first,
              accountsMatchDescription(inTransaction: inTransaction, outTransaction: outTransaction),
              let inAccount = accounts.first(where: { $0.id == inTransaction.accountId }),
              let (_, result) = try? mapTransaction(inTransaction, in: inAccount), let result else {
            return nil
        }
        var ids = result.metaData.metaData
        ids[MetaDataKeys.id] = group.map(\.id).sorted().joined(separator: " ")
        let meta = TransactionMetaData(
            date: result.metaData.date, payee: result.metaData.payee, narration: result.metaData.narration, metaData: ids
        )
        return STransaction(metaData: meta, postings: result.postings)
    }

    func mapTransfersIndividually(_ group: [WTransaction]) -> [STransaction] {
        group.compactMap { transaction in
            guard let account = accounts.first(where: { $0.id == transaction.accountId }),
                  let (_, result) = try? mapTransaction(transaction, in: account), let result else {
                return nil
            }
            return result
        }
    }

    func accountsMatchDescription(inTransaction: WTransaction, outTransaction: WTransaction) -> Bool {
        guard let inAccount = accounts.first(where: { $0.id == inTransaction.accountId }),
              let outAccount = accounts.first(where: { $0.id == outTransaction.accountId }) else {
            return false
        }
        let description = inTransaction.description
        return description.contains(inAccount.number) && description.contains(outAccount.number)
    }

}
