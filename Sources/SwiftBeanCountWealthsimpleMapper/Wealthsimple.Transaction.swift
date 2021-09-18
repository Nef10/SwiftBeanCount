//
//  WealthsimpleTransaction.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2020-07-31.
//

import SwiftBeanCountModel
import Wealthsimple

extension Wealthsimple.Transaction {

    var marketPrice: Amount {
        WealthsimpleLedgerMapper.amount(for: marketPriceAmount, in: marketPriceCurrency)
    }
    var netCash: Amount {
        WealthsimpleLedgerMapper.amount(for: netCashAmount, in: netCashCurrency)
    }
    var negatedNetCash: Amount {
        WealthsimpleLedgerMapper.amount(for: netCashAmount, in: netCashCurrency, negate: true)
    }
    var fxAmount: Amount {
        WealthsimpleLedgerMapper.amount(for: fxRate, in: marketPriceCurrency, inverse: true)
    }
    var cashTypes: [Wealthsimple.Transaction.TransactionType] {
        [.fee, .contribution, .deposit, .refund]
    }
    var useFx: Bool {
        marketValueCurrency != netCashCurrency
    }

    func quantitySymbol(lookup: LedgerLookup) throws -> String {
        cashTypes.contains(transactionType) ? symbol : try lookup.commoditySymbol(for: symbol)
    }

    func quantityAmount(lookup: LedgerLookup) throws -> Amount {
        WealthsimpleLedgerMapper.amount(for: quantity, in: try quantitySymbol(lookup: lookup))
    }

}
