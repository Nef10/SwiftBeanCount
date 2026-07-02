//
//  WealthsimpleLedgerMapper+TransactionMapping.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2024-02-08.
//

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParserUtils
import WealthsimpleDownloader

extension WealthsimpleLedgerMapper {

    // swiftlint:disable:next cyclomatic_complexity
    func mapTransaction(_ transaction: WTransaction, in account: WAccount) throws -> (Price?, STransaction?) {
        var price: Price?, result: STransaction?
        switch transaction.transactionType {
        case .buy:
            (price, result) = try mapBuy(transaction, in: account)
        case .sell:
            (price, result) = try mapSell(transaction, in: account)
        case .dividend, .manufacturedDividend:
            result = try mapDividend(transaction, in: account, manufactured: transaction.transactionType == .manufacturedDividend)
        case .contribution:
            result = try mapContribution(transaction, in: account)
        case .deposit, .withdrawal, .paymentTransferOut, .transferIn, .transferOut, .payment:
            result = try mapTransfer(transaction, in: account, accountTypes: [.asset])
        case .paymentTransferIn, .referralBonus, .giveawayBonus, .cashbackBonus:
            result = try mapTransfer(transaction, in: account, accountTypes: [.asset, .income])
        case .paymentSpend, .onlineBillPayment, .purchase, .refund:
            result = try mapTransfer(transaction, in: account, accountTypes: [.expense], allowFx: true, includeDescription: true)
        case .fee, .reimbursement, .interest:
            result = try mapTransfer(transaction, in: account, accountTypes: [.expense, .income], payee: Self.payee)
        case .stockDividend:
            (price, result) = try mapStockDividend(transaction, in: account)
        case .stockLoanBorrow, .stockLoanReturn, .returnOfCapital, .nonCashDistribution:
            break // right now we do not track stock loans
        default:
            throw WealthsimpleConversionError.unsupportedTransactionType(transaction.transactionType.rawValue)
        }
        return (price, result)
    }

