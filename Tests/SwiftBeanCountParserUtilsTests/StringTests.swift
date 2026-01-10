//
//  StringTests.swift
//  SwiftBeanCountParserUtilsTests
//
//  Created by Steffen Kötte on 2021-09-08.
//  Copyright © 2017-2021 Steffen Kötte. All rights reserved.
//


import Foundation
@testable import SwiftBeanCountParserUtils
import Testing

@Suite
struct StringTests {

    @Test
   @Test

   func matchingStrings_multipleGroups() throws {
        let regex = try NSRegularExpression(pattern: "^\\s+([^\\s]+:[^\\s]+)\\s+(-?[0-9]+(.[0-9]+)?)\\s+([^\\s]+)\\s*(;.*)?$", options: [])
        let results = "  Assets:Checking 1.00 EUR".matchingStrings(regex: regex)
        #expect(results.count == 1)
        #expect(results[0] == ["  Assets:Checking 1.00 EUR", "Assets:Checking", "1.00", ".00", "EUR", ""])
    }

    @Test
   @Test

   func matchingStrings_multipleResults() throws {
        let regex = try NSRegularExpression(pattern: "\\d\\D\\d", options: [])
        let results = "0a01b1".matchingStrings(regex: regex)
        #expect(results.count == 2)
        #expect(results[0] == ["0a0"])
        #expect(results[1] == ["1b1"])
    }

    @Test
   @Test

   func matchingStrings_ExtendedGraphemeClusters() throws {
        var regex = try NSRegularExpression(pattern: "[0-9]", options: [])
        var results = "🇩🇪€4€9".matchingStrings(regex: regex)
        #expect(results.count == 2)
        #expect(results[0] == ["4"])
        #expect(results[1] == ["9"])

        regex = try NSRegularExpression(pattern: "🇩🇪", options: [])
        results = "🇩🇪€4€9".matchingStrings(regex: regex)
        #expect(results.count == 1)
        #expect(results[0] == ["🇩🇪"])
    }

    @Test
   @Test

   func amountDecimal() {
        var (decimal, decimalDigits) = "1".amountDecimal()
        #expect(decimal == Decimal(1))
        #expect(decimalDigits == 0)

        (decimal, decimalDigits) = "0.00".amountDecimal()
        #expect(decimal == Decimal(0))
        #expect(decimalDigits == 2)

        (decimal, decimalDigits) = "+3.0".amountDecimal()
        #expect(decimal == Decimal(3))
        #expect(decimalDigits == 1)

        (decimal, decimalDigits) = "-10.0000".amountDecimal()
        #expect(decimal == Decimal(-10))
        #expect(decimalDigits == 4)

        (decimal, decimalDigits) = "1.25".amountDecimal()
        #expect(decimal == Decimal(1.25))
        #expect(decimalDigits == 2)

        (decimal, decimalDigits) = "1,001.25".amountDecimal()
        #expect(decimal == Decimal(1_001.25))
        #expect(decimalDigits == 2)
    }

}
