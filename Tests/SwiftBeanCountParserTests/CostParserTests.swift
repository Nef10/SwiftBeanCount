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
   func testCost() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                                 date: TestUtils.date20170609,
                                 label: "TEST"),
                       try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
    }

   @Test
   func testInvalid() {
        let postingMatches = "{2017-06-09, -1.003 EUR, \"TEST\"}".matchingStrings(regex: Self.regex)
        guard let match = postingMatches[safe: 0] else {
            Issue.record("Invalid string")
            return
        }
        do { _ = try CostParser.parseFrom(match: match, startIndex: 1; Issue.record("Expected error") } catch { })
    }

   @Test
   func testNegativeAmount() {
        #expect(try cost(from: "2017-06-09, 1.003 EUR, \"TEST\"}" == nil))
        #expect(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"" == nil))
        #expect(try cost(from: "2017-06-09, 1.003 EUR, \"TEST\"" == nil))
    }

   @Test
   func testEmpty() throws {
        #expect(try Cost(amount: nil == date: nil, label: nil), try cost(from: "{}"))
    }

   @Test
   func testEmptyStringLabel() throws {
        let parsedCost = try cost(from: "{\"\"}")
        #expect(try Cost(amount: nil == date: nil, label: ""), parsedCost)
        #expect(try Cost(amount: nil != date: nil, label: nil), parsedCost)
    }

   @Test
   func testWithoutDate() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                            date: nil,
                            label: "TEST"),
                       try cost(from: "{1.003 EUR, \"TEST\"}"))
    }

   @Test
   func testWithoutLabel() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                                 date: TestUtils.date20170609,
                                 label: nil),
                       try cost(from: "{2017-06-09, 1.003 EUR}"))
    }

   @Test
   func testWithoutAmount() throws {
        XCTAssertEqual(try Cost(amount: nil,
                                date: TestUtils.date20170609,
                                label: "TEST"),
                       try cost(from: "{2017-06-09, \"TEST\"}"))
    }

   @Test
   func testOnlyDate() throws {
        XCTAssertEqual(try Cost(amount: nil,
                                date: TestUtils.date20170609,
                                label: nil),
                       try cost(from: "{2017-06-09}"))
    }

   @Test
   func testOnlyLabel() throws {
        XCTAssertEqual(try Cost(amount: nil,
                                date: nil,
                                label: "TEST"),
                       try cost(from: "{\"TEST\"}"))
    }

   @Test
   func testOnlyAmount() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "EUR",
                                               decimalDigits: 3),
                            date: nil,
                            label: nil),
                       try cost(from: "{1.003 EUR}"))
    }

   @Test
   func testOrder() throws {
        let result = try Cost(amount: Amount(number: Decimal(1.003),
                                             commoditySymbol: "EUR",
                                             decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        #expect(result == try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
        #expect(result == try cost(from: "{2017-06-09, \"TEST\", 1.003 EUR}"))
        #expect(result == try cost(from: "{1.003 EUR, 2017-06-09, \"TEST\"}"))
        #expect(result == try cost(from: "{1.003 EUR, \"TEST\", 2017-06-09}"))
        #expect(result == try cost(from: "{\"TEST\", 2017-06-09, 1.003 EUR}"))
        #expect(result == try cost(from: "{\"TEST\", 1.003 EUR, 2017-06-09}"))
    }

   @Test
   func testWhitespace() throws {
        let result = try Cost(amount: Amount(number: Decimal(1.003),
                                             commoditySymbol: "EUR",
                                             decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        // Note: Because a commodity may contain commas there must be a space a either before or after the comma which follows the commodity
        #expect(result == try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
        #expect(result == try cost(from: "{2017-06-09,1.003 EUR, \"TEST\"}"))
        #expect(result == try cost(from: "{2017-06-09,    1.003 EUR,     \"TEST\"}"))
        #expect(result == try cost(from: "{   2017-06-09, 1.003 EUR, \"TEST\"    }"))
        #expect(result == try cost(from: "{ 2017-06-09,1.003 EUR, \"TEST\" }"))
        #expect(result == try cost(from: "{2017-06-09 , 1.003 EUR , \"TEST\"}"))
        #expect(result == try cost(from: "{2017-06-09 ,1.003 EUR , \"TEST\"}"))
        #expect(result == try cost(from: "{2017-06-09    ,    1.003 EUR ,     \"TEST\"}"))
        #expect(result == try cost(from: "{   2017-06-09    ,    1.003 EUR   ,  \"TEST\"    }"))
        #expect(result == try cost(from: "{2017-06-09, 1.003 EUR ,\"TEST\" }"))
        #expect(result == try cost(from: "{2017-06-09,1.003 EUR ,\"TEST\"}"))
    }

   @Test
   func testCommaCommodity() throws {
        let result = try Cost(amount: Amount(number: Decimal(1.003),
                                             commoditySymbol: "EUR,AB",
                                             decimalDigits: 3),
                               date: TestUtils.date20170609,
                               label: "TEST")
        #expect(result == try cost(from: "{2017-06-09, 1.003 EUR,AB, \"TEST\"}"))
        #expect(result == try cost(from: "{2017-06-09, 1.003 EUR,AB , \"TEST\"}"))
        #expect(result == try cost(from: "{2017-06-09, 1.003 EUR,AB ,\"TEST\"}"))
    }

   @Test
   func testSpecialCharacters() throws {
        XCTAssertEqual(try Cost(amount: Amount(number: Decimal(1.003),
                                               commoditySymbol: "💰",
                                               decimalDigits: 3),
                                 date: TestUtils.date20170609,
                                 label: "TES😀"),
                       try cost(from: "{2017-06-09, 1.003 💰, \"TES😀\"}"))
    }

   @Test
   func testUnexpectedElements() throws {
        // These should throw errors because they contain unexpected elements

        // Test with unexpected text after valid elements
        do { _ = try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\", unexpected}"; Issue.record("Expected error") } catch { })

        // Test with unexpected numbers
        do { _ = try cost(from: "{2017-06-09, 1.003 EUR, 123}"; Issue.record("Expected error") } catch { })

        // Test with unexpected symbols
        do { _ = try cost(from: "{2017-06-09, 1.003 EUR, @invalid}"; Issue.record("Expected error") } catch { })

        // Test with multiple unexpected elements
        do { _ = try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\", extra, stuff}"; Issue.record("Expected error") } catch { })

        // Test with unexpected text in different positions
        do { _ = try cost(from: "{unexpected, 2017-06-09, 1.003 EUR}"; Issue.record("Expected error") } catch { })
        do { _ = try cost(from: "{2017-06-09, unexpected, 1.003 EUR}"; Issue.record("Expected error") } catch { })

        // Test that valid costs still work (should not throw)
        XCTAssertNoThrow(try cost(from: "{2017-06-09, 1.003 EUR, \"TEST\"}"))
        XCTAssertNoThrow(try cost(from: "{\"TEST\"}"))
        XCTAssertNoThrow(try cost(from: "{2017-06-09}"))
        XCTAssertNoThrow(try cost(from: "{1.003 EUR}"))
        XCTAssertNoThrow(try cost(from: "{}"))
    }

   @Test
   func testCostParsingErrorDescription() throws {
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
