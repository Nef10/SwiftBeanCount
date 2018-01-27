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
        let eur1 = ledger.getCommodityBy(symbol: "EUR")
        XCTAssertEqual(ledger.commodities.count, 1)
        let eur2 = ledger.getCommodityBy(symbol: "EUR")
        XCTAssertEqual(ledger.commodities.count, 1)
        XCTAssertEqual(eur1, eur2)
        let dollar1 = ledger.getCommodityBy(symbol: "💵")
        XCTAssertEqual(ledger.commodities.count, 2)
        let dollar2 = ledger.getCommodityBy(symbol: "💵")
        XCTAssertEqual(ledger.commodities.count, 2)
        XCTAssertEqual(dollar1, dollar2)
    }

    func testAccounts() {
        let ledger = Ledger()
        XCTAssertEqual(ledger.accounts.count, 0)
        let checking1 = ledger.getAccountBy(name: "Assets:Checking")
        XCTAssertEqual(ledger.accounts.count, 1)
        let checking2 = ledger.getAccountBy(name: "Assets:Checking")
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertEqual(checking1, checking2)
        let cash1 = ledger.getAccountBy(name: "Assets:💰")
        XCTAssertEqual(ledger.accounts.count, 2)
        let cash2 = ledger.getAccountBy(name: "Assets:💰")
        XCTAssertEqual(ledger.accounts.count, 2)
        XCTAssertEqual(cash1, cash2)
        XCTAssertNil(ledger.getAccountBy(name: "Invalid"))
        XCTAssertEqual(ledger.accounts.count, 2)
    }

    func testAccountGroups() {
        let ledger = Ledger()
        XCTAssertEqual(ledger.accountGroups.count, AccountType.allValues().count)
        for accountGroup in ledger.accountGroups {
            XCTAssert(AccountType.allValues().map { $0.rawValue }.contains(accountGroup.nameItem))
        }
    }

    func testAccountGroup() {
        let ledger = Ledger()
        let account1 = ledger.getAccountBy(name: "Assets:Checking:RBC")
        let account2 = ledger.getAccountBy(name: "Assets:Cash")
        let accountGroup = ledger.accountGroups.first { $0.nameItem == "Assets" }!
        XCTAssertEqual(accountGroup.accountGroups.count, 1)
        XCTAssertEqual(accountGroup.accounts.count, 1)
        let accountSubGroup = accountGroup.accountGroups.values.first!
        XCTAssertEqual(accountGroup.accounts.values.first!, account2)
        XCTAssertEqual(accountGroup.children().count, 2)
        XCTAssertNotNil(accountGroup.children().contains { $0.nameItem == "Cash" })
        XCTAssertNotNil(accountGroup.children().contains { $0.nameItem == "Checking" })
        XCTAssertEqual(accountSubGroup.accounts.values.first!, account1)
    }

    func testTags() {
        let ledger = Ledger()
        XCTAssertEqual(ledger.tags.count, 0)
        let tag1 = ledger.getTagBy(name: "tag")
        XCTAssertEqual(ledger.tags.count, 1)
        let tag2 = ledger.getTagBy(name: "tag")
        XCTAssertEqual(ledger.tags.count, 1)
        XCTAssertEqual(tag1, tag2)
        let ski1 = ledger.getTagBy(name: "🎿")
        XCTAssertEqual(ledger.tags.count, 2)
        let ski2 = ledger.getTagBy(name: "🎿")
        XCTAssertEqual(ledger.tags.count, 2)
        XCTAssertEqual(ski1, ski2)
    }

    func testDescription() {
        let accountName = "Assets:Cash"
        let transactionMetaData = TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_991_600), payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transaction = Transaction(metaData: transactionMetaData)
        let account = Account(name: accountName, accountType: .asset)
        let posting = Posting(account: account, amount: Amount(number: Decimal(10), commodity: Commodity(symbol: "EUR")), transaction: transaction)
        transaction.postings.append(posting)
        let ledger = Ledger()

        // Empty leder
        XCTAssertEqual(String(describing: ledger), "")
        // Ledger with only transactions
        ledger.transactions.append(transaction)
        XCTAssertEqual(String(describing: ledger), String(describing: transaction))
        // Ledger with transactions and account openings
        ledger.getAccountBy(name: accountName)!.opening = Date(timeIntervalSince1970: 1_496_991_600)
        XCTAssertEqual(String(describing: ledger), "\(String(describing: ledger.getAccountBy(name: accountName)!))\n\(String(describing: transaction))")
        // ledger with only account openings
        let ledger2 = Ledger()
        ledger2.getAccountBy(name: accountName)!.opening = Date(timeIntervalSince1970: 1_496_991_600)
        XCTAssertEqual(String(describing: ledger2), String(describing: ledger.getAccountBy(name: accountName)!))
    }

    func testEqual() {
        let name = "Name1"
        let accountName = "Assets:Cash"
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
        _ = ledger1.getAccountBy(name: accountName)
        XCTAssertNotEqual(ledger1, ledger2)
    }

}
