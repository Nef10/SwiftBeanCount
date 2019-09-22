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

    static let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "\(CostParser.costGroup)", options: [])
    }()

    func cost(from line: String) -> Cost? {
        let postingMatches = line.matchingStrings(regex: Self.regex)
        guard let match = postingMatches[safe: 0] else {
            return nil
        }
        return try! CostParser.parseFrom(match: match, startIndex: 1)
    }

    func testCost() {
        XCTAssertEqual(try! Cost(amount: Amount(number: Decimal(1.003),
                                                commodity: Commodity(symbol: "EUR"),
                                                decimalDigits: 3),
                                 date: TestUtils.date20170609,
                                 label: "TEST"),
                       cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
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
        XCTAssertNil(cost(from: "2017-06-09, 1.003 EUR, \"TEST\"}"))
        XCTAssertNil(cost(from: "{2017-06-09, 1.003 EUR, \"TEST\""))
        XCTAssertNil(cost(from: "2017-06-09, 1.003 EUR, \"TEST\""))
    }

    func testEmpty() {
        XCTAssertEqual(try! Cost(amount: nil, date: nil, label: nil), cost(from: "{}"))
    }

    func testEmptyStringLabel() {
        let parsedCost = cost(from: "{\"\"}")
        XCTAssertEqual(try! Cost(amount: nil, date: nil, label: ""), parsedCost)
        XCTAssertNotEqual(try! Cost(amount: nil, date: nil, label: nil), parsedCost)
    }

    func testWithoutDate() {
        XCTAssertEqual(try! Cost(amount: Amount(number: Decimal(1.003),
                                                commodity: Commodity(symbol: "EUR"),
                                                decimalDigits: 3),
                            date: nil,
                            label: "TEST"),
                       cost(from: "{1.003 EUR, \"TEST\"}"))
    }

    func testWithoutLabel() {
        XCTAssertEqual(try! Cost(amount: Amount(number: Decimal(1.003),
                                                commodity: Commodity(symbol: "EUR"),
                                                decimalDigits: 3),
                                 date: TestUtils.date20170609,
                                 label: nil),
                       cost(from: "{2017-06-09, 1.003 EUR}"))
    }

    func testWithoutAmount() {
        XCTAssertEqual(try! Cost(amount: nil,
                                 date: TestUtils.date20170609,
                                 label: "TEST"),
                       cost(from: "{2017-06-09, \"TEST\"}"))
    }

    func testOnlyDate() {
        XCTAssertEqual(try! Cost(amount: nil,
                                 date: TestUtils.date20170609,
                                 label: nil),
                       cost(from: "{2017-06-09}"))
    }

    func testOnlyLabel() {
        XCTAssertEqual(try! Cost(amount: nil,
                                 date: nil,
                                 label: "TEST"),
                       cost(from: "{\"TEST\"}"))
    }

    func testOnlyAmount() {
        XCTAssertEqual(try! Cost(amount: Amount(number: Decimal(1.003),
                                                commodity: Commodity(symbol: "EUR"),
                                                decimalDigits: 3),
                            date: nil,
                            label: nil),
                       cost(from: "{1.003 EUR}"))
    }

    func testOrder() {
        let result = try! Cost(amount: Amount(number: Decimal(1.003),
                                              commodity: Commodity(symbol: "EUR"),
                                              decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        XCTAssertEqual(result, cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{2017-06-09, \"TEST\", 1.003 EUR}"))
        XCTAssertEqual(result, cost(from: "{1.003 EUR, 2017-06-09, \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{1.003 EUR, \"TEST\", 2017-06-09}"))
        XCTAssertEqual(result, cost(from: "{\"TEST\", 2017-06-09, 1.003 EUR}"))
        XCTAssertEqual(result, cost(from: "{\"TEST\", 1.003 EUR, 2017-06-09}"))
    }

    func testWhitespace() {
        let result = try! Cost(amount: Amount(number: Decimal(1.003),
                                              commodity: Commodity(symbol: "EUR"),
                                              decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        // Note: Because a commodity may contain commas there must be a space a either before or after the comma which follows the commodity
        XCTAssertEqual(result, cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{2017-06-09,1.003 EUR, \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{2017-06-09,    1.003 EUR,     \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{   2017-06-09, 1.003 EUR, \"TEST\"    }"))
        XCTAssertEqual(result, cost(from: "{ 2017-06-09,1.003 EUR, \"TEST\" }"))
        XCTAssertEqual(result, cost(from: "{2017-06-09 , 1.003 EUR , \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{2017-06-09 ,1.003 EUR , \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{2017-06-09    ,    1.003 EUR ,     \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{   2017-06-09    ,    1.003 EUR   ,  \"TEST\"    }"))
        XCTAssertEqual(result, cost(from: "{2017-06-09, 1.003 EUR ,\"TEST\" }"))
        XCTAssertEqual(result, cost(from: "{2017-06-09,1.003 EUR ,\"TEST\"}"))
    }

    func testCommaCommodity() {
        let result = try! Cost(amount: Amount(number: Decimal(1.003),
                                              commodity: Commodity(symbol: "EUR,AB"),
                                              decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        XCTAssertEqual(result, cost(from: "{2017-06-09, 1.003 EUR,AB, \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{2017-06-09, 1.003 EUR,AB , \"TEST\"}"))
        XCTAssertEqual(result, cost(from: "{2017-06-09, 1.003 EUR,AB ,\"TEST\"}"))
    }

    func testSpecialCharacters() {
        XCTAssertEqual(try! Cost(amount: Amount(number: Decimal(1.003),
                                                commodity: Commodity(symbol: "💰"),
                                                decimalDigits: 3),
                                 date: TestUtils.date20170609,
                                 label: "TES😀"),
                       cost(from: "{2017-06-09, 1.003 💰, \"TES😀\"}"))
    }

}
