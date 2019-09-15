//
//  InventoryTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-14.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class InventoryTests: XCTestCase {

    let transaction = Transaction(metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_905_200),
                                                                payee: "Payee",
                                                                narration: "Narration",
                                                                flag: Flag.complete,
                                                                tags: []))
    let account = try! Account(name: "Assets:Inventory")
    let commodity1 = Commodity(symbol: "EUR")
    let commodity2 = Commodity(symbol: "CAD")

    func testInit() {
        XCTAssertNotNil(Inventory(bookingMethod: .strict))
    }

    func testAdding() {
        let inventory = Inventory(bookingMethod: .strict)
        let amount = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost = Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let posting = Posting(account: account, amount: amount, transaction: transaction, price: nil, cost: cost)

        inventory.book(posting: posting)
        XCTAssertEqual(inventory.inventory.count, 1)
        XCTAssertEqual(inventory.inventory.first?.units, amount)
        XCTAssertEqual(inventory.inventory.first?.cost, cost)
    }

    func testAddingMultiple() {
        let inventory = Inventory(bookingMethod: .strict)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(account: account, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: 3.0, commodity: commodity1, decimalDigits: 2)
        let cost2 = Cost(amount: Amount(number: 5.0, commodity: commodity2, decimalDigits: 2), date: nil, label: nil)
        let posting2 = Posting(account: account, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        inventory.book(posting: posting1)
        inventory.book(posting: posting2)
        XCTAssertEqual(inventory.inventory.count, 2)
        XCTAssertEqual(inventory.inventory.first?.units, amount1)
        XCTAssertEqual(inventory.inventory.first?.cost, cost1)
        XCTAssertEqual(inventory.inventory.last?.units, amount2)
        XCTAssertEqual(inventory.inventory.last?.cost, cost2)
    }

    func testAddingSameCost() {
        let inventory = Inventory(bookingMethod: .strict)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost = Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(account: account, amount: amount1, transaction: transaction, price: nil, cost: cost)

        let amount2 = Amount(number: 3.0, commodity: commodity1, decimalDigits: 2)
        let posting2 = Posting(account: account, amount: amount2, transaction: transaction, price: nil, cost: cost)

        inventory.book(posting: posting1)
        inventory.book(posting: posting2)
        XCTAssertEqual(inventory.inventory.count, 1)
        XCTAssertEqual(inventory.inventory.first?.units.commodity, commodity1)
        XCTAssertEqual(inventory.inventory.first?.units.decimalDigits, 2)
        XCTAssertEqual(inventory.inventory.first?.units.number, amount1.number + amount2.number)
        XCTAssertEqual(inventory.inventory.first?.cost, cost)
    }

    func testAddingSameCostDifferentCommodity() {
        let inventory = Inventory(bookingMethod: .strict)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost = Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(account: account, amount: amount1, transaction: transaction, price: nil, cost: cost)

        let amount2 = Amount(number: 3.0, commodity: commodity2, decimalDigits: 2)
        let posting2 = Posting(account: account, amount: amount2, transaction: transaction, price: nil, cost: cost)

        inventory.book(posting: posting1)
        inventory.book(posting: posting2)
        XCTAssertEqual(inventory.inventory.count, 2)
        XCTAssertEqual(inventory.inventory.first?.units, amount1)
        XCTAssertEqual(inventory.inventory.first?.cost, cost)
        XCTAssertEqual(inventory.inventory.last?.units, amount2)
        XCTAssertEqual(inventory.inventory.last?.cost, cost)
    }

    func testAddingNegative() {
        let inventory = Inventory(bookingMethod: .strict)
        let amount = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let cost = Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let posting = Posting(account: account, amount: amount, transaction: transaction, price: nil, cost: cost)

        inventory.book(posting: posting)
        XCTAssertEqual(inventory.inventory.count, 1)
        XCTAssertEqual(inventory.inventory.first?.units, amount)
        XCTAssertEqual(inventory.inventory.first?.cost, cost)
    }

    func testAddingMultipleNegative() {
        let inventory = Inventory(bookingMethod: .strict)

        let amount1 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(account: account, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: -3.0, commodity: commodity1, decimalDigits: 2)
        let cost2 = Cost(amount: Amount(number: 5.0, commodity: commodity2, decimalDigits: 2), date: nil, label: nil)
        let posting2 = Posting(account: account, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        inventory.book(posting: posting1)
        inventory.book(posting: posting2)
        XCTAssertEqual(inventory.inventory.count, 2)
        XCTAssertEqual(inventory.inventory.first?.units, amount1)
        XCTAssertEqual(inventory.inventory.first?.cost, cost1)
        XCTAssertEqual(inventory.inventory.last?.units, amount2)
        XCTAssertEqual(inventory.inventory.last?.cost, cost2)
    }

    func testAddingSameCostNegative() {
        let inventory = Inventory(bookingMethod: .strict)

        let amount1 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let cost = Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(account: account, amount: amount1, transaction: transaction, price: nil, cost: cost)

        let amount2 = Amount(number: -3.0, commodity: commodity1, decimalDigits: 2)
        let posting2 = Posting(account: account, amount: amount2, transaction: transaction, price: nil, cost: cost)

        inventory.book(posting: posting1)
        inventory.book(posting: posting2)
        XCTAssertEqual(inventory.inventory.count, 1)
        XCTAssertEqual(inventory.inventory.first?.units.commodity, commodity1)
        XCTAssertEqual(inventory.inventory.first?.units.decimalDigits, 2)
        XCTAssertEqual(inventory.inventory.first?.units.number, amount1.number + amount2.number)
        XCTAssertEqual(inventory.inventory.first?.cost, cost)
    }

    func testDescription() {
        let inventory = Inventory(bookingMethod: .strict)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(account: account, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: 3.0, commodity: commodity1, decimalDigits: 2)
        let cost2 = Cost(amount: Amount(number: 5.0, commodity: commodity2, decimalDigits: 2), date: nil, label: nil)
        let posting2 = Posting(account: account, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        inventory.book(posting: posting1)
        inventory.book(posting: posting2)

        XCTAssertEqual(String(describing: inventory), """
            \(amount1) \(cost1)
            \(amount2) \(cost2)
            """)
    }

    func testEntryDescription() {
        let amount = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let cost = Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let entry = Inventory.Entry(units: amount, cost: cost)
        XCTAssertEqual(String(describing: entry), "\(amount) \(cost)")
    }

}
