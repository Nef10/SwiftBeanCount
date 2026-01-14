//
//  EventTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite
struct EventTests {

    @Test
    func equal() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        let event2 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        #expect(event1 == event2)
        #expect(!(event1 < event2))
        #expect(!(event2 < event1))
    }

    @Test
    func equalRespectsDate() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        let event2 = Event(date: TestUtils.date20170609, name: "A", value: "B")
        #expect(event1 != event2)
        #expect(event1 < event2)
        #expect(!(event2 < event1))
    }

    @Test
    func equalRespectsName() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        let event2 = Event(date: TestUtils.date20170608, name: "C", value: "B")
        #expect(event1 != event2)
        #expect(event1 < event2)
        #expect(!(event2 < event1))
    }

    @Test
    func equalRespectsValue() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        let event2 = Event(date: TestUtils.date20170608, name: "A", value: "C")
        #expect(event1 != event2)
        #expect(event1 < event2)
        #expect(!(event2 < event1))
    }

    @Test
    func equalRespectsMetaData() {
        let event1 = Event(date: TestUtils.date20170608, name: "A", value: "B", metaData: ["A": "B"])
        var event2 = Event(date: TestUtils.date20170608, name: "A", value: "B")
        #expect(event1 != event2)
        #expect(!(event1 < event2))
        #expect(event2 < event1)
        event2 = Event(date: TestUtils.date20170608, name: "A", value: "B", metaData: ["A": "B"])
        #expect(event1 == event2)
        #expect(!(event1 < event2))
        #expect(!(event2 < event1))
    }

    @Test
    func description() {
        var event = Event(date: TestUtils.date20170608, name: "name", value: "B")
        #expect(String(describing: event) == "2017-06-08 event \"name\" \"B\"")
        event = Event(date: TestUtils.date20170608, name: "name", value: "B", metaData: ["A": "B"])
        #expect(String(describing: event) == "2017-06-08 event \"name\" \"B\"\n  A: \"B\"")

    }

}
