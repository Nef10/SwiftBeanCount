//
//  PriceParserParserUtilsTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2020-07-26.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class ParserUtilsTests: XCTestCase {

    func testMatchRegexIn_multipleGroups() {
        // swiftlint:disable:next force_try
        let regex = try! NSRegularExpression(pattern: "^\\s+([^\\s]+:[^\\s]+)\\s+(-?[0-9]+(.[0-9]+)?)\\s+([^\\s]+)\\s*(;.*)?$", options: [])
        let results = ParserUtils.match(regex: regex, in: "  Assets:Checking 1.00 EUR")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0], ["  Assets:Checking 1.00 EUR", "Assets:Checking", "1.00", ".00", "EUR", ""])
    }

    func testMatchRegexIn_multipleResults() {
        // swiftlint:disable:next force_try
        let regex = try! NSRegularExpression(pattern: "\\d\\D\\d", options: [])
        let results = ParserUtils.match(regex: regex, in: "0a01b1")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], ["0a0"])
        XCTAssertEqual(results[1], ["1b1"])
    }

}
