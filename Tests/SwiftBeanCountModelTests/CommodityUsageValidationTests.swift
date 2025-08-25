//
//  CommodityUsageValidationTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Copilot on 2025-08-24.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

final class CommodityUsageValidationTests: XCTestCase {

    func testValidateCommodityUsageDatesWithoutPlugin() throws {
        // Test that commodity usage dates are not validated when plugin is not enabled
        let ledger = Ledger()

        // Add commodities with opening dates after the transaction date
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170609)
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170609)
        try ledger.add(eurCommodity)
        try ledger.add(cadCommodity)

        // Add accounts to the ledger
        let cashAccount = Account(name: TestUtils.cash, opening: TestUtils.date20170608)
        let chequingAccount = Account(name: TestUtils.chequing, opening: TestUtils.date20170608)
        try ledger.add(cashAccount)
        try ledger.add(chequingAccount)

        // Create transaction before commodity opening dates
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170608, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let posting1 = Posting(accountName: TestUtils.cash, amount: Amount(number: Decimal(10), commoditySymbol: TestUtils.eur))
        let posting2 = Posting(accountName: TestUtils.chequing, amount: Amount(number: Decimal(-10), commoditySymbol: TestUtils.eur))
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])

        // Should be valid since plugin is not enabled
        guard case .valid = transaction.validate(in: ledger) else {
            XCTFail("Transaction should be valid when check_commodity plugin is not enabled")
            return
        }
    }

    func testValidateCommodityUsageDatesWithPlugin() throws {
        // Test that commodity usage dates are validated when plugin is enabled
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodities with opening dates after the transaction date
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170609)
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170609)
        try ledger.add(eurCommodity)
        try ledger.add(cadCommodity)

        // Add accounts to the ledger
        let cashAccount = Account(name: TestUtils.cash, opening: TestUtils.date20170608)
        let chequingAccount = Account(name: TestUtils.chequing, opening: TestUtils.date20170608)
        try ledger.add(cashAccount)
        try ledger.add(chequingAccount)

        // Create transaction before commodity opening dates
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170608, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let posting1 = Posting(accountName: TestUtils.cash, amount: Amount(number: Decimal(10), commoditySymbol: TestUtils.eur))
        let posting2 = Posting(accountName: TestUtils.chequing, amount: Amount(number: Decimal(-10), commoditySymbol: TestUtils.eur))
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])

        // Should be invalid since commodity is used before opening
        if case .invalid(let error) = transaction.validate(in: ledger) {
            XCTAssertTrue(error.contains("EUR used on 2017-06-08 before its opening date of 2017-06-09"))
        } else {
            XCTFail("Transaction should be invalid when commodity is used before opening date")
        }
    }

    func testValidatePriceCommodityUsageDates() throws {
        // Test validation of price commodity usage dates
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodities with opening dates
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170609)
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170608)
        try ledger.add(eurCommodity)
        try ledger.add(cadCommodity)

        // Add accounts to the ledger
        let cashAccount = Account(name: TestUtils.cash, opening: TestUtils.date20170608)
        let chequingAccount = Account(name: TestUtils.chequing, opening: TestUtils.date20170608)
        try ledger.add(cashAccount)
        try ledger.add(chequingAccount)

        // Create transaction with price before EUR opening date
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170608, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let price = Amount(number: Decimal(1.2), commoditySymbol: TestUtils.eur) // EUR opens on 2017-06-09
        let posting1 = Posting(accountName: TestUtils.cash, amount: Amount(number: Decimal(10), commoditySymbol: TestUtils.cad), price: price)
        let posting2 = Posting(accountName: TestUtils.chequing, amount: Amount(number: Decimal(-12), commoditySymbol: TestUtils.eur))
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])

        // Should be invalid since EUR (price commodity) is used before opening
        if case .invalid(let error) = transaction.validate(in: ledger) {
            XCTAssertTrue(error.contains("EUR used on 2017-06-08 before its opening date of 2017-06-09"))
        } else {
            XCTFail("Transaction should be invalid when price commodity is used before opening date")
        }
    }

    func testValidateCostCommodityUsageDates() throws {
        // Test validation of cost commodity usage dates
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodities with opening dates
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170609)
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170608)
        try ledger.add(eurCommodity)
        try ledger.add(cadCommodity)

        // Add accounts to the ledger
        let cashAccount = Account(name: TestUtils.cash, opening: TestUtils.date20170608)
        let chequingAccount = Account(name: TestUtils.chequing, opening: TestUtils.date20170608)
        try ledger.add(cashAccount)
        try ledger.add(chequingAccount)

        // Create transaction with cost before EUR opening date
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170608, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let costAmount = Amount(number: Decimal(1.2), commoditySymbol: TestUtils.eur) // EUR opens on 2017-06-09
        let cost = try Cost(amount: costAmount, date: TestUtils.date20170608, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: Amount(number: Decimal(10), commoditySymbol: TestUtils.cad), cost: cost)
        let posting2 = Posting(accountName: TestUtils.chequing, amount: Amount(number: Decimal(-12), commoditySymbol: TestUtils.eur))
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])

        // Should be invalid since EUR (cost commodity) is used before opening
        if case .invalid(let error) = transaction.validate(in: ledger) {
            XCTAssertTrue(error.contains("EUR used on 2017-06-08 before its opening date of 2017-06-09"))
        } else {
            XCTFail("Transaction should be invalid when cost commodity is used before opening date")
        }
    }

    func testValidateCommodityUsageDatesValid() throws {
        // Test that validation passes when commodities are used on or after opening dates
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodities with opening dates before or on the transaction date
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170608)
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170608)
        try ledger.add(eurCommodity)
        try ledger.add(cadCommodity)

        // Add accounts to the ledger
        let cashAccount = Account(name: TestUtils.cash, opening: TestUtils.date20170608)
        let chequingAccount = Account(name: TestUtils.chequing, opening: TestUtils.date20170608)
        try ledger.add(cashAccount)
        try ledger.add(chequingAccount)

        // Create transaction on the commodity opening dates
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170608, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let posting1 = Posting(accountName: TestUtils.cash, amount: Amount(number: Decimal(10), commoditySymbol: TestUtils.eur))
        let posting2 = Posting(accountName: TestUtils.chequing, amount: Amount(number: Decimal(-10), commoditySymbol: TestUtils.eur))
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])

        // Should be valid since commodities are used on or after opening dates
        guard case .valid = transaction.validate(in: ledger) else {
            XCTFail("Transaction should be valid when commodities are used on or after opening dates")
            return
        }
    }

}
