import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import Testing
import Wealthsimple

@Suite
struct TransactionHelperTests {

    @Test
    func extensions() {
        var transaction = TestTransaction()

        transaction.marketPriceAmount = "10.0110"
        transaction.marketPriceCurrency = "EUR"
        #expect(transaction.marketPrice == Amount(number: Decimal(10.011_0), commoditySymbol: "EUR", decimalDigits: 4))

        transaction.netCashAmount = "15.1"
        transaction.netCashCurrency = "CAD"
        #expect(transaction.netCash == Amount(number: Decimal(15.10), commoditySymbol: "CAD", decimalDigits: 2))
        #expect(transaction.negatedNetCash == Amount(number: Decimal(-15.10), commoditySymbol: "CAD", decimalDigits: 2))

        transaction.marketValueAmount = "10.0110"
        transaction.marketValueCurrency = "EUR"
        #expect(transaction.negatedMarketValue == Amount(number: Decimal(-10.011_0), commoditySymbol: "EUR", decimalDigits: 4))

        transaction.marketValueCurrency = "CAD"
        #expect(!(transaction.useFx))
        transaction.marketValueCurrency = "EUR"
        #expect(transaction.useFx)

        transaction.fxRate = "0.125"
        #expect(transaction.fxAmount == Amount(number: Decimal(8.000), commoditySymbol: "EUR", decimalDigits: 3))
    }
}
