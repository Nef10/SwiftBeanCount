//
//  LedgerLookup.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2020-07-27.
//

import Foundation
import SwiftBeanCountModel
import Wealthsimple

enum AccoutLookupType {
    case transactionType(TransactionType)
    case dividend(String)
    case contributionRoom
    case rounding
}

/// To lookup things in the ledger
struct LedgerLookup {

    /// Ledger to look up accounts, commodities or duplicate entries in
    private let ledger: Ledger

    /// Create a LedgerLookup
    /// - Parameter ledger: Ledger to look up accounts, commodities or duplicate entries in
    init(_ ledger: Ledger) {
        self.ledger = ledger
    }

    /// Checks if a transaction with a certain wealthsimple id as meta data already exists in the ledger
    /// The check only checks based on the wealthsimple id - not any date, amount or other property
    /// - Parameter transaction: transaction to check - should have MetaDataKeys.id set as meta data
    /// - Returns: if a transaction with this id is already in the ledger
    func doesTransactionExistInLedger(_ transaction: SwiftBeanCountModel.Transaction) -> Bool {
        guard let id = transaction.metaData.metaData[MetaDataKeys.id] else {
            return false
        }
        return self.ledger.transactions.contains {
            $0.metaData.metaData[MetaDataKeys.id]?.contains(id) ?? false ||
            $0.metaData.metaData[MetaDataKeys.nrwtId] == id
        }
    }

    /// Checks if a specific price is already in the ledger
    /// - Parameter price: price to check
    /// - Returns: if the price exists
    func doesPriceExistInLedger(_ price: SwiftBeanCountModel.Price) -> Bool {
        ledger.prices.contains(price)
    }

    /// Checks if a specific balance exists in the ledger
    /// - Parameter balance: balance to check
    /// - Returns: if the balance already exists
    func doesBalanceExistInLedger(_ balance: Balance) -> Bool {
        guard let account = ledger.accounts.first(where: { $0.name == balance.accountName }) else {
            return false
        }
        return account.balances.contains(balance)
    }

    /// Finds the right CommoditySymbol from the ledger to use for a given asset symbol
    /// The user can specify this via Self.symbolMetaDataKey, otherwise it try to use the commodity with the same symbol
    /// - Parameter assetSymbol: asset symbol to find the commodity for
    /// - Throws: WealthsimpleConversionError if the commodity cannot be found in the ledger
    /// - Returns: CommoditySymbol
    func commoditySymbol(for assetSymbol: String) throws -> CommoditySymbol {
        var commodity = ledger.commodities.first { $0.metaData[MetaDataKeys.commoditySymbol] == assetSymbol }
        if commodity == nil {
            commodity = ledger.commodities.first { $0.symbol == assetSymbol }
        }
        guard let symbol = commodity?.symbol else {
            throw WealthsimpleConversionError.missingCommodity(assetSymbol)
        }
        return symbol
    }

    /// Returns account name to use for a certain type of posting - not including the Wealthsimple accounts themselves
    /// - Parameters:
    ///   - type: AccoutLookupType to specify for which transaction type
    ///   - account: WealthsimpleAccount to find the specific account for
    ///   - accountType: Ehich account type is required, e.g. asset, expenses, income, ...
    /// - Throws: WealthsimpleConversionError if the account could not be found
    /// - Returns: AccountName to use
    func ledgerAccountName(
        for type: AccoutLookupType,
        in account: Wealthsimple.Account,
        ofType accountTypes: [SwiftBeanCountModel.AccountType]
    ) throws -> AccountName {
        let key: String
        switch type {
        case let .transactionType(transactionType):
            key = "\(MetaDataKeys.prefix)\("\(transactionType)".camelCaseToKebabCase())"
        case let .dividend(dividendSymbol):
            key = "\(MetaDataKeys.dividendPrefix)\(try commoditySymbol(for: dividendSymbol))"
        case .contributionRoom:
            key = MetaDataKeys.contributionRoom
        case .rounding:
            key = MetaDataKeys.rounding
        }
        guard let name = ledger.accounts.first(where: { accountTypes.contains($0.name.accountType) && $0.metaData[key]?.contains(account.number) ?? false })?.name else {
            if case let .transactionType(transactionType) = type {
                switch transactionType {
                case .onlineBillPayment, .deposit, .paymentSpend, .transferIn, .transferOut, .paymentTransferIn, .paymentTransferOut, .withdrawal:
                    return WealthsimpleLedgerMapper.fallbackExpenseAccountName
                default:
                    throw WealthsimpleConversionError.missingAccount(key, account.number, accountTypes.map { $0.rawValue }.joined(separator: ", or "))
                }
            }
            throw WealthsimpleConversionError.missingAccount(key, account.number, accountTypes.map { $0.rawValue }.joined(separator: ", or "))
        }
        return name
    }

    /// Returns account name of matching the Wealthsimple account in the ledger
    /// - Parameters:
    ///   - account: Account to get the name for
    ///   - assetSymbol: Assets symbol in the account. If not specified cash account will be returned
    /// - Throws: WealthsimpleConversionError if the account cannot be found
    /// - Returns: Name of the matching account
    func ledgerAccountName(of account: Wealthsimple.Account, symbol assetSymbol: String? = nil) throws -> AccountName {
        let baseAccount = ledger.accounts.first {
            $0.metaData[MetaDataKeys.importerType] == MetaData.importerType &&
            $0.metaData[MetaDataKeys.number]?.contains(account.number) ?? false
        }
        guard let accountName = baseAccount?.name else {
            throw WealthsimpleConversionError.missingWealthsimpleAccount(account.number)
        }
        if let symbol = assetSymbol {
            let name = "\(accountName.fullName.split(separator: ":").dropLast(1).joined(separator: ":")):\(try commoditySymbol(for: symbol))"
            guard let result = try? AccountName(name) else {
                throw WealthsimpleConversionError.invalidCommoditySymbol(symbol)
            }
            return result
        }
        return accountName
    }

    /// Get the CommoditySymbol of a specified account in the ledger
    /// - Parameter account: name of the account to check
    /// - Returns:CommoditySymbol or nil if either the account could not be found or did not have a commodity assigned
    func ledgerAccountCommoditySymbol(of account: AccountName) -> CommoditySymbol? {
        ledger.accounts.first { $0.name == account }?.commoditySymbol
    }
}
