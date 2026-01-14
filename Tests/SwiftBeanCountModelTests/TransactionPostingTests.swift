//
//  TransactionPostingTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-14.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite
struct TransactionPostingTests {

    private var posting1 = Posting(accountName: TestUtils.cash, amount: TestUtils.amount)

    @Test
    func initTransactionPosting() {
        let transaction = Transaction(metaData: TransactionMetaData(date: TestUtils.date20170609, payee: "", narration: "", flag: .complete, tags: []),
                                      postings: [])
        let posting = Posting(accountName: TestUtils.cash, amount: TestUtils.amount, metaData: ["A": "B"])
        let transactionPosting = TransactionPosting(posting: posting, transaction: transaction)
        #expect(posting.accountName == transactionPosting.accountName)
        #expect(posting.amount == transactionPosting.amount)
        #expect(posting.metaData == transactionPosting.metaData)
        #expect(transaction == transactionPosting.transaction)
    }

    @Test
    func description() {
        let amount = Amount(number: Decimal(1), commoditySymbol: "💵")
        let posting = Posting(accountName: TestUtils.chequing, amount: amount)

        #expect(String(describing: posting) == "  \(String(describing: TestUtils.chequing)) \(String(describing: amount))")
    }

    @Test
    func descriptionMetaData() {
        let posting = Posting(accountName: TestUtils.chequing, amount: TestUtils.amount, metaData: ["A": "B"])

        #expect(String(describing: posting) == "  \(String(describing: TestUtils.chequing)) \(String(describing: TestUtils.amount))\n    A: \"B\"")
    }

    @Test
    func descriptionPrice() {
        let price = Amount(number: Decimal(1.555), commoditySymbol: TestUtils.eur)
        let posting = Posting(accountName: TestUtils.chequing, amount: TestUtils.amount, price: price)

        #expect(String(describing: posting) == "  \(String(describing: TestUtils.chequing)) \(String(describing: TestUtils.amount)) @ \(price)")
    }

    @Test
    func descriptionCost() throws {
        let cost = try Cost(amount: TestUtils.amount, date: nil, label: "label")
        let posting = Posting(accountName: TestUtils.chequing, amount: TestUtils.amount, price: nil, cost: cost)

        #expect(String(describing: posting) == "  \(String(describing: TestUtils.chequing)) \(String(describing: TestUtils.amount)) \(String(describing: cost))")
    }

    @Test
    func descriptionCostAndPrice() throws {
        let amount = Amount(number: Decimal(1), commoditySymbol: "💵")
        let price = Amount(number: Decimal(1.555), commoditySymbol: TestUtils.eur)
        let cost = try Cost(amount: amount, date: nil, label: "label")
        let posting = Posting(accountName: TestUtils.chequing, amount: amount, price: price, cost: cost)

        #expect(String(describing: posting) == "  \(String(describing: TestUtils.chequing)) \(String(describing: amount)) \(String(describing: cost)) @ \(price)")
    }

    @Test
    func equal() {
        let posting2 = Posting(accountName: TestUtils.cash, amount: TestUtils.amount)
        #expect(posting1 == posting2)
    }

    @Test
    func equalRespectsMetaData() {
        let posting2 = Posting(accountName: TestUtils.cash, amount: TestUtils.amount, metaData: ["A": "B"])
        #expect(posting1 != posting2)
    }

    @Test
    func equalRespectsAccount() throws {
        let posting2 = Posting(accountName: try AccountName("\(String(describing: TestUtils.cash)):💰"), amount: TestUtils.amount)
        #expect(posting1 != posting2)
    }

    @Test
    func equalRespectsAmount() {
        let posting2 = Posting(accountName: TestUtils.cash,
                               amount: Amount(number: posting1.amount.number + posting1.amount.number,
                                              commoditySymbol: "\(TestUtils.eur)1"))
        #expect(posting1 != posting2)
    }

    @Test
    func equalRespectsPrice() {
        let price = Amount(number: Decimal(1.555), commoditySymbol: TestUtils.eur)
        let posting2 = Posting(accountName: TestUtils.cash, amount: TestUtils.amount, price: price)
        #expect(posting1 != posting2)
    }

    @Test
    func equalRespectsCost() throws {
        let amount = Amount(number: Decimal(1.555), commoditySymbol: TestUtils.eur)
        let cost = try Cost(amount: amount, date: nil, label: "label")
        let posting2 = Posting(accountName: TestUtils.cash, amount: TestUtils.amount, price: nil, cost: cost)
        #expect(posting1 != posting2)
    }

    @Test
    func descriptionTotalPrice() throws {
        let amount = Amount(number: Decimal(1), commoditySymbol: "💵")
        let price = Amount(number: Decimal(1.555), commoditySymbol: TestUtils.eur)
        let posting = try Posting(accountName: TestUtils.chequing, amount: amount, price: price, priceType: .total)

        #expect(String(describing: posting) == "  \(String(describing: TestUtils.chequing)) \(String(describing: amount)) @@ \(price)")
    }

