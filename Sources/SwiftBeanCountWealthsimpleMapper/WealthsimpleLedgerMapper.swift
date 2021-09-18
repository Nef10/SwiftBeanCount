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

/// Helper functions to transform downloaded wealthsimple data into SwiftBeanCountModel types
public struct WealthsimpleLedgerMapper {

    private typealias WTransaction = Wealthsimple.Transaction
    private typealias STransaction = SwiftBeanCountModel.Transaction
    private typealias WAccount = Wealthsimple.Account
    private typealias SAccount = SwiftBeanCountModel.Account

    /// Payee used for fee transactions
    private static let payee = "Wealthsimple"

    /// Value used for the key of the rounding account
    private static let roundingValue = "rounding"

    /// Value used for the key of the contribution accounts
    private static let contributionValue = "contribution-room"

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

    private static let dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// Downloaded Wealthsimple accounts
    ///
    /// Need to be set before attempting to map positions or transactions
    public var accounts = [Wealthsimple.Account]()

    private let lookup: LedgerLookup

    /// Create a WealthsimpleLedgerMapper
    /// - Parameter ledger: Ledger to look up accounts, commodities or duplicate entries in
    public init(ledger: Ledger) {
        self.lookup = LedgerLookup(ledger)
    }

    static func amount(for string: String, in commoditySymbol: String, negate: Bool = false, inverse: Bool = false) -> Amount {
        var (number, decimalDigits) = string.amountDecimal()
        if negate {
            number = -number
        }
        if inverse {
            number = 1 / number
        }
        // Wealthsimple cuts of an ending 0 in the second digit. However, all amounts we deal with have at least 2 digits
        return Amount(number: number, commoditySymbol: commoditySymbol, decimalDigits: max(2, decimalDigits))
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
            let price = Self.amount(for: $0.priceAmount, in: $0.priceCurrency)
            let balanceAmount = Self.amount(for: $0.quantity, in: try lookup.commoditySymbol(for: $0.asset))
            if $0.asset.type != .currency {
                let price = try Price(date: $0.positionDate, commoditySymbol: try lookup.commoditySymbol(for: $0.asset), amount: price)
                if !lookup.doesPriceExistInLedger(price) {
                    prices.append(price)
                }
            }
            let balance = Balance(date: $0.positionDate,
                                  accountName: try lookup.ledgerAccountName(of: account, symbol: $0.asset.symbol),
                                  amount: balanceAmount)
            if !lookup.doesBalanceExistInLedger(balance) {
                balances.append(balance)
            }
        }
        if positions.isEmpty {
            let balance = Balance(date: Date(),
                                  accountName: try lookup.ledgerAccountName(of: account),
                                  amount: Amount(number: 0, commoditySymbol: account.currency, decimalDigits: 0))
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
        let transactionsToMap = wealthsimpleTransactions.filter { $0.transactionType != .nonResidentWithholdingTax }
        var prices = [Price]()
        var transactions = [SwiftBeanCountModel.Transaction]()
        for wealthsimpleTransaction in transactionsToMap {
            var (price, transaction) = try mapTransaction(wealthsimpleTransaction, in: account)
            if !lookup.doesTransactionExistInLedger(transaction) {
                if wealthsimpleTransaction.transactionType == .dividend,
                   let index = nrwtTransactions.firstIndex(where: { $0.symbol == wealthsimpleTransaction.symbol && $0.processDate == wealthsimpleTransaction.processDate }) {
                    transaction = try mergeNRWT(transaction: nrwtTransactions[index], withDividendTransaction: transaction, in: account)
                    nrwtTransactions.remove(at: index)
                }
                transactions.append(transaction)
            }
            if let price = price, !lookup.doesPriceExistInLedger(price) {
                prices.append(price)
            }
        }
        for wealthsimpleTransaction in nrwtTransactions { // add nrwt transactions which could not be merged
            let (price, transaction) = try mapTransaction(wealthsimpleTransaction, in: account)
            if !lookup.doesTransactionExistInLedger(transaction) {
                transactions.append(transaction)
            }
            if let price = price, !lookup.doesPriceExistInLedger(price) {
                prices.append(price)
            }
        }
        return (prices, transactions)
    }

