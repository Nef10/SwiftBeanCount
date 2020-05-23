//
//  TransactionPostingTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-14.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class TransactionPostingTests: XCTestCase {

    let commoditySymbol = "EUR"
    let amountInteger = 1
    var amount1: Amount?
    var account1: Account?
    var posting1: Posting?

    override func setUp() {
        super.setUp()
        amount1 = Amount(number: Decimal(amountInteger), commodity: Commodity(symbol: commoditySymbol))
        account1 = Account(name: TestUtils.cash)
        posting1 = Posting(accountName: TestUtils.cash, amount: amount1!)
    }

    func testInitTransactionPosting() {
        let transaction = Transaction(metaData: TransactionMetaData(date: TestUtils.date20170609, payee: "", narration: "", flag: .complete, tags: []),
                                      postings: [])
        let posting = Posting(accountName: TestUtils.cash, amount: amount1!, metaData: ["A": "B"])
        let transactionPosting = TransactionPosting(posting: posting, transaction: transaction)
        XCTAssertEqual(posting.accountName, transactionPosting.accountName)
        XCTAssertEqual(posting.amount, transactionPosting.amount)
        XCTAssertEqual(posting.metaData, transactionPosting.metaData)
        XCTAssertEqual(transaction, transactionPosting.transaction)
    }

    func testDescription() {
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "💵"))
        let posting = Posting(accountName: TestUtils.chequing, amount: amount)

        XCTAssertEqual(String(describing: posting), "  \(String(describing: TestUtils.chequing)) \(String(describing: amount))")
    }

    func testDescriptionMetaData() {
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "💵"))
        let posting = Posting(accountName: TestUtils.chequing, amount: amount, metaData: ["A": "B"])

        XCTAssertEqual(String(describing: posting), "  \(String(describing: TestUtils.chequing)) \(String(describing: amount))\n    A: \"B\"")
    }

    func testDescriptionPrice() {
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "💵"))
        let price = Amount(number: Decimal(1.555), commodity: TestUtils.eur)
        let posting = Posting(accountName: TestUtils.chequing, amount: amount, price: price)

        XCTAssertEqual(String(describing: posting), "  \(String(describing: TestUtils.chequing)) \(String(describing: amount)) @ \(price)")
    }

    func testDescriptionCost() {
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "💵"))
        let cost = try! Cost(amount: amount, date: nil, label: "label")
        let posting = Posting(accountName: TestUtils.chequing, amount: amount, price: nil, cost: cost)

        XCTAssertEqual(String(describing: posting), "  \(String(describing: TestUtils.chequing)) \(String(describing: amount)) \(String(describing: cost))")
    }

    func testDescriptionCostAndPrice() {
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "💵"))
        let price = Amount(number: Decimal(1.555), commodity: TestUtils.eur)
        let cost = try! Cost(amount: amount, date: nil, label: "label")
        let posting = Posting(accountName: TestUtils.chequing, amount: amount, price: price, cost: cost)

        XCTAssertEqual(String(describing: posting), "  \(String(describing: TestUtils.chequing)) \(String(describing: amount)) \(String(describing: cost)) @ \(price)")
    }

    func testEqual() {
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount1!)
        XCTAssertEqual(posting1, posting2)
    }

    func testEqualRespectsMetaData() {
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount1!, metaData: ["A": "B"])
        XCTAssertNotEqual(posting1, posting2)
   }

    func testEqualRespectsAccount() {
        let posting2 = Posting(accountName: try! AccountName("\(String(describing: TestUtils.cash)):💰"), amount: amount1!)
        XCTAssertNotEqual(posting1, posting2)
    }

    func testEqualRespectsAmount() {
        let posting2 = Posting(accountName: TestUtils.cash,
                               amount: Amount(number: Decimal(amountInteger),
                                              commodity: Commodity(symbol: "\(commoditySymbol)1")))
        XCTAssertNotEqual(posting1, posting2)
    }

    func testEqualRespectsPrice() {
        let price = Amount(number: Decimal(1.555), commodity: TestUtils.eur)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount1!, price: price)
        XCTAssertNotEqual(posting1, posting2)
    }

    func testEqualRespectsCost() {
        let amount = Amount(number: Decimal(1.555), commodity: TestUtils.eur)
        let cost = try! Cost(amount: amount, date: nil, label: "label")
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount1!, price: nil, cost: cost)
        XCTAssertNotEqual(posting1, posting2)
    }

}