    @Test
    func equalRespectsPriceType() throws {
        let price = Amount(number: Decimal(1.555), commoditySymbol: TestUtils.eur)
        let posting2 = try Posting(accountName: TestUtils.cash, amount: TestUtils.amount, price: price, priceType: .perUnit)
        let posting3 = try Posting(accountName: TestUtils.cash, amount: TestUtils.amount, price: price, priceType: .total)
        #expect(posting2 != posting3)
    }

    @Test
    func balanceTotalPrice() throws {
        let ledger = Ledger()
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170609, payee: "", narration: "", flag: .complete, tags: [])

        // Test with total price: 10 units @@ 155.5 EUR total
        let amount = Amount(number: Decimal(10), commoditySymbol: "💵")
        let totalPrice = Amount(number: Decimal(155.5), commoditySymbol: TestUtils.eur)
        let posting = try Posting(accountName: TestUtils.cash, amount: amount, price: totalPrice, priceType: .total)

        let transaction = Transaction(metaData: transactionMetaData, postings: [posting])
        let transactionPosting = TransactionPosting(posting: posting, transaction: transaction)

        let balance = try transactionPosting.balance(in: ledger)

        // Should be 155.5 EUR total (not 10 * 155.5 = 1555)
        #expect(balance.amounts[TestUtils.eur] == Decimal(155.5))
    }

    @Test
    func balancePerUnitPrice() throws {
        let ledger = Ledger()
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170609, payee: "", narration: "", flag: .complete, tags: [])

        // Test with per-unit price: 10 units @ 15.55 EUR per unit
        let amount = Amount(number: Decimal(10), commoditySymbol: "💵")
        let perUnitPrice = Amount(number: Decimal(15.55), commoditySymbol: TestUtils.eur)
        let posting = try Posting(accountName: TestUtils.cash, amount: amount, price: perUnitPrice, priceType: .perUnit)

        let transaction = Transaction(metaData: transactionMetaData, postings: [posting])
        let transactionPosting = TransactionPosting(posting: posting, transaction: transaction)

        let balance = try transactionPosting.balance(in: ledger)

        // Should be 10 * 15.55 = 155.5 EUR
        #expect(balance.amounts[TestUtils.eur] == Decimal(155.5))
    }

    @Test
    func integrationPerUnitAndTotalPrices() throws {
        // Integration test showing @ and @@ working together
        let ledger = Ledger()
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170609, payee: "Test", narration: "Integration test", flag: .complete, tags: [])

        // Simple test: 10 USD @ 1.5 CAD per unit should equal 5 EUR @@ 7.5 CAD total
        // Both should give us 15 CAD and 7.5 CAD respectively

        // 10 USD @ 1.5 CAD per unit = 15 CAD total
        let amount1 = Amount(number: Decimal(10), commoditySymbol: TestUtils.usd)
        let perUnitPrice = Amount(number: Decimal(1.5), commoditySymbol: TestUtils.cad)
        let posting1 = try Posting(accountName: TestUtils.cash, amount: amount1, price: perUnitPrice, priceType: .perUnit)

        // 5 EUR @@ 7.5 CAD total (which is 1.5 CAD per EUR)
        let amount2 = Amount(number: Decimal(5), commoditySymbol: TestUtils.eur)
        let totalPrice = Amount(number: Decimal(7.5), commoditySymbol: TestUtils.cad)
        let posting2 = try Posting(accountName: TestUtils.chequing, amount: amount2, price: totalPrice, priceType: .total)

        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])

        // Verify descriptions show correct format
        #expect(String(describing: posting1).contains(" @ "))
        #expect(String(describing: posting2).contains(" @@ "))

        // Verify both postings calculate to the same per-unit rate (1.5 CAD)
        let posting1PerUnit = perUnitPrice.number
        let posting2PerUnit = totalPrice.number / amount2.number
        #expect(posting1PerUnit == posting2PerUnit)

        // Verify individual posting balances
        let transactionPosting1 = TransactionPosting(posting: posting1, transaction: transaction)
        let transactionPosting2 = TransactionPosting(posting: posting2, transaction: transaction)

        let balance1 = try transactionPosting1.balance(in: ledger)
        let balance2 = try transactionPosting2.balance(in: ledger)

        // Verify posting 1: 10 USD @ 1.5 CAD = 15 CAD
        #expect(balance1.amounts[TestUtils.cad] == Decimal(15))

        // Verify posting 2: 5 EUR @@ 7.5 CAD = 7.5 CAD total
        #expect(balance2.amounts[TestUtils.cad] == Decimal(7.5))

        // The important part is that @@ uses total price, not per-unit * quantity
        // If posting2 were using per-unit calculation, it would be 5 * 7.5 = 37.5 CAD
        #expect(balance2.amounts[TestUtils.cad] != Decimal(37.5))
    }

    @Test
    func initErrorPriceWithoutType() throws {
        #expect(throws: PostingError.priceWithoutType) { try Posting(accountName: TestUtils.chequing, amount: TestUtils.amount, price: TestUtils.amount2, priceType: nil) }
    }

    @Test(arguments: PostingPriceType.allCases)
    func initErrorPriceTypeWithoutPrice(priceType: PostingPriceType) throws {
        #expect(throws: PostingError.priceTypeWithoutPrice) { try Posting(accountName: TestUtils.chequing, amount: TestUtils.amount, price: nil, priceType: priceType) }
    }

}
