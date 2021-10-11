//
//  StringTests.swift
//  SwiftBeanCountParserUtilsTests
//
//  Created by Steffen Kötte on 2021-09-08.
//  Copyright © 2017-2021 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountParserUtils
import XCTest

class StringTests: XCTestCase {

    func testMatchingStrings_multipleGroups() throws {
        let regex = try NSRegularExpression(pattern: "^\\s+([^\\s]+:[^\\s]+)\\s+(-?[0-9]+(.[0-9]+)?)\\s+([^\\s]+)\\s*(;.*)?$", options: [])
        let results = "  Assets:Checking 1.00 EUR".matchingStrings(regex: regex)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0], ["  Assets:Checking 1.00 EUR", "Assets:Checking", "1.00", ".00", "EUR", ""])
    }

    func testMatchingStrings_multipleResults() throws {
        let regex = try NSRegularExpression(pattern: "\\d\\D\\d", options: [])
        let results = "0a01b1".matchingStrings(regex: regex)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], ["0a0"])
        XCTAssertEqual(results[1], ["1b1"])
    }

    func testMatchingStrings_ExtendedGraphemeClusters() throws {
        var regex = try NSRegularExpression(pattern: "[0-9]", options: [])
        var results = "🇩🇪€4€9".matchingStrings(regex: regex)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], ["4"])
        XCTAssertEqual(results[1], ["9"])

        regex = try NSRegularExpression(pattern: "🇩🇪", options: [])
        results = "🇩🇪€4€9".matchingStrings(regex: regex)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0], ["🇩🇪"])
    }

    func testAmountDecimal() {
        var (decimal, decimalDigits) = "1".amountDecimal()
        XCTAssertEqual(decimal, Decimal(1))
        XCTAssertEqual(decimalDigits, 0)

        (decimal, decimalDigits) = "0.00".amountDecimal()
        XCTAssertEqual(decimal, Decimal(0))
        XCTAssertEqual(decimalDigits, 2)

        (decimal, decimalDigits) = "+3.0".amountDecimal()
        XCTAssertEqual(decimal, Decimal(3))
        XCTAssertEqual(decimalDigits, 1)

        (decimal, decimalDigits) = "-10.0000".amountDecimal()
        XCTAssertEqual(decimal, Decimal(-10))
        XCTAssertEqual(decimalDigits, 4)

        (decimal, decimalDigits) = "1.25".amountDecimal()
        XCTAssertEqual(decimal, Decimal(1.25))
        XCTAssertEqual(decimalDigits, 2)

        (decimal, decimalDigits) = "1,001.25".amountDecimal()
        XCTAssertEqual(decimal, Decimal(1_001.25))
        XCTAssertEqual(decimalDigits, 2)
    }

}