    /// Merges a non resident witholding tax transaction with the corresponding dividend transactin
    /// - Parameters:
    ///   - transaction: the non resident witholding tax transaction
    ///   - dividend: the dividend transaction
    ///   - account: account of the transactions
    /// - Throws: WealthsimpleConversionError
    /// - Returns: Merged transaction
    private func mergeNRWT(transaction: WTransaction, withDividendTransaction dividend: STransaction, in account: WAccount) throws -> STransaction {
        let expenseAmount = try parseNRWTDescription(transaction.description)
        let oldAsset = dividend.postings.first { $0.accountName.accountType == .asset }!
        let assetAmount = (oldAsset.amount + transaction.netCash).amountFor(symbol: transaction.netCashCurrency)
        let postings = [
            dividend.postings.first { $0.accountName.accountType == .income }!, // income stays the same
            Posting(accountName: try lookup.ledgerAccountName(for: account, ofType: [.expense], symbol: transaction.transactionType.rawValue), amount: expenseAmount),
            Posting(accountName: oldAsset.accountName, amount: assetAmount, price: oldAsset.price, cost: oldAsset.cost, metaData: oldAsset.metaData)
        ]
        var metaData = dividend.metaData.metaData
        metaData[MetaDataKeys.nrwtId] = transaction.id
        return SwiftBeanCountModel.Transaction(metaData: TransactionMetaData(date: dividend.metaData.date, metaData: metaData), postings: postings)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func mapTransaction(_ transaction: Wealthsimple.Transaction, in account: Wealthsimple.Account) throws -> (Price?, SwiftBeanCountModel.Transaction) {
        let assetAccountName = try lookup.ledgerAccountName(of: account)
        var price: Price?, result: STransaction
        switch transaction.transactionType {
        case .buy:
            (price, result) = try mapBuy(transaction: transaction, in: account, assetAccountName: assetAccountName)
        case .sell:
            (price, result) = try mapSell(transaction: transaction, in: account, assetAccountName: assetAccountName)
        case .dividend:
            result = try mapDividend(transaction: transaction, in: account, assetAccountName: assetAccountName)
        case .fee, .reimbursement, .interest:
            result = try mapFeeOrReimbursementOrInterest(transaction: transaction, in: account, assetAccountName: assetAccountName)
        case .contribution:
            result = try mapContribution(transaction: transaction, in: account, assetAccountName: assetAccountName)
        case .deposit, .withdrawal, .paymentTransferOut, .transferIn, .transferOut:
            result = try mapDeposit(transaction: transaction, in: account, assetAccountName: assetAccountName)
        case .refund:
            result = try mapRefund(transaction: transaction, in: account, assetAccountName: assetAccountName)
        case .nonResidentWithholdingTax:
            result = try mapNonResidentWithholdingTax(transaction: transaction, in: account, assetAccountName: assetAccountName)
        case .paymentTransferIn, .referralBonus, .giveawayBonus:
            result = try mapDeposit(transaction: transaction, in: account, assetAccountName: assetAccountName, accountTypes: [.asset, .income])
        case .paymentSpend:
            result = try mapDeposit(transaction: transaction, in: account, assetAccountName: assetAccountName, accountTypes: [.expense])
        default:
            throw WealthsimpleConversionError.unsupportedTransactionType(transaction.transactionType.rawValue)
        }
        if !lookup.isTransactionValid(result) {
            let posting = Posting(accountName: try lookup.ledgerAccountName(for: account, ofType: [.expense], symbol: Self.roundingValue),
                                  amount: lookup.roundingBalance(result))
            result = SwiftBeanCountModel.Transaction(metaData: result.metaData, postings: result.postings + [posting])
        }
        return (price, result)
    }

    private func mapBuy(transaction: WTransaction, in account: WAccount, assetAccountName: AccountName) throws -> (Price, STransaction) {
        let posting1 = Posting(accountName: assetAccountName, amount: transaction.netCash, price: transaction.useFx ? transaction.fxAmount : nil)
        let posting2 = Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: transaction.symbol),
                               amount: try transaction.quantityAmount(lookup: lookup),
                               cost: try Cost(amount: transaction.marketPrice, date: nil, label: nil))
        let result = STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [posting1, posting2])
        return (try Price(date: transaction.processDate, commoditySymbol: transaction.symbol, amount: transaction.marketPrice), result)
    }

    private func mapDeposit(transaction: WTransaction, in account: WAccount, assetAccountName: AccountName, accountTypes: [AccountType] = [.asset]) throws -> STransaction {
        let accountName = try lookup.ledgerAccountName(for: account, ofType: accountTypes, symbol: transaction.transactionType.rawValue)
        let posting1 = Posting(accountName: assetAccountName, amount: transaction.netCash)
        let posting2 = Posting(accountName: accountName, amount: transaction.negatedNetCash)
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [posting1, posting2])
    }

    private func mapContribution(transaction: WTransaction, in account: WAccount, assetAccountName: AccountName) throws -> STransaction {
        let accountName = try lookup.ledgerAccountName(for: account, ofType: [.asset], symbol: transaction.transactionType.rawValue)
        var postings = [
            Posting(accountName: assetAccountName, amount: transaction.netCash),
            Posting(accountName: accountName, amount: transaction.negatedNetCash)
        ]
        if let contributionAsset = try? lookup.ledgerAccountName(for: account, ofType: [.asset], symbol: Self.contributionValue),
           let contributionExpense = try? lookup.ledgerAccountName(for: account, ofType: [.expense], symbol: Self.contributionValue),
           let commoditySymbol = lookup.ledgerAccountCommoditySymbol(of: contributionAsset) {
            let amount1 = Amount(number: transaction.negatedNetCash.number, commoditySymbol: commoditySymbol, decimalDigits: transaction.negatedNetCash.decimalDigits)
            let amount2 = Amount(number: transaction.netCash.number, commoditySymbol: commoditySymbol, decimalDigits: transaction.netCash.decimalDigits)
            postings.append(Posting(accountName: contributionAsset, amount: amount1))
            postings.append(Posting(accountName: contributionExpense, amount: amount2))
        }
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: postings)
    }

    private func mapFeeOrReimbursementOrInterest(transaction: WTransaction, in account: WAccount, assetAccountName: AccountName) throws -> STransaction {
        let meta = TransactionMetaData(date: transaction.processDate, payee: Self.payee, narration: transaction.description, metaData: [MetaDataKeys.id: transaction.id])
        let posting1 = Posting(accountName: assetAccountName, amount: transaction.netCash)
        let posting2 = Posting(accountName: try lookup.ledgerAccountName(for: account, ofType: [.expense, .income], symbol: transaction.transactionType.rawValue),
                               amount: transaction.negatedNetCash)
        return SwiftBeanCountModel.Transaction(metaData: meta, postings: [posting1, posting2])
    }

    private func mapDividend(transaction: WTransaction, in account: WAccount, assetAccountName: AccountName) throws -> STransaction {
        let (date, shares, foreignAmount) = try parseDividendDescription(transaction.description)
        var income = transaction.negatedNetCash
        var price: Amount?
        if let amount = foreignAmount {
            income = amount
            price = Amount(number: transaction.fxAmount.number, commoditySymbol: amount.commoditySymbol, decimalDigits: transaction.fxAmount.decimalDigits)
        }
        let posting1 = Posting(accountName: assetAccountName, amount: transaction.netCash, price: price)
        let posting2 = Posting(accountName: try lookup.ledgerAccountName(for: account, ofType: [.income], symbol: transaction.symbol), amount: income)
        let metaDataDict = [MetaDataKeys.id: transaction.id, MetaDataKeys.dividendRecordDate: date, MetaDataKeys.dividendShares: shares]
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: metaDataDict), postings: [posting1, posting2])
    }

    private func mapNonResidentWithholdingTax(transaction: WTransaction, in account: WAccount, assetAccountName: AccountName) throws -> STransaction {
        let amount = try parseNRWTDescription(transaction.description)
        let price = Amount(number: transaction.fxAmount.number, commoditySymbol: amount.commoditySymbol, decimalDigits: transaction.fxAmount.decimalDigits)
        let posting1 = Posting(accountName: assetAccountName, amount: transaction.netCash, price: price)
        let posting2 = Posting(accountName: try lookup.ledgerAccountName(for: account, ofType: [.expense], symbol: transaction.transactionType.rawValue), amount: amount)
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [posting1, posting2])
    }

    private func mapRefund(transaction: WTransaction, in account: WAccount, assetAccountName: AccountName) throws -> STransaction {
        let posting1 = Posting(accountName: assetAccountName, amount: transaction.netCash)
        let posting2 = Posting(accountName: try lookup.ledgerAccountName(for: account, ofType: [.income], symbol: transaction.transactionType.rawValue),
                               amount: transaction.negatedNetCash)
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [posting1, posting2])
    }

    private func mapSell(transaction: WTransaction, in account: WAccount, assetAccountName: AccountName) throws -> (Price, STransaction) {
        let cost = try Cost(amount: nil, date: nil, label: nil)
        let posting1 = Posting(accountName: assetAccountName, amount: transaction.netCash, price: transaction.useFx ? transaction.fxAmount : nil)
        let accountName2 = try lookup.ledgerAccountName(of: account, symbol: transaction.symbol)
        let posting2 = Posting(accountName: accountName2, amount: try transaction.quantityAmount(lookup: lookup), price: transaction.marketPrice, cost: cost)
        let result = STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [posting1, posting2])
        return (try Price(date: transaction.processDate, commoditySymbol: transaction.symbol, amount: transaction.marketPrice), result)
    }

    // swiftlint:disable:next large_tuple
    private func parseDividendDescription(_ string: String) throws -> (String, String, Amount?) {
        let matches = string.matchingStrings(regex: Self.dividendRegEx)
        guard matches.count == 1, let date = Self.dividendDescriptionDateFormatter.date(from: matches[0][1]) else {
            throw WealthsimpleConversionError.unexpectedDescription(string)
        }
        let match = matches[0]
        let resultAmount = !match[4].isEmpty ? Self.amount(for: match[4], in: match[7], negate: true) : nil
        return (Self.dateFormatter.string(from: date), match[2], resultAmount)
    }

    private func parseNRWTDescription(_ string: String) throws -> Amount {
        let matches = string.matchingStrings(regex: Self.nrwtRegEx)
        guard matches.count == 1 else {
            throw WealthsimpleConversionError.unexpectedDescription(string)
        }
        return Self.amount(for: matches[0][1], in: matches[0][4])
    }

}
