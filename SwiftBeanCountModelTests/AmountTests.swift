//
//  AmountTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-21.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class AmountTests: XCTestCase {

    func testEqual() {
        XCTAssertEqual(TestUtils.amount, Amount(number: Decimal(1), commoditySymbol: TestUtils.cad))
    }

    func testEqualRespectsAmount() {
        XCTAssertNotEqual(TestUtils.amount, Amount(number: Decimal(10), commoditySymbol: TestUtils.cad))
    }

    func testEqualRespectsCommodity() {
        XCTAssertNotEqual(TestUtils.amount, TestUtils.amount2)
    }

    func testEqualRespectsDecimalDigits() {
        XCTAssertNotEqual(TestUtils.amount, Amount(number: Decimal(1.0), commoditySymbol: TestUtils.eur, decimalDigits: 1))
    }

    func testDescriptionInteger() {
        let amountInteger = 123
        let amount = Amount(number: Decimal(amountInteger), commoditySymbol: TestUtils.cad)

        XCTAssertEqual(String(describing: amount), "\(amountInteger) \(TestUtils.cad)")
    }

    func testDescriptionThousandsSeperator() {
        let amountInteger = 1_234_567_890.00
        let amount = Amount(number: Decimal(amountInteger), commoditySymbol: TestUtils.cad, decimalDigits: 2)

        XCTAssertEqual(String(describing: amount), "1,234,567,890.00 \(TestUtils.cad)")
    }

    func testDescriptionFloat() {
        let amountOneDecimal = Amount(number: Decimal(125.5), commoditySymbol: TestUtils.cad, decimalDigits: 1)
        XCTAssertEqual(String(describing: amountOneDecimal), "125.5 \(TestUtils.cad)")

        let amountTwoDecimals = Amount(number: Decimal(125.50), commoditySymbol: TestUtils.cad, decimalDigits: 2)
        XCTAssertEqual(String(describing: amountTwoDecimals), "125.50 \(TestUtils.cad)")
    }

    func testDescriptionLongFloat() {
        let amount = Amount(number: Decimal(0.000_976_562_5), commoditySymbol: TestUtils.cad, decimalDigits: 10)
        XCTAssertEqual(String(describing: amount), "0.0009765625 \(TestUtils.cad)")
    }

    func testMultiCurrencyAmount() {
        let decimal = Decimal(10)
        let amount = Amount(number: decimal, commoditySymbol: TestUtils.eur)
        XCTAssertEqual(amount.multiCurrencyAmount.amounts, [TestUtils.eur: decimal])
        XCTAssertEqual(amount.multiCurrencyAmount.decimalDigits, [TestUtils.eur: 0])
    }

    func testMultiCurrencyAmountDecimalDigits() {
        let decimal = Decimal(10.25)
        let amount = Amount(number: decimal, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        XCTAssertEqual(amount.multiCurrencyAmount.amounts, [TestUtils.eur: decimal])
        XCTAssertEqual(amount.multiCurrencyAmount.decimalDigits, [TestUtils.eur: 2])
    }

}
