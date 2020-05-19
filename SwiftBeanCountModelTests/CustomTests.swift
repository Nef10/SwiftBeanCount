//
//  CustomTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class CustomTests: XCTestCase {

    let date1 = Date(timeIntervalSince1970: 1_496_905_200)
    let date2 = Date(timeIntervalSince1970: 1_496_991_600)

    func testEqual() {
        var custom1 = Custom(date: date1, name: "A", values: ["B"])
        var custom2 = Custom(date: date1, name: "A", values: ["B"])
        XCTAssertEqual(custom1, custom2)

        // meta data
        custom1.metaData["A"] = "B"
        XCTAssertNotEqual(custom1, custom2)
        custom2.metaData["A"] = "B"
        XCTAssertEqual(custom1, custom2)
        XCTAssertFalse(custom1 < custom2)
        XCTAssertFalse(custom2 < custom1)
    }

    func testEqualRespectsDate() {
        let custom1 = Custom(date: date1, name: "A", values: ["B"])
        let custom2 = Custom(date: date2, name: "A", values: ["B"])
        XCTAssertNotEqual(custom1, custom2)
        XCTAssert(custom1 < custom2)
        XCTAssertFalse(custom2 < custom1)
    }

    func testEqualRespectsName() {
        let custom1 = Custom(date: date1, name: "A", values: ["B"])
        let custom2 = Custom(date: date1, name: "C", values: ["B"])
        XCTAssertNotEqual(custom1, custom2)
        XCTAssert(custom1 < custom2)
        XCTAssertFalse(custom2 < custom1)
    }

    func testEqualRespectsValue() {
        let custom1 = Custom(date: date1, name: "A", values: ["B"])
        let custom2 = Custom(date: date1, name: "A", values: ["B", "C"])
        XCTAssertNotEqual(custom1, custom2)
        XCTAssert(custom1 < custom2)
        XCTAssertFalse(custom2 < custom1)
    }

    func testDescription() {
        var custom = Custom(date: date1, name: "name", values: ["B"])
        XCTAssertEqual(String(describing: custom), "2017-06-08 custom \"name\" \"B\"")
        custom.metaData["A"] = "B"
        XCTAssertEqual(String(describing: custom), "2017-06-08 custom \"name\" \"B\"\n  A: \"B\"")
    }

    func testDescriptionMultipleValues() {
        let custom = Custom(date: date1, name: "name", values: ["B", "C", "D"])
        XCTAssertEqual(String(describing: custom), "2017-06-08 custom \"name\" \"B\" \"C\" \"D\"")
    }

}
