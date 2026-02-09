//
//  WealthsimpleLedgerMapper.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2020-07-26.
//

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParserUtils
import Wealthsimple

/// Functions to transform downloaded Wealthsimple data into SwiftBeanCountModel types
public struct WealthsimpleLedgerMapper {

    typealias WTransaction = Wealthsimple.Transaction
    typealias STransaction = SwiftBeanCountModel.Transaction
    typealias WAccount = Wealthsimple.Account

    /// Fallback account for payments if not account with the correct meta data could be found
    ///
    /// Only used for certain transaction types
    public static let fallbackExpenseAccountName = try! AccountName("Expenses:TODO") // swiftlint:disable:this force_try

    /// Payee used for fee transactions
    static let payee = "Wealthsimple"

    static let renameStockSplitPattern = "at 1.00000000 per share"

    /// Regex to parse the amount in foreign currency and the record date on dividend transactions from the description
    static let dividendRegEx: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: """
             ^[^:]*:\\s+([^\\s]+)\\s+\\(record date\\)\\s+([^\\s]+)\\s+shares(,\\s+gross\\s+([-+]?[0-9]+(,[0-9]{3})*(.[0-9]+)?)\\s+([^\\s]+), convert to\\s+.*)?$
             """,
                                 options: [])
    }()

    /// Regex to parse the amount in foreign currency on non residend tax withholding transactions from the description
    static let nrwtRegEx: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^[^:]*: Non-resident tax withheld at source \\(([-+]?[0-9]+(,[0-9]{3})*(.[0-9]+)?)\\s+([^\\s]+), convert to\\s+.*$", options: [])
    }()

    /// Date formatter to parse the record date of dividends from the description of dividend transaction
    static let dividendDescriptionDateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yy"
        return dateFormatter
    }()

    /// Date formatter used to save the dividend record date into transaction meta data
    static let dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    let lookup: LedgerLookup

    /// Downloaded Wealthsimple accounts
    ///
    /// Need to be set before attempting to map positions or transactions
    public var accounts = [Wealthsimple.Account]()

    /// Create a WealthsimpleLedgerMapper
    /// - Parameter ledger: Ledger to look up accounts, commodities or duplicate entries in
    public init(ledger: Ledger) {
        self.lookup = LedgerLookup(ledger)
    }

    /// Maps downloaded wealthsimple positions from one account to SwiftBeanCountModel prices and balances
    ///
    /// It also removes prices and balances which are already existing in the ledger
    ///
    /// Notes:
    ///  - Do not call with transactions from different accounts
    ///  - Make sure to set accounts on this class to the Wealthsimple accounts first
    ///  - Do not assume that the count of input and balance output is the same
    ///
    /// - Parameter positions: downloaded positions from one account
    /// - Throws: WealthsimpleConversionError
    /// - Returns: Prices and Balances
    public func mapPositionsToPriceAndBalance(_ positions: [Position]) throws -> ([Price], [Balance]) {
        guard let firstPosition = positions.first else {
            return ([], [])
        }
        guard let account = accounts.first( where: { $0.id == firstPosition.accountId }) else {
            throw WealthsimpleConversionError.accountNotFound(firstPosition.accountId)
        }
        var prices = [Price]()
        var balances = [Balance]()
        try positions.forEach {
            let price = Amount(for: $0.priceAmount, in: $0.priceCurrency)
            let balanceAmount = Amount(for: $0.quantity, in: try lookup.commoditySymbol(for: $0.asset.symbol))
            if $0.asset.type != .currency {
                let price = try Price(date: $0.positionDate, commoditySymbol: try lookup.commoditySymbol(for: $0.asset.symbol), amount: price)
                if !lookup.doesPriceExistInLedger(price) {
                    prices.append(price)
                }
            }
            let balance = Balance(date: $0.positionDate,
                                  accountName: try lookup.ledgerAccountName(of: account, symbol: account.currency != $0.asset.symbol ? $0.asset.symbol : nil),
                                  amount: balanceAmount)
            if !lookup.doesBalanceExistInLedger(balance) {
                balances.append(balance)
            }
        }
        return (prices, balances)
    }

    /// Maps downloaded wealthsimple transactions from one account to SwiftBeanCountModel transactions and prices
    ///
    /// It also removes transactions and prices which are already existing in the ledger
    ///
    /// Notes:
    ///  - Do not call with transactions from different accounts
    ///  - Make sure to set accounts on this class to the Wealthsimple accounts first
    ///  - Do not assume that the count of input and transaction output is the same, as this function consolidates transactions
    ///
    /// - Parameter wealthsimpleTransactions: downloaded transactions from one account
    /// - Throws: WealthsimpleConversionError
    /// - Returns: Prices and Transactions
    public func mapTransactionsToPriceAndTransactions(
        _ wealthsimpleTransactions: [Wealthsimple.Transaction]
    ) throws -> ([Price], [SwiftBeanCountModel.Transaction]) {
        guard let firstTransaction = wealthsimpleTransactions.first else {
            return ([], [])
        }
        guard let account = accounts.first( where: { $0.id == firstTransaction.accountId }) else {
            throw WealthsimpleConversionError.accountNotFound(firstTransaction.accountId)
        }
        var nrwtTransactions = [WTransaction](), stockSplits = [WTransaction](), cashbackTransactions = [WTransaction](), regularTransactions = [WTransaction]()
        for transaction in wealthsimpleTransactions {
            switch transaction.transactionType {
            case .nonResidentWithholdingTax:
                nrwtTransactions.append(transaction)
            case .stockDistribution:
                stockSplits.append(transaction)
            case .cashbackBonus:
                cashbackTransactions.append(transaction)
            default:
                regularTransactions.append(transaction)
            }
        }
        var prices = [Price](), transactions = [STransaction]()
        (prices, transactions) = try mapRegularTransactions(regularTransactions, nrwtTransactions: &nrwtTransactions, in: account)
        // add nrwt transactions which could not be merged
        transactions.append(contentsOf: try nrwtTransactions.map { try mapNonResidentWithholdingTax($0, in: account) }
            .filter { !lookup.doesTransactionExistInLedger($0) })

        transactions.append(contentsOf: try mapStockSplits(stockSplits, in: account).filter { !lookup.doesTransactionExistInLedger($0) })

        transactions.append(contentsOf: try mergeCashbackTransactions(cashbackTransactions, in: account)
            .filter { !lookup.doesTransactionExistInLedger($0) })

        return (prices, transactions)
    }

    /// Maps regular transactions (excluding NRWT, stock splits, and cashback), merging dividend transactions with their corresponding NRWT transactions
    private func mapRegularTransactions(
        _ wealthsimpleTransactions: [WTransaction],
        nrwtTransactions: inout [WTransaction],
        in account: WAccount
    ) throws -> ([Price], [STransaction]) {
        var prices = [Price](), transactions = [STransaction]()
        for wealthsimpleTransaction in wealthsimpleTransactions {
            let (price, transaction) = try mapTransaction(wealthsimpleTransaction, in: account)
            if var transaction, !lookup.doesTransactionExistInLedger(transaction) {
                if wealthsimpleTransaction.transactionType == .dividend,
                   let index = nrwtTransactions.firstIndex(where: {
                       $0.symbol == wealthsimpleTransaction.symbol && $0.processDate == wealthsimpleTransaction.processDate
                   }) {
                    transaction = try mergeNRWT(nrwtTransactions[index], withDividendTransaction: transaction, in: account)
                    nrwtTransactions.remove(at: index)
                }
                transactions.append(transaction)
            }
            if let price, !lookup.doesPriceExistInLedger(price) {
                prices.append(price)
            }
        }
        return (prices, transactions)
    }

    /// Merges duplicate cashback transactions by date, description and amount, combining their IDs space-separated in metadata
    private func mergeCashbackTransactions(_ transactions: [WTransaction], in account: WAccount) throws -> [STransaction] { // swiftlint:disable:this function_body_length
        struct CashbackKey: Hashable {
            let date: Date
            let description: String
            let amount: String
        }
        let grouped = Dictionary(grouping: transactions) { CashbackKey(date: $0.processDate, description: $0.description, amount: $0.marketValueAmount) }

        var results: [STransaction] = []
        for group in grouped.values {
            guard let first = group.first else {
                continue
            }

            // For groups with multiple transactions, validate the pattern and use the positive transaction
            if group.count > 1 {
                // Count positive and negative transactions
                let positive = group.filter { !$0.netCashAmount.starts(with: "-") }
                let negative = group.filter { $0.netCashAmount.starts(with: "-") }

                // Only merge if we have 2 positive and 1 negative with the same absolute amount
                if positive.count == 2 && negative.count == 1 {
                    // Use one of the positive transactions as the base
                    guard let positiveTransaction = positive.first else {
                        continue
                    }

                    let (_, result) = try mapTransaction(positiveTransaction, in: account)
                    guard let result else {
                        continue
                    }

                    // Merge all IDs
                    var ids = result.metaData.metaData
                    ids[MetaDataKeys.id] = group.map(\.id).joined(separator: " ")
                    let meta = TransactionMetaData(date: result.metaData.date, payee: result.metaData.payee, narration: result.metaData.narration, metaData: ids)
                    results.append(STransaction(metaData: meta, postings: result.postings))
                } else {
                    // Pattern doesn't match - return transactions individually
                    for transaction in group {
                        let (_, result) = try mapTransaction(transaction, in: account)
                        if let result {
                            results.append(result)
                        }
                    }
                }
            } else {
                // Single transaction - just map it normally
                let (_, result) = try mapTransaction(first, in: account)
                if let result {
                    results.append(result)
                }
            }
        }
        return results
    }

    /// Merges a non resident witholding tax transaction with the corresponding dividend transaction
    private func mergeNRWT(_ transaction: WTransaction, withDividendTransaction dividend: STransaction, in account: WAccount) throws -> STransaction {
        let expenseAmount = try parseNRWTDescription(transaction.description)
        let oldAsset = dividend.postings.first { $0.accountName.accountType == .asset }!
        let assetAmount = (oldAsset.amount + transaction.netCash).amountFor(symbol: transaction.netCashCurrency)
        let postings = [
            dividend.postings.first { $0.accountName.accountType == .income }!, // income stays the same
            Posting(accountName: try lookup.ledgerAccountName(for: .transactionType(transaction.transactionType), in: account, ofType: [.expense]), amount: expenseAmount),
            Posting(accountName: oldAsset.accountName, amount: assetAmount, price: oldAsset.price, cost: oldAsset.cost, metaData: oldAsset.metaData)
        ]
        var metaData = dividend.metaData.metaData
        metaData[MetaDataKeys.nrwtId] = transaction.id
        return STransaction(metaData: TransactionMetaData(date: dividend.metaData.date, metaData: metaData), postings: postings)
    }

}
