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
        let account = Account(name: TestUtils.cash)
        let amount = Amount(number: Decimal(1), commoditySymbol: TestUtils.cad)

        var balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount)
        XCTAssertEqual(String(describing: balance), "2017-06-08 balance \(account.name) \(amount)")

        balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount, metaData: ["A": "B"])
        XCTAssertEqual(String(describing: balance), "2017-06-08 balance \(account.name) \(amount)\n  A: \"B\"")
    }

    func testEqual() {
        let amount = Amount(number: Decimal(1), commoditySymbol: TestUtils.cad)
        var balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount)
        var balance2 = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount)
        XCTAssertEqual(balance, balance2)

        // Meta Data
        balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount, metaData: ["A": "B"])
        balance2 = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount, metaData: ["A": "C"])
        XCTAssertNotEqual(balance, balance2)
        balance2 = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount, metaData: ["A": "B"])
        XCTAssertEqual(balance, balance2)

        // Date different
        let balance3 = Balance(date: TestUtils.date20170609, accountName: TestUtils.cash, amount: amount)
        XCTAssertNotEqual(balance, balance3)

        // Account different
        let balance4 = Balance(date: TestUtils.date20170608, accountName: TestUtils.chequing, amount: amount)
        XCTAssertNotEqual(balance, balance4)

        // Amount commodity different
        let amount2 = Amount(number: Decimal(1), commoditySymbol: TestUtils.usd)
        let balance5 = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount2)
        XCTAssertNotEqual(balance, balance5)

        // Amount number different
        let amount3 = Amount(number: Decimal(2), commoditySymbol: TestUtils.cad)
        let balance6 = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount3)
        XCTAssertNotEqual(balance, balance6)
    }

}
