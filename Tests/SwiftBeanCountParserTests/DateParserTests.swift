//
//  DateParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-17.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountParser
import XCTest

final class DateParserTests: XCTestCase {

    func testNormalParsing() {
        let date = DateParser.parseFrom(string: "2017-06-09")
        XCTAssertEqual(date, TestUtils.date20170609)
    }

    func testInvalidDate() {
        let date = DateParser.parseFrom(string: "2017-00-09")
        XCTAssertNil(date)
    }

    func testNonExistentDate() {
        let date = DateParser.parseFrom(string: "2017-02-30")
        XCTAssertNil(date)
    }

}
