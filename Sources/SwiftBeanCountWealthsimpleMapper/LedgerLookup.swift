//
//  LedgerLookup.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2020-07-27.
//

import Foundation
import SwiftBeanCountModel
import Wealthsimple

/// To lookup things in the ledger
struct LedgerLookup {

    /// Key used to look up assets for wealthsimple symbols in the ledger
    static let symbolMetaDataKey = "wealthsimple-symbol"

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

    func doesTransactionExistInLedger(_ transaction: SwiftBeanCountModel.Transaction) -> Bool {
        self.ledger.transactions.contains {
            $0.metaData.metaData[MetaDataKeys.id] == transaction.metaData.metaData[MetaDataKeys.id] ||
            $0.metaData.metaData[MetaDataKeys.nrwtId] == transaction.metaData.metaData[MetaDataKeys.id]
        }
    }

    func doesPriceExistInLedger(_ price: SwiftBeanCountModel.Price) -> Bool {
        ledger.prices.contains(price)
    }

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

    func ledgerSymbol(for asset: Asset) throws -> String {
        if asset.type == .currency {
            return asset.symbol
        } else {
            return try ledgerSymbol(for: asset.symbol)
        }
    }

    func ledgerSymbol(for assetSymbol: String) throws -> String {
        let commodity = ledger.commodities.first {
            $0.metaData[Self.symbolMetaDataKey] == assetSymbol
        }
        guard let symbol = commodity?.symbol else {
            throw WealthsimpleConversionError.missingCommodity(assetSymbol)
        }
        return symbol
    }

    func ledgerAccountName(for account: Wealthsimple.Account, ofType type: [SwiftBeanCountModel.AccountType], symbol assetSymbol: String? = nil) throws -> AccountName {
        let symbol = assetSymbol ?? account.currency
        let accountType = account.accountType.rawValue
        let account = ledger.accounts.first {
            type.contains($0.name.accountType)  &&
                ($0.metaData[Self.keyMetaDataKey]?.contains(symbol) ?? false) &&
                ($0.metaData[Self.accountTypeMetaDataKey]?.contains(accountType) ?? false)
        }
        guard let accountName = account?.name else {
            throw WealthsimpleConversionError.missingAccount(symbol, type.map { $0.rawValue }.joined(separator: ", or"), accountType)
        }
        return accountName
    }

    func ledgerAccountCommoditySymbol(of account: AccountName) -> String? {
        let account = ledger.accounts.first {
            $0.name == account
        }
        return account?.commoditySymbol
    }
}
