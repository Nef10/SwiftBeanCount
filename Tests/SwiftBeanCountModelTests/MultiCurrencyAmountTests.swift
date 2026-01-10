//
//  MultiCurrencyAmountTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-07-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite

struct MultiCurrencyAmountTests {

    func testInit() {
        let multiCurrencyAmount = MultiCurrencyAmount()
        #expect(multiCurrencyAmount.amounts == [:])
    }

    func testMultiCurrencyAmount() {
        let multiCurrencyAmount = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10)], decimalDigits: [TestUtils.eur: 0])
        #expect(multiCurrencyAmount.multiCurrencyAmount == multiCurrencyAmount)
    }

    func testAmountFor() {
        var multiCurrencyAmount = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10)], decimalDigits: [TestUtils.eur: 3])
        var result = multiCurrencyAmount.amountFor(symbol: TestUtils.eur)
        #expect(result.commoditySymbol == TestUtils.eur)
        #expect(result.number == Decimal(10))
        #expect(result.decimalDigits == 3)
        result = multiCurrencyAmount.amountFor(symbol: TestUtils.usd)
        #expect(result.commoditySymbol == TestUtils.usd)
        #expect(result.number == Decimal(0))
        #expect(result.decimalDigits == 0)

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10), TestUtils.usd: Decimal(4)], decimalDigits: [TestUtils.eur: 3, TestUtils.usd: 0])
        result = multiCurrencyAmount.amountFor(symbol: TestUtils.eur)
        #expect(result.commoditySymbol == TestUtils.eur)
        #expect(result.number == Decimal(10))
        #expect(result.decimalDigits == 3)

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10), TestUtils.usd: Decimal(4)], decimalDigits: [TestUtils.eur: 3])
        result = multiCurrencyAmount.amountFor(symbol: TestUtils.usd)
        #expect(result.commoditySymbol == TestUtils.usd)
        #expect(result.number == Decimal(4))
        #expect(result.decimalDigits == 0)
    }

    func testPlusSameCurrency() {
        let fifteenEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(15)], decimalDigits: [TestUtils.eur: 0])
        let tenEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(10)], decimalDigits: [TestUtils.eur: 0])
        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        #expect(fiveEuro + fiveEuro == tenEuro)
        #expect(fiveEuro + tenEuro == fifteenEuro)
        #expect(tenEuro + fiveEuro == fifteenEuro)
        var result = tenEuro
        result += fiveEuro
        #expect(result == fifteenEuro)
    }

    func testPlusDifferentCurrency() {
        let fiveEuroAndTenCanadianDollar = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5), TestUtils.cad: Decimal(10)],
                                                               decimalDigits: [TestUtils.eur: 0, TestUtils.cad: 0])
        let tenCanadianDollar = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(10)], decimalDigits: [TestUtils.cad: 0])
        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        #expect(fiveEuro + tenCanadianDollar == fiveEuroAndTenCanadianDollar)
        #expect(tenCanadianDollar + fiveEuro == fiveEuroAndTenCanadianDollar)
        var result = tenCanadianDollar
        result += fiveEuro
        #expect(result == fiveEuroAndTenCanadianDollar)
    }

    func testPlusEmpty() {
        let nothing = MultiCurrencyAmount()
        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        #expect(nothing + nothing == nothing)
        #expect(fiveEuro + nothing == fiveEuro)
        #expect(nothing + fiveEuro == fiveEuro)
        var result = nothing
        result += fiveEuro
        #expect(result == fiveEuro)
    }

    func testPlusDecimalDigits() {
        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        let fiveEuroZero = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5.0)], decimalDigits: [TestUtils.eur: 1])
        let fiveEuroZeroZero = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5.00)], decimalDigits: [TestUtils.eur: 2])
        let fiveCanadianDollar = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5)], decimalDigits: [TestUtils.cad: 0])

        var result = fiveEuro + fiveEuroZeroZero
        #expect(result.amounts[TestUtils.eur]! == 10)
        #expect(result.decimalDigits[TestUtils.eur]! == 0)
        result = fiveEuro
        result += fiveEuroZeroZero
        #expect(result.amounts[TestUtils.eur]! == 10)
        #expect(result.decimalDigits[TestUtils.eur]! == 0)

        result = fiveEuroZero + fiveEuroZeroZero
        #expect(result.amounts[TestUtils.eur]! == 10)
        #expect(result.decimalDigits[TestUtils.eur]! == 2)
        result = fiveEuroZero
        result += fiveEuroZeroZero
        #expect(result.amounts[TestUtils.eur]! == 10)
        #expect(result.decimalDigits[TestUtils.eur]! == 2)

        result = fiveCanadianDollar + fiveEuroZeroZero
        #expect(result.decimalDigits[TestUtils.eur]! == 2)
        #expect(result.decimalDigits[TestUtils.cad]! == 0)
        result = fiveCanadianDollar
        result += fiveEuroZeroZero
        #expect(result.decimalDigits[TestUtils.eur]! == 2)
        #expect(result.decimalDigits[TestUtils.cad]! == 0)
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
        #expect((empty + test).decimalDigits[TestUtils.cad]! == 5)

        var result = empty
        result += test

        #expect(result.decimalDigits[TestUtils.cad]! == 5)
    }

    func testEqual() {
        let nothing = MultiCurrencyAmount()
        #expect(nothing == nothing)

        let fiveEuro = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5)], decimalDigits: [TestUtils.eur: 0])
        #expect(fiveEuro == fiveEuro)
        #expect(nothing != fiveEuro)

        let fiveCanadianDollar1 = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5)], decimalDigits: [TestUtils.cad: 0])
        let fiveCanadianDollar2 = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5)], decimalDigits: [TestUtils.cad: 0])
        #expect(fiveCanadianDollar1 == fiveCanadianDollar2)
        #expect(fiveCanadianDollar1 != fiveEuro)
        #expect(fiveCanadianDollar1 != nothing)

        let fiveEuroAndFiveCanadianDollar1 = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5), TestUtils.cad: Decimal(10)],
                                                                 decimalDigits: [TestUtils.eur: 0, TestUtils.cad: 0])
        let fiveEuroAndFiveCanadianDollar2 = MultiCurrencyAmount(amounts: [TestUtils.eur: Decimal(5), TestUtils.cad: Decimal(10)],
                                                                 decimalDigits: [TestUtils.eur: 0, TestUtils.cad: 0])
        #expect(fiveEuroAndFiveCanadianDollar1 == fiveEuroAndFiveCanadianDollar2)
        #expect(fiveEuroAndFiveCanadianDollar1 != fiveEuro)
        #expect(fiveEuroAndFiveCanadianDollar1 != fiveCanadianDollar1)
        #expect(fiveEuroAndFiveCanadianDollar1 != nothing)
    }

    func testEqualDecimalDigits() {
        let fiveTwentyFife1 = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5.25)], decimalDigits: [TestUtils.cad: 2])
        let fiveTwentyFife2 = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5.25)], decimalDigits: [TestUtils.cad: 2])
        #expect(fiveTwentyFife1 == fiveTwentyFife2)

        let fiveTwentyFifeZero = MultiCurrencyAmount(amounts: [TestUtils.cad: Decimal(5.250)], decimalDigits: [TestUtils.cad: 3])
        #expect(fiveTwentyFife1 != fiveTwentyFifeZero)
    }

    func testValidateZeroWithTolerance() {
        let commodity = TestUtils.cad
        var amount = MultiCurrencyAmount(amounts: [:], decimalDigits: [:])
        #expect(amount.validateZeroWithTolerance() == .valid)
        #expect(amount.isZeroWithTolerance())

        amount = MultiCurrencyAmount(amounts: [commodity: 0], decimalDigits: [:])
        #expect(amount.validateZeroWithTolerance() == .valid)
        #expect(amount.isZeroWithTolerance())

        amount = MultiCurrencyAmount(amounts: [commodity: 0.000_05], decimalDigits: [:])
        #expect(amount.validateZeroWithTolerance() == .invalid("0.00005 CAD too much (0 tolerance)"))
        #expect(!(amount.isZeroWithTolerance()))

        amount = MultiCurrencyAmount(amounts: [commodity: 0.000_05], decimalDigits: [commodity: 5])
        #expect(amount.validateZeroWithTolerance() == .invalid("0.00005 CAD too much (0.000005 tolerance)"))
        #expect(!(amount.isZeroWithTolerance()))

        amount = MultiCurrencyAmount(amounts: [commodity: 0.000_05], decimalDigits: [commodity: 4])
        #expect(amount.validateZeroWithTolerance() == .valid)
        #expect(amount.isZeroWithTolerance())
    }

    func testValidateOneAmountWithTolerance() {
        let commoditySymbol = TestUtils.cad
        var multiCurrencyAmount = MultiCurrencyAmount(amounts: [:], decimalDigits: [:])

        var amount = Amount(number: 0, commoditySymbol: commoditySymbol, decimalDigits: 0)
        #expect(multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) == .valid)

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [commoditySymbol: 0], decimalDigits: [:])
        #expect(multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) == .valid)

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [commoditySymbol: 0.000_05], decimalDigits: [commoditySymbol: 5])
        #expect(multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) == .invalid("-0.00005 CAD too much (0 tolerance)"))

        amount = Amount(number: 0, commoditySymbol: commoditySymbol, decimalDigits: 1)
        #expect(multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) == .invalid("-0.00005 CAD too much (0.000005 tolerance)"))

        amount = Amount(number: 0.000_05, commoditySymbol: commoditySymbol, decimalDigits: 5)
        #expect(multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) == .valid)

        multiCurrencyAmount = MultiCurrencyAmount(amounts: [commoditySymbol: 0.000_055], decimalDigits: [commoditySymbol: 5])
        #expect(multiCurrencyAmount.validateOneAmountWithTolerance(amount: amount) == .valid)
    }

}
