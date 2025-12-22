//
//  CustomTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

final class CustomTests: XCTestCase {

    func testEqual() {
        var custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        var custom2 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        XCTAssertEqual(custom1, custom2)

        // meta data
        custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"], metaData: ["A": "B"])
        XCTAssertNotEqual(custom1, custom2)
        custom2 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"], metaData: ["A": "B"])
        XCTAssertEqual(custom1, custom2)
        XCTAssertFalse(custom1 < custom2)
        XCTAssertFalse(custom2 < custom1)
    }

    func testEqualRespectsDate() {
        let custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        let custom2 = Custom(date: TestUtils.date20170609, name: "A", values: ["B"])
        XCTAssertNotEqual(custom1, custom2)
        XCTAssert(custom1 < custom2)
        XCTAssertFalse(custom2 < custom1)
    }

    func testEqualRespectsName() {
        let custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        let custom2 = Custom(date: TestUtils.date20170608, name: "C", values: ["B"])
        XCTAssertNotEqual(custom1, custom2)
        XCTAssert(custom1 < custom2)
        XCTAssertFalse(custom2 < custom1)
    }

    func testEqualRespectsValue() {
        let custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        let custom2 = Custom(date: TestUtils.date20170608, name: "A", values: ["B", "C"])
        XCTAssertNotEqual(custom1, custom2)
        XCTAssert(custom1 < custom2)
        XCTAssertFalse(custom2 < custom1)
    }

    func testDescription() {
        var custom = Custom(date: TestUtils.date20170608, name: "name", values: ["B"])
        XCTAssertEqual(String(describing: custom), "2017-06-08 custom \"name\" \"B\"")
        custom = Custom(date: TestUtils.date20170608, name: "name", values: ["B"], metaData: ["A": "B"])
        XCTAssertEqual(String(describing: custom), "2017-06-08 custom \"name\" \"B\"\n  A: \"B\"")
    }

    func testDescriptionMultipleValues() {
        let custom = Custom(date: TestUtils.date20170608, name: "name", values: ["B", "C", "D"])
        XCTAssertEqual(String(describing: custom), "2017-06-08 custom \"name\" \"B\" \"C\" \"D\"")
    }

}
