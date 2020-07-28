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

    func testInit() {
        let multiCurrencyAmount = MultiCurrencyAmount()
        XCTAssertEqual(multiCurrencyAmount.amounts, [:])
    }

    func testMultiCurrencyAmount() {
        let multiCurrencyAmount = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10)], decimalDigits: [TestUtils.eur: 0])
        XCTAssertEqual(multiCurrencyAmount.multiCurrencyAmount, multiCurrencyAmount)
    }

    func testAmountFor() {
        var multiCurrencyAmount = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10)], decimalDigits: [TestUtils.eur: 3])
        var result = multiCurrencyAmount.amountFor(symbol: TestUtils.eur)
        XCTAssertEqual(result.commoditySymbol, TestUtils.eur)
        XCTAssertEqual(result.number, Decimal(10))
        XCTAssertEqual(result.decimalDigits, 3)

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10), TestUtils.usd: Decimal(4)], decimalDigits: [TestUtils.eur: 3, TestUtils.usd: 0])
        result = multiCurrencyAmount.amountFor(symbol: TestUtils.eur)
        XCTAssertEqual(result.commoditySymbol, TestUtils.eur)
        XCTAssertEqual(result.number, Decimal(10))
        XCTAssertEqual(result.decimalDigits, 3)

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10)], decimalDigits: [TestUtils.eur: 3])
        result = multiCurrencyAmount.amountFor(symbol: TestUtils.usd)
        XCTAssertEqual(result.commoditySymbol, TestUtils.usd)
        XCTAssertEqual(result.number, Decimal(0))
        XCTAssertEqual(result.decimalDigits, 0)
    }

    func testPlusSameCurrency() {
        let fifteenEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(15)], decimalDigits: [TestUtils.eur: 0])
        let tenEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10)], decimalDigits: [TestUtils.eur: 0])
        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        XCTAssertEqual(fiveEuro + fiveEuro, tenEuro)
        XCTAssertEqual(fiveEuro + tenEuro, fifteenEuro)
        XCTAssertEqual(tenEuro + fiveEuro, fifteenEuro)
        var result = tenEuro
        result += fiveEuro
        XCTAssertEqual(result, fifteenEuro)
    }

    func testPlusDifferentCurrency() {
        let fiveEuroAndTenCanadianDollar = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5), TestUtils.cad: Decimal(10)],
                                                               decimalDigits: [TestUtils.eur: 0, TestUtils.cad: 0])
        let tenCanadianDollar = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(10)], decimalDigits: [TestUtils.cad: 0])
        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        XCTAssertEqual(fiveEuro + tenCanadianDollar, fiveEuroAndTenCanadianDollar)
        XCTAssertEqual(tenCanadianDollar + fiveEuro, fiveEuroAndTenCanadianDollar)
        var result = tenCanadianDollar
        result += fiveEuro
        XCTAssertEqual(result, fiveEuroAndTenCanadianDollar)
    }

    func testPlusEmpty() {
        let nothing = MultiCurrencyAmount()
        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        XCTAssertEqual(nothing + nothing, nothing)
        XCTAssertEqual(fiveEuro + nothing, fiveEuro)
        XCTAssertEqual(nothing + fiveEuro, fiveEuro)
        var result = nothing
        result += fiveEuro
        XCTAssertEqual(result, fiveEuro)
    }

    func testPlusDecimalDigits() {
        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        let fiveEuroZero = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5.0)], decimalDigits: [TestUtils.eur: 1])
        let fiveEuroZeroZero = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5.00)], decimalDigits: [TestUtils.eur: 2])
        let fiveCanadianDollar = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5)], decimalDigits: [TestUtils.cad: 0])

        var result = fiveEuro + fiveEuroZeroZero
        XCTAssertEqual(result.amounts[TestUtils.eur]!, 10)
        XCTAssertEqual(result.decimalDigits[TestUtils.eur]!, 0)
        result = fiveEuro
        result += fiveEuroZeroZero
        XCTAssertEqual(result.amounts[TestUtils.eur]!, 10)
        XCTAssertEqual(result.decimalDigits[TestUtils.eur]!, 0)

        result = fiveEuroZero + fiveEuroZeroZero
        XCTAssertEqual(result.amounts[TestUtils.eur]!, 10)
        XCTAssertEqual(result.decimalDigits[TestUtils.eur]!, 2)
        result = fiveEuroZero
        result += fiveEuroZeroZero
        XCTAssertEqual(result.amounts[TestUtils.eur]!, 10)
        XCTAssertEqual(result.decimalDigits[TestUtils.eur]!, 2)

        result = fiveCanadianDollar + fiveEuroZeroZero
        XCTAssertEqual(result.decimalDigits[TestUtils.eur]!, 2)
        XCTAssertEqual(result.decimalDigits[TestUtils.cad]!, 0)
        result = fiveCanadianDollar
        result += fiveEuroZeroZero
        XCTAssertEqual(result.decimalDigits[TestUtils.eur]!, 2)
        XCTAssertEqual(result.decimalDigits[TestUtils.cad]!, 0)
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
        let test = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(8.525_0)], decimalDigits: [TestUtils.cad: 5])
        XCTAssertEqual((empty + test).decimalDigits[TestUtils.cad]!, 5)

        var result = empty
        result += test

        XCTAssertEqual(result.decimalDigits[TestUtils.cad]!, 5)
    }

    func testEqual() {
        let nothing = MultiCurrencyAmount()
        XCTAssertEqual(nothing, nothing)

        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        XCTAssertEqual(fiveEuro, fiveEuro)
        XCTAssertNotEqual(nothing, fiveEuro)

        let fiveCanadianDollar1 = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5)], decimalDigits: [TestUtils.cad: 0])
        let fiveCanadianDollar2 = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5)], decimalDigits: [TestUtils.cad: 0])
        XCTAssertEqual(fiveCanadianDollar1, fiveCanadianDollar2)
        XCTAssertNotEqual(fiveCanadianDollar1, fiveEuro)
        XCTAssertNotEqual(fiveCanadianDollar1, nothing)

        let fiveEuroAndFiveCanadianDollar1 = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5), TestUtils.cad: Decimal(10)],
                                                                 decimalDigits: [TestUtils.eur: 0, TestUtils.cad: 0])
        let fiveEuroAndFiveCanadianDollar2 = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5), TestUtils.cad: Decimal(10)],
                                                                 decimalDigits: [TestUtils.eur: 0, TestUtils.cad: 0])
        XCTAssertEqual(fiveEuroAndFiveCanadianDollar1, fiveEuroAndFiveCanadianDollar2)
        XCTAssertNotEqual(fiveEuroAndFiveCanadianDollar1, fiveEuro)
        XCTAssertNotEqual(fiveEuroAndFiveCanadianDollar1, fiveCanadianDollar1)
        XCTAssertNotEqual(fiveEuroAndFiveCanadianDollar1, nothing)
    }

    func testEqualDecimalDigits() {
        let fiveTwentyFife1 = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5.25)], decimalDigits: [TestUtils.cad: 2])
        let fiveTwentyFife2 = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5.25)], decimalDigits: [TestUtils.cad: 2])
        XCTAssertEqual(fiveTwentyFife1, fiveTwentyFife2)

        let fiveTwentyFifeZero = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5.250)], decimalDigits: [TestUtils.cad: 3])
        XCTAssertNotEqual(fiveTwentyFife1, fiveTwentyFifeZero)
    }

    func testValidateZeroWithTolerance() {
        let commodity = TestUtils.cad
        var amount = MultiCurrencyAmount(amounts: [:], decimalDigits: [:])
        guard case .valid = amount.validateZeroWithTolerance() else {
            XCTFail("\(amount) is not valid")
            return
        }
        XCTAssertTrue(amount.isZeroWithTolerance())

        amount = MultiCurrencyAmount(amounts: [commodity: 0], decimalDigits: [:])
        guard case .valid = amount.validateZeroWithTolerance() else {
            XCTFail("\(amount) is not valid")
            return
        }
        XCTAssertTrue(amount.isZeroWithTolerance())

        amount = MultiCurrencyAmount(amounts: [commodity: 0.000_05], decimalDigits: [:])
        if case .invalid(let error) = amount.validateZeroWithTolerance() {
            XCTAssertEqual(error, "0.00005 CAD too much (0 tolerance)")
        } else {
            XCTFail("\(amount) is valid")
        }
        XCTAssertFalse(amount.isZeroWithTolerance())

        amount = MultiCurrencyAmount(amounts: [commodity: 0.000_05], decimalDigits: [commodity: 5])
        if case .invalid(let error) = amount.validateZeroWithTolerance() {
            XCTAssertEqual(error, "0.00005 CAD too much (0.000005 tolerance)")
        } else {
            XCTFail("\(amount) is valid")
        }
        XCTAssertFalse(amount.isZeroWithTolerance())

        amount = MultiCurrencyAmount(amounts: [commodity: 0.000_05], decimalDigits: [commodity: 4])
        guard case .valid = amount.validateZeroWithTolerance() else {
            XCTFail("\(amount) is not valid")
            return
        }
        XCTAssertTrue(amount.isZeroWithTolerance())
    }

    func testValidateOneAmountWithTolerance() {
        let commoditySymbol = TestUtils.cad
        var multiCurrencyAmount = MultiCurrencyAmount(amounts: [:], decimalDigits: [:])

        var amount = Amount(number: 0, commoditySymbol: commoditySymbol, decimalDigits: 0)
        guard case .valid = multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) else {
            XCTFail("\(multiCurrencyAmount) is not valid")
            return
        }

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [commoditySymbol: 0], decimalDigits: [:])
        guard case .valid = multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) else {
            XCTFail("\(multiCurrencyAmount) is not valid")
            return
        }

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [commoditySymbol: 0.000_05], decimalDigits: [commoditySymbol: 5])
        if case .invalid(let error) = multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) {
            XCTAssertEqual(error, "-0.00005 CAD too much (0 tolerance)")
        } else {
            XCTFail("\(multiCurrencyAmount) is valid")
        }

        amount = Amount(number: 0, commoditySymbol: commoditySymbol, decimalDigits: 1)
        if case .invalid(let error) = multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) {
            XCTAssertEqual(error, "-0.00005 CAD too much (0.000005 tolerance)")
        } else {
            XCTFail("\(multiCurrencyAmount) is valid")
        }

        amount = Amount(number: 0.000_05, commoditySymbol: commoditySymbol, decimalDigits: 5)
        guard case .valid = multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) else {
            XCTFail("\(multiCurrencyAmount) is not valid")
            return
        }

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [commoditySymbol: 0.000_055], decimalDigits: [commoditySymbol: 5])
        guard case .valid = multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) else {
            XCTFail("\(multiCurrencyAmount) is not valid")
            return
        }
    }

}
