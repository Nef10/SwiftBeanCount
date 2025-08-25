//
//  CostParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-09-13.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

final class CostParserTests: XCTestCase {

    private static let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "\(CostParser.costGroup)", options: [])
    }()

    private func cost(from line: String) throws -> Cost? {
        let postingMatches = line.matchingStrings(regex: Self.regex)
        guard let match = postingMatches[safe: 0] else {
            return nil
        }
        return try CostParser.parseFrom(match: match, startIndex: 1)
    }

    func testCost() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                                 date: TestUtils.date20170609,
                                 label: "TEST"),
                       try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
    }

    func testInvalid() {
        let postingMatches = "{2017-06-09, -1.003 EUR, \"TEST\"}".matchingStrings(regex: Self.regex)
        guard let match = postingMatches[safe: 0] else {
            XCTFail("Invalid string")
            return
        }
        XCTAssertThrowsError(try CostParser.parseFrom(match: match, startIndex: 1))
    }

    func testNegativeAmount() {
        XCTAssertNil(try cost(from: "2017-06-09, 1.003 EUR, \"TEST\"}"))
        XCTAssertNil(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\""))
        XCTAssertNil(try cost(from: "2017-06-09, 1.003 EUR, \"TEST\""))
    }

    func testEmpty() throws {
        XCTAssertEqual(try Cost(amount: nil, date: nil, label: nil), try cost(from: "{}"))
    }

    func testEmptyStringLabel() throws {
        let parsedCost = try cost(from: "{\"\"}")
        XCTAssertEqual(try Cost(amount: nil, date: nil, label: ""), parsedCost)
        XCTAssertNotEqual(try Cost(amount: nil, date: nil, label: nil), parsedCost)
    }

    func testWithoutDate() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                            date: nil,
                            label: "TEST"),
                       try cost(from: "{1.003 EUR, \"TEST\"}"))
    }

    func testWithoutLabel() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                                 date: TestUtils.date20170609,
                                 label: nil),
                       try cost(from: "{2017-06-09, 1.003 EUR}"))
    }

    func testWithoutAmount() throws {
        XCTAssertEqual(try Cost(amount: nil,
                                date: TestUtils.date20170609,
                                label: "TEST"),
                       try cost(from: "{2017-06-09, \"TEST\"}"))
    }

    func testOnlyDate() throws {
        XCTAssertEqual(try Cost(amount: nil,
                                date: TestUtils.date20170609,
                                label: nil),
                       try cost(from: "{2017-06-09}"))
    }

    func testOnlyLabel() throws {
        XCTAssertEqual(try Cost(amount: nil,
                                date: nil,
                                label: "TEST"),
                       try cost(from: "{\"TEST\"}"))
    }

    func testOnlyAmount() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                            date: nil,
                            label: nil),
                       try cost(from: "{1.003 EUR}"))
    }

    func testOrder() throws {
        let result = try Cost(amount: Amount(number: Decimal(1.003),
                                             commoditySymbol: "EUR",
                                             decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        XCTAssertEqual(result, try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09, \"TEST\", 1.003 EUR}"))
        XCTAssertEqual(result, try cost(from: "{1.003 EUR, 2017-06-09, \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{1.003 EUR, \"TEST\", 2017-06-09}"))
        XCTAssertEqual(result, try cost(from: "{\"TEST\", 2017-06-09, 1.003 EUR}"))
        XCTAssertEqual(result, try cost(from: "{\"TEST\", 1.003 EUR, 2017-06-09}"))
    }

    func testWhitespace() throws {
        let result = try Cost(amount: Amount(number: Decimal(1.003),
                                             commoditySymbol: "EUR",
                                             decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        // Note: Because a commodity may contain commas there must be a space a either before or after the comma which follows the commodity
        XCTAssertEqual(result, try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09,1.003 EUR, \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09,    1.003 EUR,     \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{   2017-06-09, 1.003 EUR, \"TEST\"    }"))
        XCTAssertEqual(result, try cost(from: "{ 2017-06-09,1.003 EUR, \"TEST\" }"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09 , 1.003 EUR , \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09 ,1.003 EUR , \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09    ,    1.003 EUR ,     \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{   2017-06-09    ,    1.003 EUR   ,  \"TEST\"    }"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09, 1.003 EUR ,\"TEST\" }"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09,1.003 EUR ,\"TEST\"}"))
    }

    func testCommaCommodity() throws {
        let result = try Cost(amount: Amount(number: Decimal(1.003),
                                             commoditySymbol: "EUR,AB",
                                             decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        XCTAssertEqual(result, try cost(from: "{2017-06-09, 1.003 EUR,AB, \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09, 1.003 EUR,AB , \"TEST\"}"))
        XCTAssertEqual(result, try cost(from: "{2017-06-09, 1.003 EUR,AB ,\"TEST\"}"))
    }

    func testSpecialCharacters() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "💰",
                                               decimalDigits: 3),
                                 date: TestUtils.date20170609,
                                 label: "TES😀"),
                       try cost(from: "{2017-06-09, 1.003 💰, \"TES😀\"}"))
    }

    func testUnexpectedElements() throws {
        // These should throw errors because they contain unexpected elements

        // Test with unexpected text after valid elements
        XCTAssertThrowsError(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\", unexpected}"))

        // Test with unexpected numbers
        XCTAssertThrowsError(try cost(from: "{2017-06-09, 1.003 EUR, 123}"))

        // Test with unexpected symbols
        XCTAssertThrowsError(try cost(from: "{2017-06-09, 1.003 EUR, @invalid}"))

        // Test with multiple unexpected elements
        XCTAssertThrowsError(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\", extra, stuff}"))

        // Test with unexpected text in different positions
        XCTAssertThrowsError(try cost(from: "{unexpected, 2017-06-09, 1.003 EUR}"))
        XCTAssertThrowsError(try cost(from: "{2017-06-09, unexpected, 1.003 EUR}"))

        // Test that valid costs still work (should not throw)
        XCTAssertNoThrow(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
        XCTAssertNoThrow(try cost(from: "{\"TEST\"}"))
        XCTAssertNoThrow(try cost(from: "{2017-06-09}"))
        XCTAssertNoThrow(try cost(from: "{1.003 EUR}"))
        XCTAssertNoThrow(try cost(from: "{}"))
    }

    func testCostParsingErrorDescription() throws {
        // Test the errorDescription property of CostParsingError
        do {
            _ = try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\", unexpected}")
            XCTFail("Expected CostParsingError to be thrown")
        } catch let error as CostParsingError {
            XCTAssertEqual(error.errorDescription, "Unexpected elements in cost: unexpected")
        } catch {
            XCTFail("Expected CostParsingError, but got: \(error)")
        }
    }

}
