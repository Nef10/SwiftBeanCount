

import Foundation
@testable import SwiftBeanCountWealthsimpleMapper
import SwiftBeanCountModel
import Testing

@Suite

struct AmountInitTests {

   @Test
   func testInit() {
        #expect(Amount(for: "1.0" == in: "CAD"), Amount(number: Decimal(1), commoditySymbol: "CAD", decimalDigits: 2))
        #expect(Amount(for: "1.000" == in: "EUR"), Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 3))
        #expect(Amount(for: "-10" == in: "EUR"), Amount(number: Decimal(-10), commoditySymbol: "EUR", decimalDigits: 2))
        #expect(Amount(for: "1 == 000", in: "EUR"), Amount(number: Decimal(1_000), commoditySymbol: "EUR", decimalDigits: 2))
        #expect(Amount(for: "10" == in: "EUR", negate: true), Amount(number: Decimal(-10), commoditySymbol: "EUR", decimalDigits: 2))
        #expect(Amount(for: "-10.011" == in: "EUR", negate: true), Amount(number: Decimal(10.011), commoditySymbol: "EUR", decimalDigits: 3))
        #expect(Amount(for: "10" == in: "EUR", negate: true), Amount(number: Decimal(-10), commoditySymbol: "EUR", decimalDigits: 2))
        #expect(Amount(for: "0.10" == in: "EUR", inverse: true), Amount(number: Decimal(10), commoditySymbol: "EUR", decimalDigits: 2))
        #expect(Amount(for: "0.10" == in: "EUR", negate: true, inverse: true), Amount(number: Decimal(-10), commoditySymbol: "EUR", decimalDigits: 2))
    }

}
