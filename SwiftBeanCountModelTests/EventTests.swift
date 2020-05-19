//
//  EventTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class EventTests: XCTestCase {

    let date1 = Date(timeIntervalSince1970: 1_496_905_200)
    let date2 = Date(timeIntervalSince1970: 1_496_991_600)

    func testEqual() {
        let event1 = Event(date: date1, name: "A", value: "B")
        let event2 = Event(date: date1, name: "A", value: "B")
        XCTAssertEqual(event1, event2)
        XCTAssertFalse(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testEqualRespectsDate() {
        let event1 = Event(date: date1, name: "A", value: "B")
        let event2 = Event(date: date2, name: "A", value: "B")
        XCTAssertNotEqual(event1, event2)
        XCTAssert(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testEqualRespectsName() {
        let event1 = Event(date: date1, name: "A", value: "B")
        let event2 = Event(date: date1, name: "C", value: "B")
        XCTAssertNotEqual(event1, event2)
        XCTAssert(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testEqualRespectsValue() {
        let event1 = Event(date: date1, name: "A", value: "B")
        let event2 = Event(date: date1, name: "A", value: "C")
        XCTAssertNotEqual(event1, event2)
        XCTAssert(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testEqualRespectsMetaData() {
        var event1 = Event(date: date1, name: "A", value: "B")
        var event2 = Event(date: date1, name: "A", value: "B")
        event1.metaData["A"] = "B"
        XCTAssertNotEqual(event1, event2)
        XCTAssertFalse(event1 < event2)
        XCTAssert(event2 < event1)
        event2.metaData["A"] = "B"
        XCTAssertEqual(event1, event2)
        XCTAssertFalse(event1 < event2)
        XCTAssertFalse(event2 < event1)
    }

    func testDescription() {
        var event = Event(date: date1, name: "name", value: "B")
        XCTAssertEqual(String(describing: event), "2017-06-08 event \"name\" \"B\"")
        event.metaData["A"] = "B"
        XCTAssertEqual(String(describing: event), "2017-06-08 event \"name\" \"B\"\n  A: \"B\"")

    }

}
