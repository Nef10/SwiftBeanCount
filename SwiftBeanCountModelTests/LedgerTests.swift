//
//  LedgerTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class LedgerTests: XCTestCase {

    func testCommodities() {
        let ledger = Ledger()
        XCTAssertEqual(ledger.commodities.count, 0)
        _ = ledger.getCommodityBy(symbol: "EUR")
        XCTAssertEqual(ledger.commodities.count, 1)
        _ = ledger.getCommodityBy(symbol: "EUR")
        XCTAssertEqual(ledger.commodities.count, 1)
        _ = ledger.getCommodityBy(symbol: "💵")
        XCTAssertEqual(ledger.commodities.count, 2)
        _ = ledger.getCommodityBy(symbol: "💵")
        XCTAssertEqual(ledger.commodities.count, 2)
    }

    func testAccounts() {
        let ledger = Ledger()
        XCTAssertEqual(ledger.accounts.count, 0)
        _ = ledger.getAccountBy(name: "Assets:Checking")
        XCTAssertEqual(ledger.accounts.count, 1)
        _ = ledger.getAccountBy(name: "Assets:Checking")
        XCTAssertEqual(ledger.accounts.count, 1)
        _ = ledger.getAccountBy(name: "Assets:💰")
        XCTAssertEqual(ledger.accounts.count, 2)
        _ = ledger.getAccountBy(name: "Assets:💰")
        XCTAssertEqual(ledger.accounts.count, 2)
    }

    func testTags() {
        let ledger = Ledger()
        XCTAssertEqual(ledger.tags.count, 0)
        _ = ledger.getTagBy(name: "1")
        XCTAssertEqual(ledger.tags.count, 1)
        _ = ledger.getTagBy(name: "1")
        XCTAssertEqual(ledger.tags.count, 1)
        _ = ledger.getTagBy(name: "🎿")
        XCTAssertEqual(ledger.tags.count, 2)
        _ = ledger.getTagBy(name: "🎿")
        XCTAssertEqual(ledger.tags.count, 2)
    }

    func testDescription() {
        let accountName = "Assets:Cash"
        let transactionMetaData = TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_991_600), payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transaction = Transaction(metaData: transactionMetaData)
        let posting = Posting(account: Account(name: accountName), amount: Amount(number: Decimal(10), commodity: Commodity(symbol: "EUR")), transaction: transaction)
        transaction.postings.append(posting)
        let ledger = Ledger()

        // Empty leder
        XCTAssertEqual(String(describing: ledger), "")
        // Ledger with only transactions
        ledger.transactions.append(transaction)
        XCTAssertEqual(String(describing: ledger), String(describing: transaction))
        // Ledger with transactions and account openings
        ledger.getAccountBy(name: accountName).opening = Date(timeIntervalSince1970: 1_496_991_600)
        XCTAssertEqual(String(describing: ledger), String(describing: transaction) + "\n" + String(describing: ledger.getAccountBy(name: accountName)))
        // ledger with only account openings
        let ledger2 = Ledger()
        ledger2.getAccountBy(name: accountName).opening = Date(timeIntervalSince1970: 1_496_991_600)
        XCTAssertEqual(String(describing: ledger2), String(describing: ledger.getAccountBy(name: accountName)))
    }

    func testEqual() {
        let name = "Name1"
        let transaction1 = Transaction(metaData: TransactionMetaData(date: Date(), payee: name, narration: name, flag: Flag.complete, tags: []))

        let ledger1 = Ledger()
        let ledger2 = Ledger()

        // equal
        XCTAssertEqual(ledger1, ledger2)
        // test errors are ignored
        ledger1.errors.append("String")
        XCTAssertEqual(ledger1, ledger2)
        // different tags
        _ = ledger1.getTagBy(name: name)
        XCTAssertNotEqual(ledger1, ledger2)
        _ = ledger2.getTagBy(name: name)
        // different transactions
        ledger1.transactions.append(transaction1)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.transactions.append(transaction1)
        // different commodities
        _ = ledger1.getCommodityBy(symbol: name)
        XCTAssertNotEqual(ledger1, ledger2)
        _ = ledger2.getCommodityBy(symbol: name)
        // different accounts
        _ = ledger1.getAccountBy(name: name)
        XCTAssertNotEqual(ledger1, ledger2)
        _ = ledger2.getAccountBy(name: name)
    }

}
