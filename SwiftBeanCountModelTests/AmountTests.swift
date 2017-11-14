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

    let amount1 = Amount(number: Decimal(1), commodity: Commodity(symbol: "CAD"))

    func testEqual() {
        let amount2 = Amount(number: Decimal(1), commodity: Commodity(symbol: "CAD"))
        XCTAssertEqual(amount1, amount2)
    }

    func testEqualRespectsAmount() {
        let amount2 = Amount(number: Decimal(10), commodity: Commodity(symbol: "CAD"))
        XCTAssertNotEqual(amount1, amount2)
    }

    func testEqualRespectsCommodity() {
        let amount2 = Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR"))
        XCTAssertNotEqual(amount1, amount2)
    }

    func testEqualRespectsDecimalDigits() {
        let amount2 = Amount(number: Decimal(1.0), commodity: Commodity(symbol: "EUR"), decimalDigits: 1)
        XCTAssertNotEqual(amount1, amount2)
    }

    func testDescriptionInteger() {
        let amountInteger = 123
        let commodity = Commodity(symbol: "💵")
        let amount = Amount(number: Decimal(amountInteger), commodity: commodity)

        XCTAssertEqual(String(describing: amount), "\(amountInteger) \(String(describing: commodity))")
    }

    func testDescriptionThousandsSeperator() {
        let amountInteger = 1_234_567_890.00
        let commodity = Commodity(symbol: "💵")
        let amount = Amount(number: Decimal(amountInteger), commodity: commodity, decimalDigits: 2)

        XCTAssertEqual(String(describing: amount), "1,234,567,890.00 \(String(describing: commodity))")
    }

    func testDescriptionFloat() {
        let commodity = Commodity(symbol: "💵")

        let amountOneDecimal = Amount(number: Decimal(125.5), commodity: commodity, decimalDigits: 1)
        XCTAssertEqual(String(describing: amountOneDecimal), "125.5 \(String(describing: commodity))")

        let amountTwoDecimals = Amount(number: Decimal(125.50), commodity: commodity, decimalDigits: 2)
        XCTAssertEqual(String(describing: amountTwoDecimals), "125.50 \(String(describing: commodity))")
    }

    func testDescriptionLongFloat() {
        let commodity = Commodity(symbol: "💵")
        let amount = Amount(number: Decimal(0.000_976_562_5), commodity: commodity, decimalDigits: 10)

        XCTAssertEqual(String(describing: amount), "0.0009765625 \(String(describing: commodity))")
    }

    func testMultiCurrencyAmount() {
        let decimal = Decimal(10)
        let commodity = Commodity(symbol: "EUR")
        let amount = Amount(number: decimal, commodity: commodity)
        XCTAssertEqual(amount.multiAccountAmount.amounts, [commodity: decimal])
        XCTAssertEqual(amount.multiAccountAmount.decimalDigits, [commodity: 0])
    }

    func testMultiCurrencyAmountDecimalDigits() {
        let decimal = Decimal(10.25)
        let commodity = Commodity(symbol: "EUR")
        let amount = Amount(number: decimal, commodity: commodity, decimalDigits: 2)
        XCTAssertEqual(amount.multiAccountAmount.amounts, [commodity: decimal])
        XCTAssertEqual(amount.multiAccountAmount.decimalDigits, [commodity: 2])
    }

}
