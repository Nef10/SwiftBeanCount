//
//  WealthsimpleTransaction.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2020-07-31.
//

import Foundation
import SwiftBeanCountModel
import Wealthsimple

/// Protocol to abstract a Wealthsimple Account
public protocol AccountProvider {
   /// Wealthsimple id for the account
    var id: String { get }
    /// number of the account
    var number: String { get }
    /// Operating currency of the account
    var currency: String { get }
}

/// Protocol to abstract a Wealthsimple Asset
public protocol AssetProvider {
    /// Symbol of the asset, e.g. currency or ticker symbol
    var symbol: String { get }
    /// Type of the asset, e.g. currency or ETF
    var type: Wealthsimple.Asset.AssetType { get }
}

/// Protocol to abstract a Wealthsimple Position
public protocol PositionProvider {
    /// Wealthsimple identifier of the account in which this position is held
    var accountId: String { get }
    /// Asset which is held
    var assetObject: AssetProvider { get }
    /// Price per pice of the asset on `priceDate`
    var priceAmount: String { get }
    /// Date of the positon
    var positionDate: Date { get }
    /// Currency of the price
    var priceCurrency: String { get }
    /// Number of units of the asset held
    var quantity: String { get }
}

/// Protocol to define which properties are required for Wealthsimple Transactions
public protocol TransactionProvider {
    /// Wealthsimples identifier of this transaction
    var id: String { get }
    /// Wealthsimple identifier of the account in which this transaction happend
    var accountId: String { get }
    /// type of the transaction, like buy or sell
    var transactionType: Wealthsimple.Transaction.TransactionType { get }
    /// description of the transaction
    var description: String { get }
    /// symbol of the asset which is brought, sold, ...
    var symbol: String { get }
    /// Number of units of the asset brought, sold, ...
    var quantity: String { get }
    /// market pice of the asset
    var marketPriceAmount: String { get }
    /// Currency of the market price
    var marketPriceCurrency: String { get }
    /// market value of the assets
    var marketValueAmount: String { get }
    /// Currency of the market value
    var marketValueCurrency: String { get }
    /// Net chash change in the account
    var netCashAmount: String { get }
    /// Currency of the net cash change
    var netCashCurrency: String { get }
    /// Foreign exchange rate applied
    var fxRate: String { get }
    /// Date when the trade was settled
    var effectiveDate: Date { get }
    /// Date when the trade was processed
    var processDate: Date { get }
}

extension TransactionProvider {

    var marketPrice: Amount {
        Amount(for: marketPriceAmount, in: marketPriceCurrency)
    }
    var netCash: Amount {
        Amount(for: netCashAmount, in: netCashCurrency)
    }
    var negatedNetCash: Amount {
        Amount(for: netCashAmount, in: netCashCurrency, negate: true)
    }
    var fxAmount: Amount {
        Amount(for: fxRate, in: marketPriceCurrency, inverse: true)
    }
    var useFx: Bool {
        marketValueCurrency != netCashCurrency
    }

}

extension Wealthsimple.Account: AccountProvider {
}

extension Wealthsimple.Asset: AssetProvider {
}

extension Wealthsimple.Position: PositionProvider {
    public var assetObject: AssetProvider {
        asset
    }
}

extension Wealthsimple.Transaction: TransactionProvider {
}
