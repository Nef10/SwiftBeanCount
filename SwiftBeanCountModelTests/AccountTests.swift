//
//  AccountTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-11.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class AccountTests: XCTestCase {

    let date20170608 = Date(timeIntervalSince1970: 1_496_905_200)
    let date20170609 = Date(timeIntervalSince1970: 1_496_991_600)
    let date20170610 = Date(timeIntervalSince1970: 1_497_078_000)

    let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR"))
    let accountName = "Assets:Cash"
    let invalidNames = ["Assets", "Liabilities", "Income", "Expenses", "Equity", "Assets:", "Assets:Test:", "Assets:Test:", "Assets:Test::Test", "💰", ""]
    let validNames = ["Assets:Cash", "Assets:Cash:Test:Test:A", "Assets:Cash:💰", "Assets:Cash:Ca💰h:Test:💰", "Liabilities:Test", "Income:Test", "Expenses:Test", "Equity:Test"]

    func testInit() {
        for name in validNames {
            XCTAssertNoThrow(try Account(name: name))
        }
        for name in invalidNames {
            XCTAssertThrowsError(try Account(name: name))
        }
    }

    func testDescription() {
        let name = "Assets:Cash"
        let accout = try! Account(name: name)
        XCTAssertEqual(String(describing: accout), "")
        accout.opening = date20170608
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(name)")
        let symbol = "EUR"
        accout.commodity = Commodity(symbol: symbol)
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(name) \(symbol)")
        accout.closing = date20170609
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(name) \(symbol)\n2017-06-09 close \(name)")
    }

    func testDescriptionSpecialCharacters() {
        let name = "Assets:💰"
        let accout = try! Account(name: name)
        XCTAssertEqual(String(describing: accout), "")
        accout.opening = date20170608
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(name)")
        let symbol = "💵"
        accout.commodity = Commodity(symbol: symbol)
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(name) \(symbol)")
        accout.closing = date20170609
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(name) \(symbol)\n2017-06-09 close \(name)")
    }

    func testNameItem() {
        XCTAssertEqual(try! Account(name: "Assets:Cash").nameItem, "Cash")
        XCTAssertEqual(try! Account(name: "Assets:A:B:C:D:E:Cash").nameItem, "Cash")
        XCTAssertEqual(try! Account(name: "Assets:💰").nameItem, "💰")
    }

    func testAccountType() {
        XCTAssertEqual(try! Account(name: "Assets:Test").accountType, AccountType.asset)
        XCTAssertEqual(try! Account(name: "Liabilities:Test").accountType, AccountType.liability)
        XCTAssertEqual(try! Account(name: "Income:Test").accountType, AccountType.income)
        XCTAssertEqual(try! Account(name: "Expenses:Test").accountType, AccountType.expense)
        XCTAssertEqual(try! Account(name: "Equity:Test").accountType, AccountType.equity)
    }

    func testIsPostingValid_NotOpenPast() {
        let account = try! Account(name: accountName)
        let transaction = Transaction(metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 0),
                                                                    payee: "Payee",
                                                                    narration: "Narration",
                                                                    flag: Flag.complete,
                                                                    tags: []))
        let posting = Posting(account: account, amount: Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR")), transaction: transaction)
        XCTAssertFalse(account.isPostingValid(posting))
    }

    func testIsPostingValid_NotOpenPresent() {
        let account = try! Account(name: accountName)
        let transaction = Transaction(metaData: TransactionMetaData(date: Date(), payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(account: account, amount: Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR")), transaction: transaction)
        XCTAssertFalse(account.isPostingValid(posting))
    }

    func testIsPostingValid_BeforeOpening() {
        let account = try! Account(name: accountName)
        account.opening = date20170609

        let transaction1 = Transaction(metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 0),
                                                                     payee: "Payee",
                                                                     narration: "Narration",
                                                                     flag: Flag.complete,
                                                                     tags: []))
        let posting1 = Posting(account: account, amount: Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR")), transaction: transaction1)
        XCTAssertFalse(account.isPostingValid(posting1))

        let transaction2 = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting2 = Posting(account: account, amount: Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR")), transaction: transaction2)
        XCTAssertFalse(account.isPostingValid(posting2))
    }

    func testIsPostingValid_AfterOpening() {
        let account = try! Account(name: accountName)
        account.opening = date20170609

        let transaction1 = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting1 = Posting(account: account, amount: amount, transaction: transaction1)
        XCTAssert(account.isPostingValid(posting1))

        let transaction2 = Transaction(metaData: TransactionMetaData(date: Date(), payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting2 = Posting(account: account, amount: amount, transaction: transaction2)
        XCTAssert(account.isPostingValid(posting2))
    }

    func testIsPostingValid_BeforeClosing() {
        let account = try! Account(name: accountName)
        account.opening = date20170609
        account.closing = date20170609
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(account: account, amount: amount, transaction: transaction)
        XCTAssert(account.isPostingValid(posting))
    }

    func testIsPostingValid_AfterClosing() {
        let account = try! Account(name: accountName)
        account.opening = date20170609
        account.closing = date20170609
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170610, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(account: account, amount: amount, transaction: transaction)
        XCTAssertFalse(account.isPostingValid(posting))
    }

    func testIsPostingValid_WithoutCommodity() {
        let account = try! Account(name: accountName)
        account.opening = date20170608

        let transaction1 = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting1 = Posting(account: account, amount: amount, transaction: transaction1)
        XCTAssert(account.isPostingValid(posting1))

        let transaction2 = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting2 = Posting(account: account, amount: amount, transaction: transaction2)
        XCTAssert(account.isPostingValid(posting2))
    }

    func testIsPostingValid_CorrectCommodity() {
        let account = try! Account(name: accountName)
        account.commodity = amount.commodity
        account.opening = date20170608
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(account: account, amount: amount, transaction: transaction)
        XCTAssert(account.isPostingValid(posting))
    }

    func testIsPostingValid_WrongCommodity() {
        let account = try! Account(name: accountName)
        account.commodity = Commodity(symbol: "\(amount.commodity.symbol)1")
        account.opening = date20170608
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(account: account, amount: amount, transaction: transaction)
        XCTAssertFalse(account.isPostingValid(posting))
    }

    func testEqual() {
        let name1 = "Assets:Cash"
        let name2 = "Assets:💰"
        let commodity1 = Commodity(symbol: "EUR")
        let commodity2 = Commodity(symbol: "💵")
        let date1 = date20170608
        let date2 = date20170609

        let account1 = try! Account(name: name1)
        let account2 = try! Account(name: name1)
        let account3 = try! Account(name: name2)

        // equal
        XCTAssertEqual(account1, account2)
        // different name
        XCTAssertNotEqual(account1, account3)

        account1.commodity = commodity1
        account2.commodity = commodity1
        account1.opening = date1
        account2.opening = date1
        account1.closing = date1
        account2.closing = date1

        // equal
        XCTAssertEqual(account1, account2)
        // different commodity
        account2.commodity = commodity2
        XCTAssertNotEqual(account1, account2)
        account2.commodity = commodity1
        // different opening
        account2.opening = date2
        XCTAssertNotEqual(account1, account2)
        account2.opening = date1
        // different closing
        account2.closing = date2
        XCTAssertNotEqual(account1, account2)
        account2.closing = date1
    }

    func testIsAccountNameVaild() {
        for name in validNames {
            XCTAssert(Account.isNameValid(name))
        }
        for name in invalidNames {
            XCTAssertFalse(Account.isNameValid(name))
        }
    }

}
