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

class CostParserTests: XCTestCase {

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

}
