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

        let commodity1 = Commodity(symbol: "EUR")
        try! ledger.add(commodity1)
        XCTAssertEqual(ledger.commodities.count, 1)
        XCTAssertThrowsError(try ledger.add(commodity1))
        XCTAssertEqual(ledger.commodities.count, 1)
        XCTAssertEqual(ledger.commodities.first, commodity1)

        let commodity2 = Commodity(symbol: "💵")
        try! ledger.add(commodity2)
        XCTAssertEqual(ledger.commodities.count, 2)
        XCTAssertThrowsError(try ledger.add(commodity2))
        XCTAssertEqual(ledger.commodities.count, 2)
        XCTAssert(ledger.commodities.contains(commodity2))
    }

    func testAccounts() {
        let ledger = Ledger()
        XCTAssertEqual(ledger.accounts.count, 0)

        let account1 = try! Account(name: "Assets:Checking")
        try! ledger.add(account1)
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertThrowsError(try ledger.add(account1))
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertEqual(ledger.accounts.first, account1)

        let account2 = try! Account(name: "Assets:💰")
        try! ledger.add(account2)
        XCTAssertEqual(ledger.accounts.count, 2)
        XCTAssertThrowsError(try ledger.add(account2))
        XCTAssertEqual(ledger.accounts.count, 2)
        XCTAssert(ledger.accounts.contains(account2))

        XCTAssertThrowsError(try ledger.add(Account(name: "Invalid")))
        XCTAssertEqual(ledger.accounts.count, 2)
        XCTAssertThrowsError(try ledger.add(Account(name: "Assets:Invalid:")))
        XCTAssertEqual(ledger.accounts.count, 2)
        XCTAssertThrowsError(try ledger.add(Account(name: "Assets::Invalid")))
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
        let account1 = try! Account(name: "Assets:Checking:RBC")
        try! ledger.add(account1)
        let account2 = try! Account(name: "Assets:Cash")
        try! ledger.add(account2)
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

        let tag1 = Tag(name: "tag")
        try! ledger.add(tag1)
        XCTAssertEqual(ledger.tags.count, 1)
        XCTAssertThrowsError(try ledger.add(tag1))
        XCTAssertEqual(ledger.tags.count, 1)
        XCTAssertEqual(ledger.tags.first, tag1)

        let tag2 = Tag(name: "🎿")
        try! ledger.add(tag2)
        XCTAssertEqual(ledger.tags.count, 2)
        XCTAssertThrowsError(try ledger.add(tag2))
        XCTAssertEqual(ledger.tags.count, 2)
        XCTAssert(ledger.tags.contains(tag2))
    }

    func testTransactions() {
        let ledger = Ledger()
        let date = Date(timeIntervalSince1970: 1_496_991_600)
        let transactionMetaData = TransactionMetaData(date: date,
                                                      payee: "Payee",
                                                      narration: "Narration",
                                                      flag: Flag.complete,
                                                      tags: [Tag(name: "test")])
        let transaction = Transaction(metaData: transactionMetaData)
        let account = try! Account(name: "Assets:Cash")
        let posting = Posting(account: account,
                              amount: Amount(number: Decimal(10), commodity: Commodity(symbol: "EUR")),
                              transaction: transaction,
                              price: Amount(number: Decimal(15), commodity: Commodity(symbol: "USD")))
        transaction.postings.append(posting)

        let addedTransaction = ledger.add(transaction)
        XCTAssertEqual(addedTransaction, transaction)
        XCTAssert(ledger.transactions.contains(addedTransaction))
        XCTAssertEqual(ledger.commodities.count, 2)
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertEqual(ledger.tags.count, 1)

        // Test that properties on accounts are not overridden
        let ledger2 = Ledger()
        let account2 = try! Account(name: "Assets:Cash")
        account2.opening = date
        account.opening = date.addingTimeInterval(1_000_000)
        try! ledger2.add(account2)
        _ = ledger2.add(transaction)
        XCTAssertEqual(ledger2.accounts.first!.opening, date)
    }

    func testValidate() {
        let ledger = Ledger()
        ledger.validate()
        XCTAssertTrue(ledger.errors.isEmpty)

        // add invalid transaction without postings
        let transactionMetaData = TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_991_600),
                                                      payee: "Payee",
                                                      narration: "Narration",
                                                      flag: Flag.complete,
                                                      tags: [Tag(name: "test")])
        let transaction = Transaction(metaData: transactionMetaData)
        _ = ledger.add(transaction)
        ledger.validate()
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testDescription() {
        let accountName = "Assets:Cash"
        let transactionMetaData = TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_991_600), payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transaction = Transaction(metaData: transactionMetaData)
        let account = try! Account(name: accountName)
        let posting = Posting(account: account, amount: Amount(number: Decimal(10), commodity: Commodity(symbol: "EUR")), transaction: transaction)
        transaction.postings.append(posting)
        let ledger = Ledger()

        // Empty leder
        XCTAssertEqual(String(describing: ledger), "")

        // Ledger with only transactions
        _ = ledger.add(transaction)
        XCTAssertEqual(String(describing: ledger), String(describing: transaction))

        // Ledger with transactions and account openings
        ledger.accounts.first { $0.name == accountName }!.opening = Date(timeIntervalSince1970: 1_496_991_600)
        XCTAssertEqual(String(describing: ledger), "\(String(describing: ledger.accounts.first { $0.name == accountName }!))\n\(String(describing: transaction))")

        // ledger with only account openings
        let ledger2 = Ledger()
        let account2 = try! Account(name: accountName)
        account2.opening = Date(timeIntervalSince1970: 1_496_991_600)
        try! ledger2.add(account2)
        XCTAssertEqual(String(describing: ledger2), String(describing: ledger2.accounts.first!))
    }

    func testEqual() {
        let tag = Tag(name: "Name1")
        let commodity = Commodity(symbol: "Name1")
        let account = try! Account(name: "Assets:Cash")
        let transaction1 = Transaction(metaData: TransactionMetaData(date: Date(), payee: name, narration: name, flag: Flag.complete, tags: []))

        let ledger1 = Ledger()
        let ledger2 = Ledger()

        // equal
        XCTAssertEqual(ledger1, ledger2)

        // test errors are ignored
        ledger1.errors.append("String")
        XCTAssertEqual(ledger1, ledger2)

        // different tags
        try! ledger1.add(tag)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger2.add(tag)
        XCTAssertEqual(ledger1, ledger2)

        // different transactions
        _ = ledger1.add(transaction1)
        XCTAssertNotEqual(ledger1, ledger2)
        _ = ledger2.add(transaction1)
        XCTAssertEqual(ledger1, ledger2)

        // different commodities
        try! ledger1.add(commodity)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger2.add(commodity)
        XCTAssertEqual(ledger1, ledger2)

        // different accounts
        try! ledger1.add(account)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger2.add(account)
        XCTAssertEqual(ledger1, ledger2)
    }

}
