import SwiftBeanCountModel
@testable import SwiftBeanCountTax
import XCTest

final class SaleTests: XCTestCase {

    func testDescriptionWithName() {
        let date = Date(timeIntervalSince1970: 1_650_013_015)
        let sale = Sale(date: date,
                        symbol: "STOCK",
                        name: "Stock Company",
                        quantity: 4,
                        proceeds: Amount(number: 100, commoditySymbol: "USD").multiCurrencyAmount,
                        gain: Amount(number: 10, commoditySymbol: "CAD").multiCurrencyAmount,
                        provider: "Bank")
        XCTAssertEqual(sale.description, "2022-04-15 STOCK 4 Stock Company 100.00 USD 10.00 CAD")
    }

    func testDescriptionWithoutName() {
        let date = Date(timeIntervalSince1970: 1_650_013_015)
        let sale = Sale(date: date,
                        symbol: "STOCK",
                        name: nil,
                        quantity: 4,
                        proceeds: Amount(number: 100, commoditySymbol: "USD").multiCurrencyAmount,
                        gain: Amount(number: 10, commoditySymbol: "CAD").multiCurrencyAmount,
                        provider: "Bank")
        XCTAssertEqual(sale.description, "2022-04-15 STOCK 4  100.00 USD 10.00 CAD")
    }

}
