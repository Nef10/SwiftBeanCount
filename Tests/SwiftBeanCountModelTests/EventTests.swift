//
//  EventTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

final class EventTests: XCTestCase {

    func testEqual() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        let event2 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        XCTAssertEqual(event1, event2)
        XCTAssertFalse(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testEqualRespectsDate() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        let event2 = Event(date: TestUtils.date20170609, name: "A", value: "B")
        XCTAssertNotEqual(event1, event2)
        XCTAssert(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testEqualRespectsName() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        let event2 = Event(date: TestUtils.date20170608, name: "C", value: "B")
        XCTAssertNotEqual(event1, event2)
        XCTAssert(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testEqualRespectsValue() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        let event2 = Event(date: TestUtils.date20170608, name: "A", value: "C")
        XCTAssertNotEqual(event1, event2)
        XCTAssert(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testEqualRespectsMetaData() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B", metaData: ["A": "B"])
        var event2 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        XCTAssertNotEqual(event1, event2)
        XCTAssertFalse(event1 < event2)
        XCTAssert(event2 < event1)
        event2 = Event(date: TestUtils.date20170608, name: "A", value: "B", metaData: ["A": "B"])
        XCTAssertEqual(event1, event2)
        XCTAssertFalse(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testDescription() {
        var event = Event(date: TestUtils.date20170608, name: "name", value: "B")
        XCTAssertEqual(String(describing: event), "2017-06-08 event \"name\" \"B\"")
        event = Event(date: TestUtils.date20170608, name: "name", value: "B", metaData: ["A": "B"])
        XCTAssertEqual(String(describing: event), "2017-06-08 event \"name\" \"B\"\n  A: \"B\"")

    }

}
