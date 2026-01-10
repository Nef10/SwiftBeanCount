//
//  CustomTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//


import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite

struct CustomTests {

   @Test


   func testEqual() {
        var custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        var custom2 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        #expect(custom1 == custom2)

        // meta data
        custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"], metaData: ["A": "B"])
        #expect(custom1 != custom2)
        custom2 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"], metaData: ["A": "B"])
        #expect(custom1 == custom2)
        #expect(!(custom1 < custom2))
        #expect(!(custom2 < custom1))
    }

   @Test


   func testEqualRespectsDate() {
        let custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        let custom2 = Custom(date: TestUtils.date20170609, name: "A", values: ["B"])
        #expect(custom1 != custom2)
        #expect(custom1 < custom2)
        #expect(!(custom2 < custom1))
    }

   @Test


   func testEqualRespectsName() {
        let custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        let custom2 = Custom(date: TestUtils.date20170608, name: "C", values: ["B"])
        #expect(custom1 != custom2)
        #expect(custom1 < custom2)
        #expect(!(custom2 < custom1))
    }

   @Test


   func testEqualRespectsValue() {
        let custom1 = Custom(date: TestUtils.date20170608, name: "A", values: ["B"])
        let custom2 = Custom(date: TestUtils.date20170608, name: "A", values: ["B", "C"])
        #expect(custom1 != custom2)
        #expect(custom1 < custom2)
        #expect(!(custom2 < custom1))
    }

   @Test


   func testDescription() {
        var custom = Custom(date: TestUtils.date20170608, name: "name", values: ["B"])
        #expect(String(describing: custom) == "2017-06-08 custom \"name\" \"B\"")
        custom = Custom(date: TestUtils.date20170608, name: "name", values: ["B"], metaData: ["A": "B"])
        #expect(String(describing: custom) == "2017-06-08 custom \"name\" \"B\"\n  A: \"B\"")
    }

   @Test


   func testDescriptionMultipleValues() {
        let custom = Custom(date: TestUtils.date20170608, name: "name", values: ["B", "C", "D"])
        #expect(String(describing: custom) == "2017-06-08 custom \"name\" \"B\" \"C\" \"D\"")
    }

}
