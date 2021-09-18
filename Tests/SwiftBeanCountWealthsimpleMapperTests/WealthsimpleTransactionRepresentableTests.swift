import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import Wealthsimple
import XCTest

struct TestWealthsimpleTransactionRepresentable: WealthsimpleTransactionRepresentable {
    let id = ""
    let accountId = ""
    let transactionType: Wealthsimple.Transaction.TransactionType = .buy
    let description = ""
    let symbol = ""
    let marketValueAmount = ""
    let effectiveDate = Date()
    let processDate = Date()
    let quantity = ""

    var fxRate = ""
    var netCashAmount = ""
    var netCashCurrency = ""
    var marketPriceAmount = ""
    var marketPriceCurrency = ""
    var marketValueCurrency = ""
}

final class WealthsimpleTransactionRepresentableTests: XCTestCase {

    func testExtension() {
        var transaction = TestWealthsimpleTransactionRepresentable()

        transaction.marketPriceAmount = "10.0110"
        transaction.marketPriceCurrency = "EUR"
        XCTAssertEqual(transaction.marketPrice, Amount(number: Decimal(10.011_0), commoditySymbol: "EUR", decimalDigits: 4))

        transaction.netCashAmount = "15.1"
        transaction.netCashCurrency = "CAD"
        XCTAssertEqual(transaction.netCash, Amount(number: Decimal(15.10), commoditySymbol: "CAD", decimalDigits: 2))
        XCTAssertEqual(transaction.negatedNetCash, Amount(number: Decimal(-15.10), commoditySymbol: "CAD", decimalDigits: 2))

        transaction.marketValueCurrency = "CAD"
        XCTAssertFalse(transaction.useFx)
        transaction.marketValueCurrency = "EUR"
        XCTAssert(transaction.useFx)

        transaction.fxRate = "0.125"
        XCTAssertEqual(transaction.fxAmount, Amount(number: Decimal(8.000), commoditySymbol: "EUR", decimalDigits: 3))
    }
}
