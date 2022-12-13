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

    private typealias WTransaction = Wealthsimple.Transaction
    private typealias STransaction = SwiftBeanCountModel.Transaction
    private typealias WAccount = Wealthsimple.Account

    /// Fallback account for payments if not account with the correct meta data could be found
    ///
    /// Only used for transaction type payment spend
    public static let fallbackExpenseAccountName = try! AccountName("Expenses:TODO") // swiftlint:disable:this force_try

    /// Payee used for fee transactions
    private static let payee = "Wealthsimple"

    /// Regex to parse the amount in foreign currency and the record date on dividend transactions from the description
    private static let dividendRegEx: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: """
             ^[^:]*:\\s+([^\\s]+)\\s+\\(record date\\)\\s+([^\\s]+)\\s+shares(,\\s+gross\\s+([-+]?[0-9]+(,[0-9]{3})*(.[0-9]+)?)\\s+([^\\s]+), convert to\\s+.*)?$
             """,
                                 options: [])
    }()

    /// Regex to parse the amount in foreign currency on non residend tax withholding transactions from the description
    private static let nrwtRegEx: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^[^:]*: Non-resident tax withheld at source \\(([-+]?[0-9]+(,[0-9]{3})*(.[0-9]+)?)\\s+([^\\s]+), convert to\\s+.*$", options: [])
    }()

    /// Date formatter to parse the record date of dividends from the description of dividend transaction
    private static let dividendDescriptionDateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yy"
        return dateFormatter
    }()

    /// Date formatter used to save the dividend record date into transaction meta data
    private static let dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private let lookup: LedgerLookup

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
    public func mapTransactionsToPriceAndTransactions(_ wealthsimpleTransactions: [Wealthsimple.Transaction]) throws -> ([Price], [SwiftBeanCountModel.Transaction]) {
        guard let firstTransaction = wealthsimpleTransactions.first else {
            return ([], [])
        }
        guard let account = accounts.first( where: { $0.id == firstTransaction.accountId }) else {
            throw WealthsimpleConversionError.accountNotFound(firstTransaction.accountId)
        }
        var nrwtTransactions = wealthsimpleTransactions.filter { $0.transactionType == .nonResidentWithholdingTax }
        let stockSplits = wealthsimpleTransactions.filter { $0.transactionType == .stockDistribution }
        var prices = [Price](), transactions = [STransaction]()
        for wealthsimpleTransaction in wealthsimpleTransactions where wealthsimpleTransaction.transactionType != .nonResidentWithholdingTax
                                                                      && wealthsimpleTransaction.transactionType != .stockDistribution {
            var (price, transaction) = try mapTransaction(wealthsimpleTransaction, in: account)
            if !lookup.doesTransactionExistInLedger(transaction) {
                if wealthsimpleTransaction.transactionType == .dividend,
                   let index = nrwtTransactions.firstIndex(where: { $0.symbol == wealthsimpleTransaction.symbol && $0.processDate == wealthsimpleTransaction.processDate }) {
                    transaction = try mergeNRWT(nrwtTransactions[index], withDividendTransaction: transaction, in: account)
                    nrwtTransactions.remove(at: index)
                }
                transactions.append(transaction)
            }
            if let price, !lookup.doesPriceExistInLedger(price) {
                prices.append(price)
            }
        }
        // add nrwt transactions which could not be merged
        transactions.append(contentsOf: try nrwtTransactions.map { try mapNonResidentWithholdingTax($0, in: account) }.filter { !lookup.doesTransactionExistInLedger($0) })

        transactions.append(contentsOf: try mapStockSplits(stockSplits, in: account).filter { !lookup.doesTransactionExistInLedger($0) })
        return (prices, transactions)
    }

    /// Merges a non resident witholding tax transaction with the corresponding dividend transaction
    /// - Parameters:
    ///   - transaction: the non resident witholding tax transaction
    ///   - dividend: the dividend transaction
    ///   - account: account of the transactions
    /// - Throws: WealthsimpleConversionError
    /// - Returns: Merged transaction
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

    private func mapTransaction(_ transaction: WTransaction, in account: WAccount) throws -> (Price?, STransaction) {
        var price: Price?, result: STransaction
        switch transaction.transactionType {
        case .buy:
            (price, result) = try mapBuy(transaction, in: account)
        case .sell:
            (price, result) = try mapSell(transaction, in: account)
        case .dividend:
            result = try mapDividend(transaction, in: account)
        case .contribution:
            result = try mapContribution(transaction, in: account)
        case .deposit, .withdrawal, .paymentTransferOut, .transferIn, .transferOut:
            result = try mapTransfer(transaction, in: account, accountTypes: [.asset])
        case .paymentTransferIn, .referralBonus, .giveawayBonus, .refund, .cashbackBonus:
            result = try mapTransfer(transaction, in: account, accountTypes: [.asset, .income])
        case .paymentSpend:
            result = try mapTransfer(transaction, in: account, accountTypes: [.expense])
        case .fee, .reimbursement, .interest:
            result = try mapTransfer(transaction, in: account, accountTypes: [.expense, .income], payee: Self.payee)
        default:
            throw WealthsimpleConversionError.unsupportedTransactionType(transaction.transactionType.rawValue)
        }
        return (price, result)
    }

    private func mapBuy(_ transaction: WTransaction, in account: WAccount) throws -> (Price, STransaction) {
        let result = STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [
            Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash, price: transaction.useFx ? transaction.fxAmount : nil),
            Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: transaction.symbol),
                    amount: Amount(for: transaction.quantity, in: try lookup.commoditySymbol(for: transaction.symbol)),
                    cost: try Cost(amount: transaction.marketPrice, date: nil, label: nil))
        ])
        return (try Price(date: transaction.processDate, commoditySymbol: transaction.symbol, amount: transaction.marketPrice), result)
    }

    private func mapSell(_ transaction: WTransaction, in account: WAccount) throws -> (Price, STransaction) {
        let result = STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [
            Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash, price: transaction.useFx ? transaction.fxAmount : nil),
            Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: transaction.symbol),
                    amount: Amount(for: transaction.quantity, in: try lookup.commoditySymbol(for: transaction.symbol)),
                    price: transaction.marketPrice,
                    cost: try Cost(amount: nil, date: nil, label: nil))
        ])
        return (try Price(date: transaction.processDate, commoditySymbol: transaction.symbol, amount: transaction.marketPrice), result)
    }

    private func mapTransfer(_ transaction: WTransaction, in account: WAccount, accountTypes: [SwiftBeanCountModel.AccountType], payee: String = "") throws -> STransaction {
        let accountName = try lookup.ledgerAccountName(for: .transactionType(transaction.transactionType), in: account, ofType: accountTypes)
        let posting1 = Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash)
        let posting2 = Posting(accountName: accountName, amount: transaction.negatedNetCash)
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, payee: payee, metaData: [MetaDataKeys.id: transaction.id]),
                            postings: [posting1, posting2])
    }

    private func mapContribution(_ transaction: WTransaction, in account: WAccount) throws -> STransaction {
        let accountName = try lookup.ledgerAccountName(for: .transactionType(transaction.transactionType), in: account, ofType: [.asset])
        var postings = [
            Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash),
            Posting(accountName: accountName, amount: transaction.negatedNetCash)
        ]
        if let contributionAsset = try? lookup.ledgerAccountName(for: .contributionRoom, in: account, ofType: [.asset]),
           let contributionExpense = try? lookup.ledgerAccountName(for: .contributionRoom, in: account, ofType: [.expense]),
           let commoditySymbol = lookup.ledgerAccountCommoditySymbol(of: contributionAsset) {
            let amount1 = Amount(number: transaction.negatedNetCash.number, commoditySymbol: commoditySymbol, decimalDigits: transaction.negatedNetCash.decimalDigits)
            let amount2 = Amount(number: transaction.netCash.number, commoditySymbol: commoditySymbol, decimalDigits: transaction.netCash.decimalDigits)
            postings.append(Posting(accountName: contributionAsset, amount: amount1))
            postings.append(Posting(accountName: contributionExpense, amount: amount2))
        }
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: postings)
    }

    private func mapDividend(_ transaction: WTransaction, in account: WAccount) throws -> STransaction {
        let (date, shares, foreignAmount) = try parseDividendDescription(transaction.description)
        var income = transaction.negatedNetCash
        var price: Amount?
        if let amount = foreignAmount {
            income = amount
            price = Amount(number: transaction.fxAmount.number, commoditySymbol: amount.commoditySymbol, decimalDigits: transaction.fxAmount.decimalDigits)
        }
        let posting1 = Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash, price: price)
        let posting2 = Posting(accountName: try lookup.ledgerAccountName(for: .dividend(transaction.symbol), in: account, ofType: [.income]), amount: income)
        let metaDataDict = [MetaDataKeys.id: transaction.id, MetaDataKeys.dividendRecordDate: date, MetaDataKeys.dividendShares: shares]
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: metaDataDict), postings: [posting1, posting2])
    }

    private func mapNonResidentWithholdingTax(_ transaction: WTransaction, in account: WAccount) throws -> STransaction {
        let amount = try parseNRWTDescription(transaction.description)
        let price = Amount(number: transaction.fxAmount.number, commoditySymbol: amount.commoditySymbol, decimalDigits: transaction.fxAmount.decimalDigits)
        let posting1 = Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash, price: price)
        let posting2 = Posting(accountName: try lookup.ledgerAccountName(for: .transactionType(transaction.transactionType), in: account, ofType: [.expense]), amount: amount)
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [posting1, posting2])
    }

    private func mapStockSplits(_ transactions: [WTransaction], in account: WAccount) throws -> [STransaction] {
        var splitPairs = [String: [WTransaction]]()
        for transaction in transactions {
            if splitPairs["\(transaction.symbol)"] == nil {
                splitPairs["\(transaction.symbol)"] = []
            }
            splitPairs["\(transaction.symbol)"]?.append(transaction)
        }
        var transactions = [STransaction]()
        for (_, transactionPair) in splitPairs {
            transactions.append(try mapStockSplit(transactionPair, in: account))
        }
        return transactions
    }

    private func mapStockSplit(_ transactions: [WTransaction], in account: WAccount) throws -> STransaction {
        guard transactions.count == 2 else {
            throw WealthsimpleConversionError.unexpectedStockSplit(transactions.first!.description)
        }
        guard let buyTransaction = transactions.first(where: { !$0.quantity.starts(with: "-") }),
              let sellTransaction = transactions.first(where: { $0.quantity.starts(with: "-") }) else {
            throw WealthsimpleConversionError.unexpectedStockSplit(transactions.first!.description)
        }
        let metaData = TransactionMetaData(date: buyTransaction.processDate, narration: buyTransaction.description, metaData: [MetaDataKeys.id: buyTransaction.id])
        let result = STransaction(metaData: metaData, postings: [
            Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: sellTransaction.symbol),
                    amount: Amount(for: sellTransaction.quantity, in: try lookup.commoditySymbol(for: sellTransaction.symbol)),
                    cost: try Cost(amount: nil, date: nil, label: nil)),
            Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: buyTransaction.symbol),
                    amount: Amount(for: buyTransaction.quantity, in: try lookup.commoditySymbol(for: buyTransaction.symbol)),
                    cost: try Cost(amount: nil, date: nil, label: nil))
        ])
        return result
    }

    // swiftlint:disable:next large_tuple
    private func parseDividendDescription(_ string: String) throws -> (String, String, Amount?) {
        let matches = string.matchingStrings(regex: Self.dividendRegEx)
        guard matches.count == 1, let date = Self.dividendDescriptionDateFormatter.date(from: matches[0][1]) else {
            throw WealthsimpleConversionError.unexpectedDescription(string)
        }
        let match = matches[0]
        let resultAmount = !match[4].isEmpty ? Amount(for: match[4], in: match[7], negate: true) : nil
        return (Self.dateFormatter.string(from: date), match[2], resultAmount)
    }

    private func parseNRWTDescription(_ string: String) throws -> Amount {
        let matches = string.matchingStrings(regex: Self.nrwtRegEx)
        guard matches.count == 1 else {
            throw WealthsimpleConversionError.unexpectedDescription(string)
        }
        return Amount(for: matches[0][1], in: matches[0][4])
    }

}
