//
//  CostTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-08.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class CostTests: XCTestCase {

    let amount1 = Amount(number: Decimal(1), commodity: Commodity(symbol: "CAD"))
    let amount2 = Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR"))

    let date1 = Date(timeIntervalSince1970: 1_496_905_200)
    let date2 = Date(timeIntervalSince1970: 1_496_991_600)

    let label1 = "1"
    let label2 = "2"

    func testEqual() {
        let cost1 = Cost(amount: amount1, date: date1, label: label1)
        let cost2 = Cost(amount: amount1, date: date1, label: label1)
        XCTAssertEqual(cost1, cost2)
    }

    func testEqualRespectsAmount() {
        let cost1 = Cost(amount: amount1, date: date1, label: label1)
        let cost2 = Cost(amount: amount2, date: date1, label: label1)
        let cost3 = Cost(amount: nil, date: date1, label: label1)
        XCTAssertNotEqual(cost1, cost2)
        XCTAssertNotEqual(cost1, cost3)
    }

    func testEqualRespectsDate() {
        let cost1 = Cost(amount: amount1, date: date1, label: label1)
        let cost2 = Cost(amount: amount1, date: date2, label: label1)
        let cost3 = Cost(amount: amount1, date: nil, label: label1)
        XCTAssertNotEqual(cost1, cost2)
        XCTAssertNotEqual(cost1, cost3)
    }

    func testEqualRespectsLabel() {
        let cost1 = Cost(amount: amount1, date: date1, label: label1)
        let cost2 = Cost(amount: amount1, date: date1, label: label2)
        let cost3 = Cost(amount: amount1, date: date1, label: nil)
        XCTAssertNotEqual(cost1, cost2)
        XCTAssertNotEqual(cost1, cost3)
    }

    func testEqualWorksWithNil() {
        let cost1 = Cost(amount: nil, date: nil, label: nil)
        let cost2 = Cost(amount: nil, date: nil, label: nil)
        XCTAssertEqual(cost1, cost2)
    }

    func testDescription() {
        let cost = Cost(amount: amount1, date: date1, label: label1)
        XCTAssertEqual(String(describing: cost), "{2017-06-08, \(String(describing: amount1)), \"\(label1)\"}")
    }

    func testDescriptionWithoutDate() {
        let cost = Cost(amount: amount1, date: nil, label: label1)
        XCTAssertEqual(String(describing: cost), "{\(String(describing: amount1)), \"\(label1)\"}")
    }

    func testDescriptionWithoutAmount() {
        let cost = Cost(amount: nil, date: date1, label: label1)
        XCTAssertEqual(String(describing: cost), "{2017-06-08, \"\(label1)\"}")
    }

    func testDescriptionWithoutLabel() {
        let cost = Cost(amount: amount1, date: date1, label: nil)
        XCTAssertEqual(String(describing: cost), "{2017-06-08, \(String(describing: amount1))}")
    }

    func testDescriptionWithOnlyAmount() {
        let cost = Cost(amount: amount1, date: nil, label: nil)
        XCTAssertEqual(String(describing: cost), "{\(String(describing: amount1))}")
    }

    func testDescriptionWithOnlyDate() {
        let cost = Cost(amount: nil, date: date1, label: nil)
        XCTAssertEqual(String(describing: cost), "{2017-06-08}")
    }

    func testDescriptionWithOnlyLabel() {
        let cost = Cost(amount: nil, date: nil, label: label1)
        XCTAssertEqual(String(describing: cost), "{\"\(label1)\"}")
    }

    func testEmptyDescription() {
        let cost = Cost(amount: nil, date: nil, label: nil)
        XCTAssertEqual(String(describing: cost), "{}")
    }

}
