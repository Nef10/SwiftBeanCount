//
//  BalanceTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2018-05-13.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

final class BalanceTests: XCTestCase {

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

    func testValidateWithoutPlugin() throws {
        // Test that balance validation is skipped when plugin is not enabled
        let ledger = Ledger()

        // Add commodity with opening date after the balance date
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170609)
        try ledger.add(cadCommodity)

        // Create balance before commodity opening date
        let amount = Amount(number: Decimal(100), commoditySymbol: TestUtils.cad)
        let balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount)

        // Should be valid since plugin is not enabled
        guard case .valid = balance.validate(in: ledger) else {
            XCTFail("Balance should be valid when check_commodity plugin is not enabled")
            return
        }
    }

    func testValidateWithPlugin() throws {
        // Test that balance validation works when plugin is enabled
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodity with opening date after the balance date
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170609)
        try ledger.add(cadCommodity)

        // Create balance before commodity opening date
        let amount = Amount(number: Decimal(100), commoditySymbol: TestUtils.cad)
        let balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount)

        // Should be invalid since CAD commodity is used before opening
        if case .invalid(let error) = balance.validate(in: ledger) {
            XCTAssertTrue(error.contains("CAD used on 2017-06-08 before its opening date of 2017-06-09"))
        } else {
            XCTFail("Balance should be invalid when commodity is used before opening date")
        }
    }

    func testValidateValid() throws {
        // Test that validation passes when commodity is used on or after opening date
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodity with opening date before or on the balance date
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170608)
        try ledger.add(cadCommodity)

        // Create balance on the commodity opening date
        let amount = Amount(number: Decimal(100), commoditySymbol: TestUtils.cad)
        let balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount)

        // Should be valid since commodity is used on or after opening date
        guard case .valid = balance.validate(in: ledger) else {
            XCTFail("Balance should be valid when commodity is used on or after opening date")
            return
        }
    }

    func testValidateWithAutoCreatedCommodity() throws {
        // Test with auto-created commodity (no explicit opening date)
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Auto-created commodity doesn't have opening date
        // Create balance - should validate as if commodity was auto-created
        let amount = Amount(number: Decimal(100), commoditySymbol: TestUtils.cad)
        let balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount)

        // Should be valid since auto-created commodity is not in the ledger commodities collection
        guard case .valid = balance.validate(in: ledger) else {
            XCTFail("Balance should be valid when commodity is auto-created")
            return
        }
    }

}
