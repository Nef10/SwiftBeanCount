import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import XCTest

final class AmountInitTests: XCTestCase {

    func testInit() {
        XCTAssertEqual(Amount(for: "1.0", in: "CAD"), Amount(number: Decimal(1), commoditySymbol: "CAD", decimalDigits: 2))
        XCTAssertEqual(Amount(for: "1.000", in: "EUR"), Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 3))
        XCTAssertEqual(Amount(for: "-10", in: "EUR"), Amount(number: Decimal(-10), commoditySymbol: "EUR", decimalDigits: 2))
        XCTAssertEqual(Amount(for: "1,000", in: "EUR"), Amount(number: Decimal(1_000), commoditySymbol: "EUR", decimalDigits: 2))
        XCTAssertEqual(Amount(for: "10", in: "EUR", negate: true), Amount(number: Decimal(-10), commoditySymbol: "EUR", decimalDigits: 2))
        XCTAssertEqual(Amount(for: "-10.011", in: "EUR", negate: true), Amount(number: Decimal(10.011), commoditySymbol: "EUR", decimalDigits: 3))
        XCTAssertEqual(Amount(for: "10", in: "EUR", negate: true), Amount(number: Decimal(-10), commoditySymbol: "EUR", decimalDigits: 2))
        XCTAssertEqual(Amount(for: "0.10", in: "EUR", inverse: true), Amount(number: Decimal(10), commoditySymbol: "EUR", decimalDigits: 2))
        XCTAssertEqual(Amount(for: "0.10", in: "EUR", negate: true, inverse: true), Amount(number: Decimal(-10), commoditySymbol: "EUR", decimalDigits: 2))
    }

}
