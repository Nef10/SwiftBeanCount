//
//  ParserUtilsTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-08-22.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import XCTest

class ParserUtilsTests: XCTestCase {

    func testParseAmountDecimalFrom() {
        var (decimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: "1")
        XCTAssertEqual(decimal, Decimal(1))
        XCTAssertEqual(decimalDigits, 0)

        (decimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: "0.00")
        XCTAssertEqual(decimal, Decimal(0))
        XCTAssertEqual(decimalDigits, 2)

        (decimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: "+3.0")
        XCTAssertEqual(decimal, Decimal(3))
        XCTAssertEqual(decimalDigits, 1)

        (decimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: "-10.0000")
        XCTAssertEqual(decimal, Decimal(-10))
        XCTAssertEqual(decimalDigits, 4)

        (decimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: "1.25")
        XCTAssertEqual(decimal, Decimal(1.25))
        XCTAssertEqual(decimalDigits, 2)

        (decimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: "1,001.25")
        XCTAssertEqual(decimal, Decimal(1_001.25))
        XCTAssertEqual(decimalDigits, 2)
    }

    func testParseAmountFrom() {
        let commoditySymbol = "ABC"

        var amount = ParserUtils.parseAmountFrom(string: "1", commoditySymbol: commoditySymbol)
        XCTAssertEqual(amount.number, Decimal(1))
        XCTAssertEqual(amount.decimalDigits, 0)
        XCTAssertEqual(amount.commoditySymbol, commoditySymbol)

        amount = ParserUtils.parseAmountFrom(string: "0.00", commoditySymbol: commoditySymbol)
        XCTAssertEqual(amount.number, Decimal(0))
        XCTAssertEqual(amount.decimalDigits, 2)
        XCTAssertEqual(amount.commoditySymbol, commoditySymbol)

        amount = ParserUtils.parseAmountFrom(string: "+3.0", commoditySymbol: commoditySymbol)
        XCTAssertEqual(amount.number, Decimal(3))
        XCTAssertEqual(amount.decimalDigits, 1)
        XCTAssertEqual(amount.commoditySymbol, commoditySymbol)

        amount = ParserUtils.parseAmountFrom(string: "-10.0000", commoditySymbol: commoditySymbol)
        XCTAssertEqual(amount.number, Decimal(-10))
        XCTAssertEqual(amount.decimalDigits, 4)
        XCTAssertEqual(amount.commoditySymbol, commoditySymbol)

        amount = ParserUtils.parseAmountFrom(string: "1.25", commoditySymbol: commoditySymbol)
        XCTAssertEqual(amount.number, Decimal(1.25))
        XCTAssertEqual(amount.decimalDigits, 2)
        XCTAssertEqual(amount.commoditySymbol, commoditySymbol)

        amount = ParserUtils.parseAmountFrom(string: "1,001.25", commoditySymbol: commoditySymbol)
        XCTAssertEqual(amount.number, Decimal(1_001.25))
        XCTAssertEqual(amount.decimalDigits, 2)
        XCTAssertEqual(amount.commoditySymbol, commoditySymbol)
    }

}
