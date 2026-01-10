//
//  CostTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-08.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite

struct CostTests {

    private let label1 = "1"
    private let label2 = "2"

   @Test
   func testNegativeAmount() {
        XCTAssertThrowsError(try Cost(amount: Amount(number: -1, commoditySymbol: TestUtils.eur), date: nil, label: nil)) {
            #expect($0.localizedDescription == "Invalid Cost, negative amount: {-1 EUR}")
        }
    }

   @Test
   func testEqual() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1 == cost2)
    }

   @Test
   func testEqualRespectsAmount() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount2, date: TestUtils.date20170608, label: label1)
        let cost3 = try Cost(amount: nil, date: TestUtils.date20170608, label: label1)
        #expect(cost1 != cost2)
        #expect(cost1 != cost3)
    }

   @Test
   func testEqualRespectsDate() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170609, label: label1)
        let cost3 = try Cost(amount: TestUtils.amount, date: nil, label: label1)
        #expect(cost1 != cost2)
        #expect(cost1 != cost3)
    }

   @Test
   func testEqualRespectsLabel() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label2)
        let cost3 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: nil)
        #expect(cost1 != cost2)
        #expect(cost1 != cost3)
    }

   @Test
   func testEqualWorksWithNil() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: nil)
        let cost2 = try Cost(amount: nil, date: nil, label: nil)
        #expect(cost1 == cost2)
    }

   @Test
   func testMatches() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: nil, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

   @Test
   func testMatchesNil() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

   @Test
   func testMatchesLabel() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

   @Test
   func testMatchesDate() throws {
        let cost1 = try Cost(amount: nil, date: TestUtils.date20170608, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

   @Test
   func testMatchesAmount() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: nil, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

   @Test
   func testNotMatchesLabel() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: label2)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

   @Test
   func testNotMatchesDate() throws {
        let cost1 = try Cost(amount: nil, date: TestUtils.date20170609, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

   @Test
   func testNotMatchesAmount() throws {
        let cost1 = try Cost(amount: TestUtils.amount2, date: nil, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

   @Test
   func testMatchesLabelWrong() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label2)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

   @Test
   func testMatchesDateWrong() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170609, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

   @Test
   func testMatchesAmountWrong() throws {
        let cost1 = try Cost(amount: TestUtils.amount2, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

   @Test
   func testDescription() throws {
        let cost = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(String(describing: cost) == "{2017-06-08, \(String(describing: TestUtils.amount)), \"\(label1)\"}")
    }

   @Test
   func testDescriptionWithoutDate() throws {
        let cost = try Cost(amount: TestUtils.amount, date: nil, label: label1)
        #expect(String(describing: cost) == "{\(String(describing: TestUtils.amount)), \"\(label1)\"}")
    }

   @Test
   func testDescriptionWithoutAmount() throws {
        let cost = try Cost(amount: nil, date: TestUtils.date20170608, label: label1)
        #expect(String(describing: cost) == "{2017-06-08, \"\(label1)\"}")
    }

   @Test
   func testDescriptionWithoutLabel() throws {
        let cost = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: nil)
        #expect(String(describing: cost) == "{2017-06-08, \(String(describing: TestUtils.amount))}")
    }

   @Test
   func testDescriptionWithOnlyAmount() throws {
        let cost = try Cost(amount: TestUtils.amount, date: nil, label: nil)
        #expect(String(describing: cost) == "{\(String(describing: TestUtils.amount))}")
    }

   @Test
   func testDescriptionWithOnlyDate() throws {
        let cost = try Cost(amount: nil, date: TestUtils.date20170608, label: nil)
        #expect(String(describing: cost) == "{2017-06-08}")
    }

   @Test
   func testDescriptionWithOnlyLabel() throws {
        let cost = try Cost(amount: nil, date: nil, label: label1)
        #expect(String(describing: cost) == "{\"\(label1)\"}")
    }

   @Test
   func testEmptyDescription() throws {
        let cost = try Cost(amount: nil, date: nil, label: nil)
        #expect(String(describing: cost) == "{}")
    }

}
