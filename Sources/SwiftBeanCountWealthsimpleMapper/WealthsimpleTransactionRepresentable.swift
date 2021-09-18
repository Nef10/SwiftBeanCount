//
//  WealthsimpleTransaction.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2020-07-31.
//

import Foundation
import SwiftBeanCountModel
import Wealthsimple

/// Protocol to define which properties are required for Wealthsimple Transactions
protocol WealthsimpleTransactionRepresentable {
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

extension WealthsimpleTransactionRepresentable {

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

extension Wealthsimple.Transaction: WealthsimpleTransactionRepresentable {
}