    func mapBuy(_ transaction: WTransaction, in account: WAccount) throws -> (Price, STransaction) {
        let result = STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [
            Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash, price: transaction.useFx ? transaction.fxAmount : nil),
            Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: transaction.symbol),
                    amount: Amount(for: transaction.quantity, in: try lookup.commoditySymbol(for: transaction.symbol)),
                    cost: try Cost(amount: transaction.marketPrice, date: nil, label: nil))
        ])
        return (try Price(date: transaction.processDate, commoditySymbol: lookup.commoditySymbol(for: transaction.symbol), amount: transaction.marketPrice), result)
    }

    func mapSell(_ transaction: WTransaction, in account: WAccount) throws -> (Price, STransaction) {
        let result = STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [
            Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash, price: transaction.useFx ? transaction.fxAmount : nil),
            Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: transaction.symbol),
                    amount: Amount(for: transaction.quantity, in: try lookup.commoditySymbol(for: transaction.symbol)),
                    price: transaction.marketPrice,
                    cost: try Cost(amount: nil, date: nil, label: nil))
        ])
        return (try Price(date: transaction.processDate, commoditySymbol: lookup.commoditySymbol(for: transaction.symbol), amount: transaction.marketPrice), result)
    }

    func mapTransfer(
        _ transaction: WTransaction,
        in account: WAccount,
        accountTypes: [SwiftBeanCountModel.AccountType],
        payee: String = "",
        allowFx: Bool = false,
        includeDescription: Bool = false
    ) throws -> STransaction {
        let accountName = try lookup.ledgerAccountName(for: .transactionType(transaction.transactionType), in: account, ofType: accountTypes)
        let hasFX = allowFx && transaction.netCashCurrency != transaction.symbol
        let amount = hasFX ? Amount(for: transaction.quantity, in: try lookup.commoditySymbol(for: transaction.symbol), negate: true) : transaction.negatedNetCash
        let price = hasFX ? (transaction.netCash.number.isSignMinus ? transaction.negatedNetCash : transaction.netCash) : nil
        let posting1 = Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash)
        let posting2 = try Posting(accountName: accountName, amount: amount, price: price, priceType: hasFX ? .total : nil)
        let narration = includeDescription ? transaction.description : ""
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, payee: payee, narration: narration, metaData: [MetaDataKeys.id: transaction.id]),
                            postings: [posting1, posting2])
    }

    func mapContribution(_ transaction: WTransaction, in account: WAccount) throws -> STransaction {
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

    func mapDividend(_ transaction: WTransaction, in account: WAccount, manufactured: Bool = false) throws(WealthsimpleConversionError) -> STransaction {
        let (date, shares, foreignAmount) = parseDividendDescription(transaction.description)
        var income = transaction.negatedNetCash
        var price: Amount?
        if let amount = foreignAmount {
            income = amount
            price = Amount(number: transaction.fxAmount.number, commoditySymbol: amount.commoditySymbol, decimalDigits: transaction.fxAmount.decimalDigits)
        }
        let posting1 = Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash, price: price)
        let posting2 = Posting(accountName: try lookup.ledgerAccountName(for: .dividend(transaction.symbol), in: account, ofType: [.income]), amount: income)
        var metaDataDict = [MetaDataKeys.id: transaction.id]
        if let date {
            metaDataDict[MetaDataKeys.dividendRecordDate] = date
        }
        if let shares {
            metaDataDict[MetaDataKeys.dividendShares] = shares
        }
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, narration: manufactured ? "Manufactured Dividend" : "", metaData: metaDataDict),
                            postings: [posting1, posting2])
    }

    func mapStockDividend(_ transaction: WTransaction, in account: WAccount) throws -> (Price, STransaction) {
        let result = STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [
            Posting(accountName: try lookup.ledgerAccountName(for: .dividend(transaction.symbol), in: account, ofType: [.income]), amount: transaction.negatedMarketValue),
            Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: transaction.symbol),
                    amount: Amount(for: transaction.quantity, in: try lookup.commoditySymbol(for: transaction.symbol)),
                    cost: try Cost(amount: transaction.marketPrice, date: nil, label: nil))
        ])
        return (try Price(date: transaction.processDate, commoditySymbol: lookup.commoditySymbol(for: transaction.symbol), amount: transaction.marketPrice), result)
    }

    func mapNonResidentWithholdingTax(_ transaction: WTransaction, in account: WAccount) throws -> STransaction {
        let amount = try parseNRWTDescription(transaction.description)
        let price = Amount(number: transaction.fxAmount.number, commoditySymbol: amount.commoditySymbol, decimalDigits: transaction.fxAmount.decimalDigits)
        let posting1 = Posting(accountName: try lookup.ledgerAccountName(of: account), amount: transaction.netCash, price: price)
        let posting2 = Posting(accountName: try lookup.ledgerAccountName(for: .transactionType(transaction.transactionType), in: account, ofType: [.expense]), amount: amount)
        return STransaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transaction.id]), postings: [posting1, posting2])
    }

    func mapStockSplits(_ transactions: [WTransaction], in account: WAccount) throws -> [STransaction] {
        var groups: [String: [WTransaction]] = [:]
        for transaction in transactions {
            var description = transaction.description
            if description.hasSuffix(Self.renameStockSplitPattern) {
                description.removeLast(Self.renameStockSplitPattern.count)
            }
            if groups[description] == nil {
                groups[description] = []
            }
            groups[description]?.append(transaction)
        }
        return try groups.values.map { try mapStockSplit($0, in: account) }
    }

    func mapStockSplit(_ transactions: [WTransaction], in account: WAccount) throws -> STransaction {
        guard let buyTransaction = transactions.first(where: { !$0.quantity.starts(with: "-") }),
              let sellTransaction = transactions.first(where: { $0.quantity.starts(with: "-") }) else {
            throw WealthsimpleConversionError.unexpectedStockSplit(transactions.first!.description)
        }
        let metaData = TransactionMetaData(date: buyTransaction.processDate, narration: buyTransaction.description, metaData: [MetaDataKeys.id: buyTransaction.id])
        return STransaction(metaData: metaData, postings: [
            Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: sellTransaction.symbol),
                    amount: Amount(for: sellTransaction.quantity, in: try lookup.commoditySymbol(for: sellTransaction.symbol)),
                    cost: try Cost(amount: nil, date: nil, label: nil)),
            Posting(accountName: try lookup.ledgerAccountName(of: account, symbol: buyTransaction.symbol),
                    amount: Amount(for: buyTransaction.quantity, in: try lookup.commoditySymbol(for: buyTransaction.symbol)),
                    cost: try Cost(amount: buyTransaction.symbol != sellTransaction.symbol ? buyTransaction.marketPrice : nil, date: nil, label: nil))
        ])
    }

    // swiftlint:disable:next large_tuple
    func parseDividendDescription(_ string: String) -> (String?, String?, Amount?) {
        let matches = string.matchingStrings(regex: Self.dividendRegEx)
        guard matches.count == 1, let date = Self.dividendDescriptionDateFormatter.date(from: matches[0][1]) else {
            return (nil, nil, nil)
        }
        let match = matches[0]
        let resultAmount = !match[4].isEmpty ? Amount(for: match[4], in: match[7], negate: true) : nil
        return (Self.dateFormatter.string(from: date), match[2], resultAmount)
    }

    func parseNRWTDescription(_ string: String) throws -> Amount {
        let matches = string.matchingStrings(regex: Self.nrwtRegEx)
        guard matches.count == 1 else {
            throw WealthsimpleConversionError.unexpectedDescription(string)
        }
        return Amount(for: matches[0][1], in: matches[0][4])
    }

}
