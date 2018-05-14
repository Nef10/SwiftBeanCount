//
//  BalanceTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2018-05-13.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class BalanceTests: XCTestCase {

    func testDescription() {
        let date = Date(timeIntervalSince1970: 1_496_905_200)
        let account = try! Account(name: "Assets:Test")
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "CAD"))

        let balance = Balance(date: date, account: account, amount: amount)
        XCTAssertEqual(String(describing: balance), "2017-06-08 balance \(account.name) \(amount)")
    }

    func testEqual() {
        let date = Date(timeIntervalSince1970: 1_496_905_200)
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "CAD"))
        let account = try! Account(name: "Assets:Test")
        let balance = Balance(date: date, account: account, amount: amount)

        XCTAssertEqual(balance, balance)

        // Date different
        let date2 = Date(timeIntervalSince1970: 1_496_991_600)
        let balance2 = Balance(date: date2, account: account, amount: amount)
        XCTAssertNotEqual(balance, balance2)

        // Account different
        let account2 = try! Account(name: "Assets:Tests")
        let balance3 = Balance(date: date, account: account2, amount: amount)
        XCTAssertNotEqual(balance, balance3)

        // Amount commodity different
        let amount2 = Amount(number: Decimal(1), commodity: Commodity(symbol: "USD"))
        let balance4 = Balance(date: date, account: account, amount: amount2)
        XCTAssertNotEqual(balance, balance4)

        // Amount number different
        let amount3 = Amount(number: Decimal(2), commodity: Commodity(symbol: "CAD"))
        let balance5 = Balance(date: date, account: account, amount: amount3)
        XCTAssertNotEqual(balance, balance5)
    }

}
