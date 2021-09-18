//
//  LedgerLookup.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2020-07-27.
//

import Foundation
import SwiftBeanCountModel
import Wealthsimple

protocol WealthsimpleAccountRepresentable {
    var number: String { get }
    var accountType: Wealthsimple.Account.AccountType { get }
    var currency: String { get }
}

enum AccoutLookupType {
    case transactionType(Wealthsimple.Transaction.TransactionType)
    case dividend(String)
    case contributionRoom
    case rounding
}

/// To lookup things in the ledger
struct LedgerLookup {

    /// Key used to look up accounts by keys (e.g. symbols or transactions types) in the ledger
    static let keyMetaDataKey = "wealthsimple-key"

    /// Key used to look up accounts by type in the ledger
    static let accountTypeMetaDataKey = "wealthsimple-account-type"

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
            $0.metaData.metaData[MetaDataKeys.id] == id ||
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

    func isTransactionValid(_ transaction: SwiftBeanCountModel.Transaction) -> Bool {
        do {
            return try transaction.balance(in: ledger).isZeroWithTolerance()
        } catch {
            return true
        }
    }

    func roundingBalance(_ transaction: SwiftBeanCountModel.Transaction) -> Amount {
        do {
            let balance = try transaction.balance(in: ledger)
            let (symbol, _) = balance.amounts.first!
            let amount = balance.amountFor(symbol: symbol)
            return Amount(number: amount.number, commoditySymbol: amount.commoditySymbol, decimalDigits: amount.decimalDigits + 1)
        } catch {
            return Amount(number: 0, commoditySymbol: "")
        }
    }

    func commoditySymbol(for asset: Asset) throws -> CommoditySymbol {
        if asset.type == .currency {
            return asset.symbol
        } else {
            return try commoditySymbol(for: asset.symbol)
        }
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
    func ledgerAccountName(
        for type: AccoutLookupType,
        in account: WealthsimpleAccountRepresentable,
        ofType accountType: [SwiftBeanCountModel.AccountType]
    ) throws -> AccountName {
        let symbol: String
        switch type {
        case let .transactionType(transactionType):
            symbol = transactionType.rawValue
        case let .dividend(dividendSymbol):
            symbol = dividendSymbol
        case .contributionRoom:
            symbol = "contribution-room"
        case .rounding:
            symbol = "rounding"
        }
        let resultAccount = ledger.accounts.first {
            accountType.contains($0.name.accountType)  &&
                ($0.metaData[Self.keyMetaDataKey]?.contains(symbol) ?? false) &&
                ($0.metaData[Self.accountTypeMetaDataKey]?.contains(account.accountType.rawValue) ?? false)
        }
        guard let accountName = resultAccount?.name else {
            throw WealthsimpleConversionError.missingAccount(symbol, accountType.map { $0.rawValue }.joined(separator: ", or "), account.accountType.rawValue)
        }
        return accountName
    }

    /// Returns account name of matching the Wealthsimple account in the ledger
    /// - Parameters:
    ///   - account: Account to get the name for
    ///   - assetSymbol: Assets symbol in the account. If not specified cash account will be returned
    /// - Throws: WealthsimpleConversionError if the account cannot be found
    /// - Returns: Name of the matching account
    func ledgerAccountName(of account: WealthsimpleAccountRepresentable, symbol assetSymbol: String? = nil) throws -> AccountName {
        let baseAccount = ledger.accounts.first {
            $0.metaData[MetaDataKeys.importerType] == MetaData.importerType &&
            $0.metaData[MetaDataKeys.number] == account.number
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

extension Wealthsimple.Account: WealthsimpleAccountRepresentable {
}
