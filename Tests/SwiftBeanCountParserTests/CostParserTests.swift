//
//  CostParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-09-13.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import Testing

@Suite
struct CostParserTests {

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

    @Test
    func cost() throws {
        let expected = try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        #expect(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}") == expected)
    }

    @Test
    func invalid() {
        let postingMatches = "{2017-06-09, -1.003 EUR, \"TEST\"}".matchingStrings(regex: Self.regex)
        guard let match = postingMatches[safe: 0] else {
            Issue.record("Invalid string")
            return
        }
        #expect(throws: (any Error).self) { try CostParser.parseFrom(match: match, startIndex: 1) }
    }

    @Test
    func negativeAmount() throws {
        #expect(try cost(from: "2017-06-09, 1.003 EUR, \"TEST\"}") == nil)
        #expect(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"") == nil)
        #expect(try cost(from: "2017-06-09, 1.003 EUR, \"TEST\"") == nil)
    }

    @Test
    func empty() throws {
        let expected = try Cost(amount: nil, date: nil, label: nil)
        #expect(try cost(from: "{}") == expected)
    }

    @Test
    func emptyStringLabel() throws {
        let parsedCost = try cost(from: "{\"\"}")
        let expected1 = try Cost(amount: nil, date: nil, label: "")
        let expected2 = try Cost(amount: nil, date: nil, label: nil)
        #expect(expected1 == parsedCost)
        #expect(expected2 == parsedCost)
    }

    @Test
    func withoutDate() throws {
        let expected = try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                               date: nil,
                               label: "TEST")
        #expect(try cost(from: "{1.003 EUR, \"TEST\"}") == expected)
    }

    @Test
    func withoutLabel() throws {
        let expected = try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: nil)
        #expect(try cost(from: "{2017-06-09, 1.003 EUR}") == expected)
    }

    @Test
    func withoutAmount() throws {
        let expected = try Cost(amount: nil,
                                date: TestUtils.date20170609,
                                label: "TEST")
        #expect(try cost(from: "{2017-06-09, \"TEST\"}") == expected)
    }

    @Test
    func onlyDate() throws {
        let expected = try Cost(amount: nil,
                                date: TestUtils.date20170609,
                                label: nil)
        #expect(try cost(from: "{2017-06-09}") == expected)
    }

    @Test
    func onlyLabel() throws {
        let expected = try Cost(amount: nil,
                                date: nil,
                                label: "TEST")
        #expect(try cost(from: "{\"TEST\"}") == expected)
    }

    @Test
    func onlyAmount() throws {
        let expected = try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                               date: nil,
                               label: nil)
        #expect(try cost(from: "{1.003 EUR}") == expected)
    }

    @Test
    func order() throws {
        let result = try Cost(amount: Amount(number: Decimal(1.003),
                                             commoditySymbol: "EUR",
                                             decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        #expect(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}") == result)
        #expect(try cost(from: "{2017-06-09, \"TEST\", 1.003 EUR}") == result)
        #expect(try cost(from: "{1.003 EUR, 2017-06-09, \"TEST\"}") == result)
        #expect(try cost(from: "{1.003 EUR, \"TEST\", 2017-06-09}") == result)
        #expect(try cost(from: "{\"TEST\", 2017-06-09, 1.003 EUR}") == result)
        #expect(try cost(from: "{\"TEST\", 1.003 EUR, 2017-06-09}") == result)
    }

    @Test
    func whitespace() throws {
        let result = try Cost(amount: Amount(number: Decimal(1.003),
                                             commoditySymbol: "EUR",
                                             decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        // Note: Because a commodity may contain commas there must be a space a either before or after the comma which follows the commodity
        #expect(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}") == result)
        #expect(try cost(from: "{2017-06-09,1.003 EUR, \"TEST\"}") == result)
        #expect(try cost(from: "{2017-06-09,    1.003 EUR,     \"TEST\"}") == result)
        #expect(try cost(from: "{   2017-06-09, 1.003 EUR, \"TEST\"    }") == result)
        #expect(try cost(from: "{ 2017-06-09,1.003 EUR, \"TEST\" }") == result)
        #expect(try cost(from: "{2017-06-09 , 1.003 EUR , \"TEST\"}") == result)
        #expect(try cost(from: "{2017-06-09 ,1.003 EUR , \"TEST\"}") == result)
        #expect(try cost(from: "{2017-06-09    ,    1.003 EUR ,     \"TEST\"}") == result)
        #expect(try cost(from: "{   2017-06-09    ,    1.003 EUR   ,  \"TEST\"    }") == result)
        #expect(try cost(from: "{2017-06-09, 1.003 EUR ,\"TEST\" }") == result)
        #expect(try cost(from: "{2017-06-09,1.003 EUR ,\"TEST\"}") == result)
    }

    @Test
    func commaCommodity() throws {
        let result = try Cost(amount: Amount(number: Decimal(1.003),
                                             commoditySymbol: "EUR,AB",
                                             decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        #expect(try cost(from: "{2017-06-09, 1.003 EUR,AB, \"TEST\"}") == result)
        #expect(try cost(from: "{2017-06-09, 1.003 EUR,AB , \"TEST\"}") == result)
        #expect(try cost(from: "{2017-06-09, 1.003 EUR,AB ,\"TEST\"}") == result)
    }

    @Test
    func specialCharacters() throws {
        let expected = try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "💰",
                                               decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TES😀")
        #expect(try cost(from: "{2017-06-09, 1.003 💰, \"TES😀\"}") == expected)
    }

    @Test
    func unexpectedElements() throws {
        // These should throw errors because they contain unexpected elements

        // Test with unexpected text after valid elements
        #expect(throws: (any Error).self) { try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\", unexpected}") }

        // Test with unexpected numbers
        #expect(throws: (any Error).self) { try cost(from: "{2017-06-09, 1.003 EUR, 123}") }

        // Test with unexpected symbols
        #expect(throws: (any Error).self) { try cost(from: "{2017-06-09, 1.003 EUR, @invalid}") }

        // Test with multiple unexpected elements
        #expect(throws: (any Error).self) { try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\", extra, stuff}") }

        // Test with unexpected text in different positions
        #expect(throws: (any Error).self) { try cost(from: "{unexpected, 2017-06-09, 1.003 EUR}") }
        #expect(throws: (any Error).self) { try cost(from: "{2017-06-09, unexpected, 1.003 EUR}") }

        // Test that valid costs still work (should not throw)
        #expect(throws: Never.self) { try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}") }
        #expect(throws: Never.self) { try cost(from: "{\"TEST\"}") }
        #expect(throws: Never.self) { try cost(from: "{2017-06-09}") }
        #expect(throws: Never.self) { try cost(from: "{1.003 EUR}") }
        #expect(throws: Never.self) { try cost(from: "{}") }
    }

    @Test
    func costParsingErrorDescription() throws {
        // Test the errorDescription property of CostParsingError
        do {
            _ = try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\", unexpected}")
            Issue.record("Expected CostParsingError to be thrown")
        } catch let error as CostParsingError {
            #expect(error.errorDescription == "Unexpected elements in cost: unexpected")
        } catch {
            Issue.record("Expected CostParsingError, but got: \(error)")
        }
    }

}
