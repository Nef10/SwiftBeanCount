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
