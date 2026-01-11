//
//  AmountTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-21.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite
struct AmountTests {

    @Test
    func testEqual() {
        #expect(TestUtils.amount == Amount(number: Decimal(1), commoditySymbol: TestUtils.cad))
    }

    @Test
    func testEqualRespectsAmount() {
        #expect(TestUtils.amount != Amount(number: Decimal(10), commoditySymbol: TestUtils.cad))
    }

    @Test
    func testEqualRespectsCommodity() {
        #expect(TestUtils.amount != TestUtils.amount2)
    }

    @Test
    func testEqualRespectsDecimalDigits() {
        #expect(TestUtils.amount != Amount(number: Decimal(1.0), commoditySymbol: TestUtils.eur, decimalDigits: 1))
    }

    @Test
    func testDescriptionInteger() {
        let amountInteger = 123
        let amount = Amount(number: Decimal(amountInteger), commoditySymbol: TestUtils.cad)

        #expect(String(describing: amount) == "\(amountInteger) \(TestUtils.cad)")
    }

    @Test
    func testDescriptionThousandsSeperator() {
        let amountInteger = 1_234_567_890.00
        let amount = Amount(number: Decimal(amountInteger), commoditySymbol: TestUtils.cad, decimalDigits: 2)

        #expect(String(describing: amount) == "1,234,567,890.00 \(TestUtils.cad)")
    }

    @Test
    func testDescriptionFloat() {
        let amountOneDecimal = Amount(number: Decimal(125.5), commoditySymbol: TestUtils.cad, decimalDigits: 1)
        #expect(String(describing: amountOneDecimal) == "125.5 \(TestUtils.cad)")

        let amountTwoDecimals = Amount(number: Decimal(125.50), commoditySymbol: TestUtils.cad, decimalDigits: 2)
        #expect(String(describing: amountTwoDecimals) == "125.50 \(TestUtils.cad)")
    }

    @Test
    func testDescriptionLongFloat() {
        let amount = Amount(number: Decimal(0.000_976_562_5), commoditySymbol: TestUtils.cad, decimalDigits: 10)
        #expect(String(describing: amount) == "0.0009765625 \(TestUtils.cad)")
    }

    @Test
    func testMultiCurrencyAmount() {
        let decimal = Decimal(10)
        let amount = Amount(number: decimal, commoditySymbol: TestUtils.eur)
        #expect(amount.multiCurrencyAmount.amounts == [TestUtils.eur: decimal])
        #expect(amount.multiCurrencyAmount.decimalDigits == [TestUtils.eur: 0])
    }

    @Test
    func testMultiCurrencyAmountDecimalDigits() {
        let decimal = Decimal(10.25)
        let amount = Amount(number: decimal, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        #expect(amount.multiCurrencyAmount.amounts == [TestUtils.eur: decimal])
        #expect(amount.multiCurrencyAmount.decimalDigits == [TestUtils.eur: 2])
    }

    @Test
    func testAmountStringPublic() {
        // Test that amountString is publicly accessible and returns formatted number without commodity
        let amountInteger = Amount(number: Decimal(123), commoditySymbol: TestUtils.cad, decimalDigits: 0)
        #expect(amountInteger.amountString == "123")

        let amountFloat = Amount(number: Decimal(125.50), commoditySymbol: TestUtils.cad, decimalDigits: 2)
        #expect(amountFloat.amountString == "125.50")

        let amountThousands = Amount(number: Decimal(1_234_567.89), commoditySymbol: TestUtils.cad, decimalDigits: 2)
        #expect(amountThousands.amountString == "1,234,567.89")

        // Verify it matches the number part of description (before the space and commodity)
        let description = String(describing: amountFloat)
        let expectedDescription = "\(amountFloat.amountString) \(TestUtils.cad)"
        #expect(description == expectedDescription)
    }

    @Test
    func testAmountStringMinMaxDecimalDigits() {
        // Fill with zeros to the right number of decimal digits
        let amount = Amount(number: Decimal(0.67), commoditySymbol: TestUtils.cad, decimalDigits: 3)
        #expect(amount.amountString == "0.670")

        // Round down to the correct number of decimal digits
        let amount2 = Amount(number: Decimal(0.673), commoditySymbol: TestUtils.cad, decimalDigits: 2)
        #expect(amount2.amountString == "0.67")

        // Round up to the correct number of decimal digits
        let amount3 = Amount(number: Decimal(0.677), commoditySymbol: TestUtils.cad, decimalDigits: 2)
        #expect(amount3.amountString == "0.68")

        // No decimal digits
        let amount4 = Amount(number: Decimal(234.56), commoditySymbol: TestUtils.cad, decimalDigits: 0)
        #expect(amount4.amountString == "235")
    }

}
