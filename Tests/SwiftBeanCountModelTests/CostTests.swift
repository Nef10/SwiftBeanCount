//
//  CostTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-08.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

final class CostTests: XCTestCase {

    private let label1 = "1"
    private let label2 = "2"

    func testNegativeAmount() {
        XCTAssertThrowsError(try Cost(amount: Amount(number: -1, commoditySymbol: TestUtils.eur), date: nil, label: nil)) {
            XCTAssertEqual($0.localizedDescription, "Invalid Cost, negative amount: {-1 EUR}")
        }
    }

    func testEqual() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertEqual(cost1, cost2)
    }

    func testEqualRespectsAmount() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount2, date: TestUtils.date20170608, label: label1)
        let cost3 = try Cost(amount: nil, date: TestUtils.date20170608, label: label1)
        XCTAssertNotEqual(cost1, cost2)
        XCTAssertNotEqual(cost1, cost3)
    }

    func testEqualRespectsDate() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170609, label: label1)
        let cost3 = try Cost(amount: TestUtils.amount, date: nil, label: label1)
        XCTAssertNotEqual(cost1, cost2)
        XCTAssertNotEqual(cost1, cost3)
    }

    func testEqualRespectsLabel() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label2)
        let cost3 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: nil)
        XCTAssertNotEqual(cost1, cost2)
        XCTAssertNotEqual(cost1, cost3)
    }

    func testEqualWorksWithNil() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: nil)
        let cost2 = try Cost(amount: nil, date: nil, label: nil)
        XCTAssertEqual(cost1, cost2)
    }

    func testMatches() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: nil, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertTrue(cost1.matches(cost: cost2))
    }

    func testMatchesNil() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertTrue(cost1.matches(cost: cost2))
    }

    func testMatchesLabel() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertTrue(cost1.matches(cost: cost2))
    }

    func testMatchesDate() throws {
        let cost1 = try Cost(amount: nil, date: TestUtils.date20170608, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertTrue(cost1.matches(cost: cost2))
    }

    func testMatchesAmount() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: nil, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertTrue(cost1.matches(cost: cost2))
    }

    func testNotMatchesLabel() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: label2)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertFalse(cost1.matches(cost: cost2))
    }

    func testNotMatchesDate() throws {
        let cost1 = try Cost(amount: nil, date: TestUtils.date20170609, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertFalse(cost1.matches(cost: cost2))
    }

    func testNotMatchesAmount() throws {
        let cost1 = try Cost(amount: TestUtils.amount2, date: nil, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertFalse(cost1.matches(cost: cost2))
    }

    func testMatchesLabelWrong() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label2)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertFalse(cost1.matches(cost: cost2))
    }

    func testMatchesDateWrong() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170609, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertFalse(cost1.matches(cost: cost2))
    }

    func testMatchesAmountWrong() throws {
        let cost1 = try Cost(amount: TestUtils.amount2, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertFalse(cost1.matches(cost: cost2))
    }

    func testDescription() throws {
        let cost = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        XCTAssertEqual(String(describing: cost), "{2017-06-08, \(String(describing: TestUtils.amount)), \"\(label1)\"}")
    }

    func testDescriptionWithoutDate() throws {
        let cost = try Cost(amount: TestUtils.amount, date: nil, label: label1)
        XCTAssertEqual(String(describing: cost), "{\(String(describing: TestUtils.amount)), \"\(label1)\"}")
    }

    func testDescriptionWithoutAmount() throws {
        let cost = try Cost(amount: nil, date: TestUtils.date20170608, label: label1)
        XCTAssertEqual(String(describing: cost), "{2017-06-08, \"\(label1)\"}")
    }

    func testDescriptionWithoutLabel() throws {
        let cost = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: nil)
        XCTAssertEqual(String(describing: cost), "{2017-06-08, \(String(describing: TestUtils.amount))}")
    }

    func testDescriptionWithOnlyAmount() throws {
        let cost = try Cost(amount: TestUtils.amount, date: nil, label: nil)
        XCTAssertEqual(String(describing: cost), "{\(String(describing: TestUtils.amount))}")
    }

    func testDescriptionWithOnlyDate() throws {
        let cost = try Cost(amount: nil, date: TestUtils.date20170608, label: nil)
        XCTAssertEqual(String(describing: cost), "{2017-06-08}")
    }

    func testDescriptionWithOnlyLabel() throws {
        let cost = try Cost(amount: nil, date: nil, label: label1)
        XCTAssertEqual(String(describing: cost), "{\"\(label1)\"}")
    }

    func testEmptyDescription() throws {
        let cost = try Cost(amount: nil, date: nil, label: nil)
        XCTAssertEqual(String(describing: cost), "{}")
    }

}
