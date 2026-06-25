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

    func processCurrencyConversions(_ currencyConversions: [WTransaction]) throws -> [STransaction] {
        var transactions = [STransaction]()
        let conversionsByAccount = Dictionary(grouping: currencyConversions) { $0.accountId }
        for (accountId, accountConversions) in conversionsByAccount {
            guard let account = accounts.first(where: { $0.id == accountId }) else {
                throw WealthsimpleConversionError.accountNotFound(accountId)
            }
            transactions.append(contentsOf: try mergeCurrencyConversionTransactions(accountConversions, in: account)
                .filter { !lookup.doesTransactionExistInLedger($0) })
        }
        return transactions
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

    func mergeCurrencyConversionTransactions(_ transactions: [WTransaction], in account: WAccount) throws -> [STransaction] {
        struct CurrencyConversionKey: Hashable {
            let date: Date
            let description: String
            let fxRate: String
        }
        let grouped = Dictionary(grouping: transactions) {
            CurrencyConversionKey(date: $0.processDate, description: $0.description, fxRate: $0.fxRate)
        }
        return try grouped.values.map { try mergeCurrencyConversionPair($0, in: account) }
    }

    func tryMergeTransferPair(_ group: [WTransaction]) -> STransaction? {
        let transferIn = group.filter { $0.transactionType == .transferIn }
        let transferOut = group.filter { $0.transactionType == .transferOut }
        guard transferIn.count == 1 && transferOut.count == 1,
              let inTransaction = transferIn.first,
              let outTransaction = transferOut.first,
              accountsMatchDescription(inTransaction: inTransaction, outTransaction: outTransaction),
              let inAccount = accounts.first(where: { $0.id == inTransaction.accountId }),
              let outAccount = accounts.first(where: { $0.id == outTransaction.accountId }) else {
            return nil
        }

        // Get the ledger account names for both accounts
        guard let inAccountName = try? lookup.ledgerAccountName(of: inAccount),
              let outAccountName = try? lookup.ledgerAccountName(of: outAccount) else {
            return nil
        }

        // Create postings directly between the two accounts
        let postings = [
            Posting(accountName: inAccountName, amount: inTransaction.netCash),
            Posting(accountName: outAccountName, amount: outTransaction.netCash)
        ]

        let mergedId = group.map(\.id).sorted().joined(separator: " ")
        let meta = TransactionMetaData(
            date: inTransaction.processDate,
            metaData: [MetaDataKeys.id: mergedId]
        )
        return STransaction(metaData: meta, postings: postings)
    }

    func mergeCurrencyConversionPair(_ group: [WTransaction], in account: WAccount) throws -> STransaction {
        guard group.count == 2,
              let buyTransaction = group.first(where: { $0.transactionType == .currencyConversionBuy }),
              let sellTransaction = group.first(where: { $0.transactionType == .currencyConversionSell }),
              buyTransaction.netCashCurrency == sellTransaction.symbol else {
            throw WealthsimpleConversionError.unsupportedTransactionType(group.first?.transactionType.rawValue ?? "")
        }

        let sourceAccountName = try lookup.ledgerAccountName(of: account, symbol: account.currency == sellTransaction.symbol ? nil : sellTransaction.symbol)
        let targetAccountName = try lookup.ledgerAccountName(of: account, symbol: account.currency == buyTransaction.symbol ? nil : buyTransaction.symbol)
        let sourceAmount = Amount(for: sellTransaction.quantity, in: try lookup.commoditySymbol(for: sellTransaction.symbol))
        let targetAmount = Amount(for: buyTransaction.quantity, in: try lookup.commoditySymbol(for: buyTransaction.symbol))
        let totalPrice = Amount(for: sellTransaction.marketValueAmount, in: try lookup.commoditySymbol(for: sellTransaction.symbol))
        let mergedId = group.map(\.id).sorted().joined(separator: " ")

        return try STransaction(
            metaData: TransactionMetaData(date: buyTransaction.processDate, metaData: [MetaDataKeys.id: mergedId]),
            postings: [
                Posting(accountName: sourceAccountName, amount: sourceAmount),
                Posting(accountName: targetAccountName, amount: targetAmount, price: totalPrice, priceType: .total)
            ]
        )
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
