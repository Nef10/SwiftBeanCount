//
//  MultiCurrencyAmountTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-07-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class MultiCurrencyAmountTests: XCTestCase {

    let euro = Commodity(symbol: "EUR")
    let canadianDollar = Commodity(symbol: "CAD")

    func testInit() {
        let multiCurrencyAmount = MultiCurrencyAmount()
        XCTAssertEqual(multiCurrencyAmount.amounts, [:])
    }

    func testMultiCurrencyAmount() {
        let multiCurrencyAmount = MultiCurrencyAmount(amounts: [euro: Decimal(10)], decimalDigits: [euro: 0])
        XCTAssertEqual(multiCurrencyAmount.multiCurrencyAmount, multiCurrencyAmount)
    }

    func testPlusSameCurrency() {
        let fifteenEuro = MultiCurrencyAmount(amounts: [euro: Decimal(15)], decimalDigits: [euro: 0])
        let tenEuro = MultiCurrencyAmount(amounts: [euro: Decimal(10)], decimalDigits: [euro: 0])
        let fiveEuro = MultiCurrencyAmount(amounts: [euro: Decimal(5)], decimalDigits: [euro: 0])
        XCTAssertEqual(fiveEuro + fiveEuro, tenEuro)
        XCTAssertEqual(fiveEuro + tenEuro, fifteenEuro)
        XCTAssertEqual(tenEuro + fiveEuro, fifteenEuro)
        var result = tenEuro
        result += fiveEuro
        XCTAssertEqual(result, fifteenEuro)
    }

    func testPlusDifferentCurrency() {
        let fiveEuroAndTenCanadianDollar = MultiCurrencyAmount(amounts: [euro: Decimal(5), canadianDollar: Decimal(10)], decimalDigits: [euro: 0, canadianDollar: 0])
        let tenCanadianDollar = MultiCurrencyAmount(amounts: [canadianDollar: Decimal(10)], decimalDigits: [canadianDollar: 0])
        let fiveEuro = MultiCurrencyAmount(amounts: [euro: Decimal(5)], decimalDigits: [euro: 0])
        XCTAssertEqual(fiveEuro + tenCanadianDollar, fiveEuroAndTenCanadianDollar)
        XCTAssertEqual(tenCanadianDollar + fiveEuro, fiveEuroAndTenCanadianDollar)
        var result = tenCanadianDollar
        result += fiveEuro
        XCTAssertEqual(result, fiveEuroAndTenCanadianDollar)
    }

    func testPlusEmpty() {
        let nothing = MultiCurrencyAmount()
        let fiveEuro = MultiCurrencyAmount(amounts: [euro: Decimal(5)], decimalDigits: [euro: 0])
        XCTAssertEqual(nothing + nothing, nothing)
        XCTAssertEqual(fiveEuro + nothing, fiveEuro)
        XCTAssertEqual(nothing + fiveEuro, fiveEuro)
        var result = nothing
        result += fiveEuro
        XCTAssertEqual(result, fiveEuro)
    }

    func testPlusDecimalDigits() {
        let fiveEuro = MultiCurrencyAmount(amounts: [euro: Decimal(5)], decimalDigits: [euro: 0])
        let fiveEuroZeroZero = MultiCurrencyAmount(amounts: [euro: Decimal(5.00)], decimalDigits: [euro: 2])
        let fiveCanadianDollar = MultiCurrencyAmount(amounts: [canadianDollar: Decimal(5)], decimalDigits: [canadianDollar: 0])
        let fiveCanadianDollarZero = MultiCurrencyAmount(amounts: [canadianDollar: Decimal(5.0)], decimalDigits: [canadianDollar: 1])

        var result = fiveEuro + fiveEuroZeroZero
        XCTAssertEqual(result.amounts[euro]!, 10)
        XCTAssertEqual(result.decimalDigits[euro]!, 2)
        result = fiveEuro
        result += fiveEuroZeroZero
        XCTAssertEqual(result.amounts[euro]!, 10)
        XCTAssertEqual(result.decimalDigits[euro]!, 2)

        result = fiveCanadianDollar + fiveEuroZeroZero
        XCTAssertEqual(result.decimalDigits[euro]!, 2)
        XCTAssertEqual(result.decimalDigits[canadianDollar]!, 0)
        result = fiveCanadianDollar
        result += fiveEuroZeroZero
        XCTAssertEqual(result.decimalDigits[euro]!, 2)
        XCTAssertEqual(result.decimalDigits[canadianDollar]!, 0)

        result = fiveCanadianDollarZero + fiveEuroZeroZero
        XCTAssertEqual(result.decimalDigits[euro]!, 2)
        XCTAssertEqual(result.decimalDigits[canadianDollar]!, 1)
        result = fiveCanadianDollarZero
        result += fiveEuroZeroZero
        XCTAssertEqual(result.decimalDigits[euro]!, 2)
        XCTAssertEqual(result.decimalDigits[canadianDollar]!, 1)

    }

    func testPlusKeepsDecimalDigits() {
        // the plus operation needs to keep decimal digits of unrelated currencies
        //
        // Example:
        // Assets:Checking 10.00000 CAD @ 0.85250 EUR will use
        // MultiCurrencyAmount(amounts:       [EUR: 8.5250],
        //                     decimalDigits: [CAD: 5])
        // The CAD: 5 needs to be carried over even if CAD is not used in amount

        let empty = MultiCurrencyAmount()
        let test = MultiCurrencyAmount(amounts: [euro: Decimal(8.525_0)], decimalDigits: [canadianDollar: 5])
        XCTAssertEqual((empty + test).decimalDigits[canadianDollar]!, 5)

        var result = empty
        result += test

        XCTAssertEqual(result.decimalDigits[canadianDollar]!, 5)
    }

    func testEqual() {
        let nothing = MultiCurrencyAmount()
        XCTAssertEqual(nothing, nothing)

        let fiveEuro = MultiCurrencyAmount(amounts: [euro: Decimal(5)], decimalDigits: [euro: 0])
        XCTAssertEqual(fiveEuro, fiveEuro)
        XCTAssertNotEqual(nothing, fiveEuro)

        let fiveCanadianDollar1 = MultiCurrencyAmount(amounts: [canadianDollar: Decimal(5)], decimalDigits: [canadianDollar: 0])
        let fiveCanadianDollar2 = MultiCurrencyAmount(amounts: [canadianDollar: Decimal(5)], decimalDigits: [canadianDollar: 0])
        XCTAssertEqual(fiveCanadianDollar1, fiveCanadianDollar2)
        XCTAssertNotEqual(fiveCanadianDollar1, fiveEuro)
        XCTAssertNotEqual(fiveCanadianDollar1, nothing)

        let fiveEuroAndFiveCanadianDollar1 = MultiCurrencyAmount(amounts: [euro: Decimal(5), canadianDollar: Decimal(10)], decimalDigits: [euro: 0, canadianDollar: 0])
        let fiveEuroAndFiveCanadianDollar2 = MultiCurrencyAmount(amounts: [euro: Decimal(5), canadianDollar: Decimal(10)], decimalDigits: [euro: 0, canadianDollar: 0])
        XCTAssertEqual(fiveEuroAndFiveCanadianDollar1, fiveEuroAndFiveCanadianDollar2)
        XCTAssertNotEqual(fiveEuroAndFiveCanadianDollar1, fiveEuro)
        XCTAssertNotEqual(fiveEuroAndFiveCanadianDollar1, fiveCanadianDollar1)
        XCTAssertNotEqual(fiveEuroAndFiveCanadianDollar1, nothing)
    }

    func testEqualDecimalDigits() {
        let fiveTwentyFife1 = MultiCurrencyAmount(amounts: [canadianDollar: Decimal(5.25)], decimalDigits: [canadianDollar: 2])
        let fiveTwentyFife2 = MultiCurrencyAmount(amounts: [canadianDollar: Decimal(5.25)], decimalDigits: [canadianDollar: 2])
        XCTAssertEqual(fiveTwentyFife1, fiveTwentyFife2)

        let fiveTwentyFifeZero = MultiCurrencyAmount(amounts: [canadianDollar: Decimal(5.250)], decimalDigits: [canadianDollar: 3])
        XCTAssertNotEqual(fiveTwentyFife1, fiveTwentyFifeZero)
    }

    func testValidateZeroWithTolerance() {
        let commodity = Commodity(symbol: "CAD")
        var amount = MultiCurrencyAmount(amounts: [:], decimalDigits: [:])
        guard case .valid = amount.validateZeroWithTolerance() else {
            XCTFail("\(amount) is not valid")
            return
        }

        amount.amounts[commodity] = 0
        guard case .valid = amount.validateZeroWithTolerance() else {
            XCTFail("\(amount) is not valid")
            return
        }

        amount.amounts[commodity] = 0.000_05
        if case .invalid(let error) = amount.validateZeroWithTolerance() {
            XCTAssertEqual(error, "0.00005 CAD too much (0 tolerance)")
        } else {
            XCTFail("\(amount) is valid")
        }

        amount.decimalDigits[commodity] = 5
        if case .invalid(let error) = amount.validateZeroWithTolerance() {
            XCTAssertEqual(error, "0.00005 CAD too much (0.000005 tolerance)")
        } else {
            XCTFail("\(amount) is valid")
        }

        amount.decimalDigits[commodity] = 4
        guard case .valid = amount.validateZeroWithTolerance() else {
            XCTFail("\(amount) is not valid")
            return
        }
    }

}
