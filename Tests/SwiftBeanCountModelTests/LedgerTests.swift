// swiftlint:disable file_length
//
//  LedgerTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

// swiftlint:disable:next type_body_length
final class LedgerTests: XCTestCase {

    func testCommodities() throws {
        let ledger = Ledger()
        XCTAssertEqual(ledger.commodities.count, 0)

        let commodity1 = Commodity(symbol: "EUR", metaData: ["A": "B"])
        try ledger.add(commodity1)
        XCTAssertEqual(ledger.commodities.count, 1)
        XCTAssertThrowsError(try ledger.add(commodity1)) {
            XCTAssertEqual($0.localizedDescription, "Entry already exists in Ledger: \(commodity1)")
        }
        XCTAssertEqual(ledger.commodities.count, 1)
        XCTAssertEqual(ledger.commodities.first, commodity1)

        let commodity2 = Commodity(symbol: "💵")
        try ledger.add(commodity2)
        XCTAssertEqual(ledger.commodities.count, 2)
        XCTAssertThrowsError(try ledger.add(commodity2))
        XCTAssertEqual(ledger.commodities.count, 2)
        XCTAssert(ledger.commodities.contains(commodity2))
    }

    func testAccounts() throws {
        let ledger = Ledger()
        XCTAssertEqual(ledger.accounts.count, 0)

        let account1 = Account(name: TestUtils.chequing, metaData: ["A": "B"])
        try ledger.add(account1)
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertThrowsError(try ledger.add(account1))
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertEqual(ledger.accounts.first, account1)

        let account2 = Account(name: TestUtils.cash)
        try ledger.add(account2)
        XCTAssertEqual(ledger.accounts.count, 2)
        XCTAssertThrowsError(try ledger.add(account2))
        XCTAssertEqual(ledger.accounts.count, 2)
        XCTAssert(ledger.accounts.contains(account2))

        XCTAssertThrowsError(try ledger.add(Account(name: AccountName("Invalid"))))
        XCTAssertEqual(ledger.accounts.count, 2)
        XCTAssertThrowsError(try ledger.add(Account(name: AccountName("Assets:Invalid:"))))
        XCTAssertEqual(ledger.accounts.count, 2)
        XCTAssertThrowsError(try ledger.add(Account(name: AccountName("Assets::Invalid"))))
        XCTAssertEqual(ledger.accounts.count, 2)
    }

    func testAccountGroups() {
        let ledger = Ledger()
        XCTAssertEqual(ledger.accountGroups.count, AccountType.allValues().count)
        for accountGroup in ledger.accountGroups {
            XCTAssert(AccountType.allValues().map(\.rawValue).contains(accountGroup.nameItem))
        }
    }

    func testAccountGroup() throws {
        let ledger = Ledger()
        let account1 = try Account(name: AccountName("Assets:Checking:RBC"))
        try ledger.add(account1)
        let account2 = Account(name: TestUtils.cash)
        try ledger.add(account2)
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

    func testTransactions() throws {
        let ledger = Ledger()
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170609,
                                                      payee: "Payee",
                                                      narration: "Narration",
                                                      flag: Flag.complete,
                                                      tags: [Tag(name: "test")],
                                                      metaData: ["A": "B"])
        let accountName = TestUtils.cash
        try ledger.add(Account(name: accountName, opening: TestUtils.date20170609))
        let posting = Posting(accountName: accountName,
                              amount: Amount(number: Decimal(10), commoditySymbol: TestUtils.eur),
                              price: Amount(number: Decimal(15), commoditySymbol: TestUtils.usd),
                              cost: try Cost(amount: Amount(number: Decimal(5), commoditySymbol: TestUtils.cad), date: TestUtils.date20170609, label: "TEST"),
                              metaData: ["A": "B"])
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting])

        ledger.add(transaction)
        XCTAssert(ledger.transactions.contains(transaction))
        XCTAssertEqual(ledger.commodities.count, 3)
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertEqual(ledger.tags.count, 1)

        // Test that properties on accounts are not overridden
        let ledger2 = Ledger()
        let account2 = Account(name: TestUtils.cash, opening: TestUtils.date20170610)
        try ledger2.add(account2)
        ledger2.add(transaction)
        XCTAssertEqual(ledger2.accounts.first!.opening, TestUtils.date20170610)
    }

    func testPrices() throws {
        let ledger = Ledger()

        let amount = Amount(number: Decimal(1), commoditySymbol: TestUtils.cad)
        let price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount, metaData: ["A": "B"])

        XCTAssertNoThrow(try ledger.add(price))
        XCTAssertThrowsError(try ledger.add(price))

        // Date different
        let price2 = try Price(date: TestUtils.date20170609, commoditySymbol: TestUtils.eur, amount: amount)
        XCTAssertNoThrow(try ledger.add(price2))
        XCTAssertThrowsError(try ledger.add(price2))

        // Commodity different
        let price3 = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.usd, amount: amount)
        XCTAssertNoThrow(try ledger.add(price3))
        XCTAssertThrowsError(try ledger.add(price3))

        // Amount commodity different
        let amount2 = Amount(number: Decimal(1), commoditySymbol: TestUtils.usd)
        let price4 = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount2)
        XCTAssertNoThrow(try ledger.add(price4))
        XCTAssertThrowsError(try ledger.add(price4))

        // Amount number different
        let amount3 = Amount(number: Decimal(2), commoditySymbol: TestUtils.cad)
        let price5 = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount3)
        XCTAssertThrowsError(try ledger.add(price5))

        XCTAssertEqual(ledger.prices.count, 4)

        XCTAssertTrue(ledger.prices.contains(price))
        XCTAssertTrue(ledger.prices.contains(price2))
        XCTAssertTrue(ledger.prices.contains(price3))
        XCTAssertTrue(ledger.prices.contains(price4))

    }

    func testBalances() throws {
        let ledger = Ledger()
        let account = Account(name: TestUtils.cash)
        let amount = Amount(number: Decimal(1), commoditySymbol: TestUtils.cad)
        let balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: amount, metaData: ["A": "B"])

        try ledger.add(account)
        XCTAssertTrue(ledger.accounts.first!.balances.isEmpty)

        ledger.add(balance)
        XCTAssertEqual(ledger.accounts.first!.balances.first!, balance)
    }

    func testParsingErrors() {
        let error = "TEST"
        let ledger = Ledger()
        ledger.parsingErrors.append(error)
        XCTAssertEqual(ledger.errors.count, 1)
        XCTAssertEqual(ledger.parsingErrors.count, 1)
        XCTAssertEqual(ledger.errors[0], error)
        XCTAssertEqual(ledger.parsingErrors[0], error)
        XCTAssertEqual(String(describing: ledger), "")
    }

    func testValidateTransactions() {
        let ledger = Ledger()
        XCTAssertTrue(ledger.errors.isEmpty)

        // add invalid transaction without postings
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170609,
                                                      payee: "Payee",
                                                      narration: "Narration",
                                                      flag: Flag.complete,
                                                      tags: [Tag(name: "test")])
        let transaction = Transaction(metaData: transactionMetaData, postings: [])
        ledger.add(transaction)
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testValidateTransactionsAtCost() throws {
        let ledger = Ledger()

        let commodity1 = Commodity(symbol: "STOCK", opening: TestUtils.date20170608)
        let commodity2 = Commodity(symbol: "CAD", opening: TestUtils.date20170608)
        let account1 = Account(name: TestUtils.cash, opening: TestUtils.date20170608)
        let account2 = Account(name: TestUtils.chequing, opening: TestUtils.date20170608)

        try ledger.add(commodity1)
        try ledger.add(commodity2)
        try ledger.add(account1)
        try ledger.add(account2)

        let amount1 = Amount(number: 2.0, commoditySymbol: commodity1.symbol, decimalDigits: 1)
        let costAmount = Amount(number: 3.0, commoditySymbol: commodity2.symbol, decimalDigits: 1)
        let amount2 = Amount(number: -6.0, commoditySymbol: commodity2.symbol, decimalDigits: 1)
        let posting1 = Posting(accountName: TestUtils.chequing, amount: amount1, price: nil, cost: try Cost(amount: costAmount, date: nil, label: nil))
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2)
        let transaction1 = Transaction(metaData: TransactionMetaData(date: TestUtils.date20170609, payee: "1", narration: "2", flag: .complete, tags: []),
                                       postings: [posting1, posting2])

        ledger.add(transaction1)
        XCTAssertTrue(ledger.errors.isEmpty)

        let amount3 = Amount(number: -2.0, commoditySymbol: commodity1.symbol, decimalDigits: 1)
        let amount4 = Amount(number: 6.0, commoditySymbol: commodity2.symbol, decimalDigits: 1)
        let posting3 = Posting(accountName: TestUtils.chequing, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))
        let posting4 = Posting(accountName: TestUtils.cash, amount: amount4)
        let transaction2 = Transaction(metaData: TransactionMetaData(date: TestUtils.date20170610, payee: "3", narration: "4", flag: .complete, tags: []),
                                       postings: [posting3, posting4])

        ledger.add(transaction2)
        XCTAssertTrue(ledger.errors.isEmpty)
    }

    func testValidateAccounts() throws {
        var account = Account(name: TestUtils.cash)

        // valid account
        let validLedger = Ledger()
        try validLedger.add(account)
        XCTAssertTrue(validLedger.errors.isEmpty)

        // invalid account with only a closing date
        let invalidLedger = Ledger()
        account = Account(name: TestUtils.cash, closing: TestUtils.date20170609)
        try invalidLedger.add(account)
        XCTAssertFalse(invalidLedger.errors.isEmpty)
    }

    func testValidateAccountBalance() throws {
        let account = Account(name: TestUtils.cash)

        let validLedger = Ledger()
        try validLedger.add(account)
        XCTAssertTrue(validLedger.errors.isEmpty)

        let invalidLedger = Ledger()
        account.balances = [
            Balance(date: TestUtils.date20170608,
                    accountName: TestUtils.cash,
                    amount: Amount(number: 1, commoditySymbol: TestUtils.cad))
        ]
        try invalidLedger.add(account)
        XCTAssertFalse(invalidLedger.errors.isEmpty)
    }

    func testValidateAccountInventory() throws {
        let ledger = Ledger()
        let account = Account(name: TestUtils.cash, commoditySymbol: TestUtils.cad)
        let amount = Amount(number: 1.1, commoditySymbol: TestUtils.cad, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 5, commoditySymbol: TestUtils.cad), date: nil, label: "1")
        try ledger.add(account)

        var posting = Posting(accountName: TestUtils.cash, amount: amount, price: nil, cost: cost)
        var transaction = Transaction(metaData: TransactionMetaData(date: TestUtils.date20170608, payee: "", narration: "", flag: .complete, tags: []),
                                      postings: [posting])
        ledger.add(transaction)

        posting = Posting(accountName: TestUtils.cash, amount: amount, price: nil, cost: cost)
        transaction = Transaction(metaData: TransactionMetaData(date: TestUtils.date20170609, payee: "", narration: "", flag: .complete, tags: []),
                                  postings: [posting])
        ledger.add(transaction)

        posting = Posting(accountName: TestUtils.cash,
                          amount: Amount(number: -1.0, commoditySymbol: TestUtils.cad, decimalDigits: 0),
                          price: nil,
                          cost: try Cost(amount: Amount(number: 5, commoditySymbol: TestUtils.cad), date: nil, label: nil))
        transaction = Transaction(metaData: TransactionMetaData(date: TestUtils.date20170610, payee: "", narration: "", flag: .complete, tags: []),
                                  postings: [posting])
        ledger.add(transaction)
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testValidateCommodities() throws {
        // Test with commodity that has opening date - should always be valid
        let validCommodity = Commodity(symbol: "EUR", opening: TestUtils.date20170608)
        let validLedger = Ledger()
        try validLedger.add(validCommodity)
        XCTAssertTrue(validLedger.errors.isEmpty)

        // Test without check_commodity plugin - should be valid even without opening date
        let invalidCommodity = TestUtils.eurCommodity
        let ledgerWithoutPlugin = Ledger()
        try ledgerWithoutPlugin.add(invalidCommodity)
        XCTAssertTrue(ledgerWithoutPlugin.errors.isEmpty, "Commodity without opening date should be valid when check_commodity plugin is not enabled")

        // Test with check_commodity plugin enabled - should be invalid without opening date
        let ledgerWithPlugin = Ledger()
        ledgerWithPlugin.plugins.append("beancount.plugins.check_commodity")
        try ledgerWithPlugin.add(TestUtils.eurCommodity)
        XCTAssertFalse(ledgerWithPlugin.errors.isEmpty, "Commodity without opening date should be invalid when check_commodity plugin is enabled")
        XCTAssertTrue(ledgerWithPlugin.errors.contains("Commodity EUR does not have an opening date"), "Should contain specific error message for EUR commodity")
    }

    func testCommodityValidationWithAutoCreatedCommodities() throws {
        // Test auto-created commodities without plugin
        let ledgerWithoutPlugin = Ledger()
        let posting = Posting(accountName: TestUtils.cash, amount: Amount(number: Decimal(100), commoditySymbol: "USD"))
        let transaction = Transaction(
            metaData: TransactionMetaData(date: TestUtils.date20170609, payee: "Test", narration: "Test", flag: .complete, tags: []),
            postings: [posting]
        )
        ledgerWithoutPlugin.add(transaction)

        // Should have transaction validation error (unbalanced) but no commodity errors
        let commodityErrors = ledgerWithoutPlugin.errors.filter { $0.contains("does not have an opening date") }
        XCTAssertTrue(commodityErrors.isEmpty, "Auto-created commodities should not generate errors when plugin is not enabled")

        // Test auto-created commodities with plugin
        let ledgerWithPlugin = Ledger()
        ledgerWithPlugin.plugins.append("beancount.plugins.check_commodity")
        ledgerWithPlugin.add(transaction)

        // Should have both transaction validation error and commodity error
        let expectedError = "Commodity USD does not have an opening date"
        XCTAssertTrue(ledgerWithPlugin.errors.contains(expectedError), "Auto-created commodities should generate errors when plugin is enabled")
    }

    func testDescriptionTransactionsAccountsCommodities() throws {
        let accountName = TestUtils.cash
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let commodity = Commodity(symbol: "EUR", opening: TestUtils.date20170609)
        var account = Account(name: accountName, opening: TestUtils.date20170609)
        let posting = Posting(accountName: accountName, amount: Amount(number: Decimal(10), commoditySymbol: commodity.symbol))
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting])
        var ledger = Ledger()

        // Empty ledger
        XCTAssertEqual(String(describing: ledger), "")

        // Ledger with commodity only
        try ledger.add(commodity)
        XCTAssertEqual(String(describing: ledger), String(describing: commodity))

        // Ledger with account opening and commodity
        try ledger.add(account)
        XCTAssertEqual(String(describing: ledger), "\(String(describing: commodity))\n\(String(describing: ledger.accounts.first { $0.name == accountName }!))")

        // Ledger with transactions, account opening and commodity
        ledger.add(transaction)
        XCTAssertEqual(String(describing: ledger),
                       "\(String(describing: commodity))\n\(String(describing: ledger.accounts.first { $0.name == accountName }!))\n\(String(describing: transaction))")

        // Ledger with transaction, account opening as well as closing and commodity
        ledger = Ledger()
        try ledger.add(commodity)
        account = Account(name: accountName, opening: TestUtils.date20170609, closing: TestUtils.date20170610)
        try ledger.add(account)
        ledger.add(transaction)
        XCTAssertEqual(String(describing: ledger),
                       "\(String(describing: commodity))\n\(String(describing: ledger.accounts.first { $0.name == accountName }!))\n\(String(describing: transaction))")

        // ledger with only account opening
        ledger = Ledger()
        let account2 = Account(name: accountName, opening: TestUtils.date20170609)
        try ledger.add(account2)
        XCTAssertEqual(String(describing: ledger), String(describing: ledger.accounts.first!))

        // Test new line after account
        let price = try Price(date: TestUtils.date20170609, commoditySymbol: TestUtils.eur, amount: Amount(number: 10, commoditySymbol: TestUtils.cad, decimalDigits: 2))
        try ledger.add(price)
        XCTAssertEqual(String(describing: ledger), "\(String(describing: ledger.accounts.first!))\n\(String(describing: price))")
    }

    func testDescriptionPrice() throws {
        let ledger = Ledger()
        let price1 = try Price(date: TestUtils.date20170609, commoditySymbol: TestUtils.eur, amount: Amount(number: 10, commoditySymbol: TestUtils.cad, decimalDigits: 2))
        let price2 = try Price(date: TestUtils.date20170610, commoditySymbol: TestUtils.eur, amount: Amount(number: 10, commoditySymbol: TestUtils.cad, decimalDigits: 2))
        try ledger.add(price1)
        XCTAssertEqual(String(describing: ledger), String(describing: price1))
        try ledger.add(price2)
        XCTAssertEqual(String(describing: ledger), "\(String(describing: price1))\n\(String(describing: price2))")
    }

    func testDescriptionOptions() {
        let ledger = Ledger()
        let option1 = Option(name: "a", value: "b")
        ledger.option.append(option1)
        XCTAssertEqual(String(describing: ledger), String(describing: option1))
        let option2 = Option(name: "z", value: "y")
        ledger.option.append(option2)
        XCTAssertEqual(String(describing: ledger), "\(String(describing: option1))\n\(String(describing: option2))")
        ledger.plugins.append("p") // Test new line after options
        XCTAssertEqual(String(describing: ledger), "\(String(describing: option1))\n\(String(describing: option2))\nplugin \"p\"")
    }

    func testDescriptionPlugins() {
        let ledger = Ledger()
        ledger.plugins.append("p")
        XCTAssertEqual(String(describing: ledger), "plugin \"p\"")
        ledger.plugins.append("p1")
        XCTAssertEqual(String(describing: ledger), "plugin \"p\"\nplugin \"p1\"")
        let custom = Custom(date: TestUtils.date20170610, name: "a", values: ["b"])
        ledger.custom.append(custom) // Test new line after plugins
        XCTAssertEqual(String(describing: ledger), "plugin \"p\"\nplugin \"p1\"\n\(String(describing: custom))")
    }

    func testDescriptionCustoms() {
        let ledger = Ledger()
        let custom1 = Custom(date: TestUtils.date20170610, name: "a", values: ["b"])
        let custom2 = Custom(date: TestUtils.date20170609, name: "c", values: ["d", "e"])
        ledger.custom.append(custom1)
        XCTAssertEqual(String(describing: ledger), String(describing: custom1))
        ledger.custom.append(custom2)
        XCTAssertEqual(String(describing: ledger), "\(String(describing: custom1))\n\(String(describing: custom2))")
        let event = Event(date: TestUtils.date20170610, name: "e", value: "e1")
        ledger.events.append(event) // Test new line after customs
        XCTAssertEqual(String(describing: ledger), "\(String(describing: custom1))\n\(String(describing: custom2))\n\(String(describing: event))")
    }

    func testDescriptionEvents() throws {
        let ledger = Ledger()
        let event1 = Event(date: TestUtils.date20170610, name: "e", value: "e1")
        let event2 = Event(date: TestUtils.date20170609, name: "c", value: "d")
        ledger.events.append(event1)
        XCTAssertEqual(String(describing: ledger), String(describing: event1))
        ledger.events.append(event2)
        XCTAssertEqual(String(describing: ledger), "\(String(describing: event1))\n\(String(describing: event2))")
        let commodity = Commodity(symbol: "EUR", opening: TestUtils.date20170609)
        try ledger.add(commodity) // Test new line after events
        XCTAssertEqual(String(describing: ledger), "\(String(describing: event1))\n\(String(describing: event2))\n\(String(describing: commodity))")
    }

    func testEqualEmpty() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualErrors() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        // test errors are ignored
        ledger1.parsingErrors.append("String")
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualTransactions() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        let accountName = TestUtils.cash
        let amount1 = Amount(number: 1, commoditySymbol: TestUtils.cad, decimalDigits: 1)
        let amount2 = Amount(number: 1, commoditySymbol: TestUtils.cad, decimalDigits: 2)

        // same meta data but different posting
        let transactionMetaData = TransactionMetaData(date: Date(), payee: name, narration: name, flag: Flag.complete, tags: [])
        let posting1 = Posting(accountName: accountName, amount: amount1)
        let posting2 = Posting(accountName: accountName, amount: amount2)
        let transaction1 = Transaction(metaData: transactionMetaData, postings: [posting1])
        let transaction2 = Transaction(metaData: transactionMetaData, postings: [posting2])

        ledger1.add(transaction1)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.add(transaction2)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger1.add(transaction2)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.add(transaction1)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualCommodities() throws {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        try ledger1.add(TestUtils.cadCommodity)
        XCTAssertNotEqual(ledger1, ledger2)
        try ledger2.add(TestUtils.eurCommodity)
        XCTAssertNotEqual(ledger1, ledger2)
        try ledger1.add(TestUtils.eurCommodity)
        XCTAssertNotEqual(ledger1, ledger2)
        try ledger2.add(TestUtils.cadCommodity)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualAccounts() throws {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        let account1 = Account(name: TestUtils.cash)
        let account2 = Account(name: TestUtils.chequing)

        try ledger1.add(account1)
        XCTAssertNotEqual(ledger1, ledger2)
        try ledger2.add(account2)
        XCTAssertNotEqual(ledger1, ledger2)
        try ledger1.add(account2)
        XCTAssertNotEqual(ledger1, ledger2)
        try ledger2.add(account1)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualPrices() throws {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        let amount1 = Amount(number: 1, commoditySymbol: TestUtils.cad, decimalDigits: 1)
        let amount2 = Amount(number: 1, commoditySymbol: TestUtils.cad, decimalDigits: 2)
        let price1 = try Price(date: Date(), commoditySymbol: TestUtils.eur, amount: amount1)
        let price2 = try Price(date: Date() + 1, commoditySymbol: TestUtils.eur, amount: amount2)

        try ledger1.add(price1)
        XCTAssertNotEqual(ledger1, ledger2)
        try ledger2.add(price2)
        XCTAssertNotEqual(ledger1, ledger2)
        try ledger1.add(price2)
        XCTAssertNotEqual(ledger1, ledger2)
        try ledger2.add(price1)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualCustom() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        let custom1 = Custom(date: Date(), name: "test", values: ["test1"])
        let custom2 = Custom(date: Date(), name: "test", values: ["test1", "test2"])

        ledger1.custom.append(custom1)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.custom.append(custom2)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger1.custom.append(custom2)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.custom.append(custom1)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualOptions() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        let option1 = Option(name: "a", value: "b")
        let option2 = Option(name: "a", value: "c")

        ledger1.option.append(option1)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.option.append(option2)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.option.append(option1)
        ledger1.option.append(option2)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualEvents() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        let event1 = Event(date: Date(), name: "event", value: "event_value1")
        let event2 = Event(date: Date(), name: "event", value: "event_value2")

        ledger1.events.append(event1)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.events.append(event2)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger1.events.append(event2)
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.events.append(event1)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualPlugins() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        ledger1.plugins.append("New Plugin")
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.plugins.append("New Plugin1")
        XCTAssertNotEqual(ledger1, ledger2)
        ledger1.plugins.append("New Plugin1")
        XCTAssertNotEqual(ledger1, ledger2)
        ledger2.plugins.append("New Plugin")
        XCTAssertEqual(ledger1, ledger2)
    }

    func testValidateUnusedAccountsWithoutPlugin() throws {
        let ledger = Ledger()
        let account = Account(name: TestUtils.cash)
        try ledger.add(account)

        // Without the nounused plugin, no errors should be generated for unused accounts
        XCTAssertTrue(ledger.errors.isEmpty)
    }

    func testValidateUnusedAccountsWithPlugin() throws {
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.nounused")
        let account = Account(name: TestUtils.cash)
        try ledger.add(account)

        // With the nounused plugin, unused accounts should generate errors
        XCTAssertFalse(ledger.errors.isEmpty)
        XCTAssertEqual(ledger.errors.count, 1)
        XCTAssertEqual(ledger.errors[0], "Account Assets:Cash has no postings")
    }

    func testValidateUsedAccountsWithPlugin() throws {
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.nounused")

        // Add commodity with opening date
        try ledger.add(Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170608))

        // Add accounts with opening dates
        let cashAccount = Account(name: TestUtils.cash, opening: TestUtils.date20170608)
        let incomeAccount = Account(name: TestUtils.income, opening: TestUtils.date20170608)
        try ledger.add(cashAccount)
        try ledger.add(incomeAccount)

        // Add a balanced transaction that uses the account
        let posting1 = Posting(accountName: TestUtils.cash, amount: Amount(number: 10, commoditySymbol: TestUtils.cad))
        let posting2 = Posting(accountName: TestUtils.income, amount: Amount(number: -10, commoditySymbol: TestUtils.cad))
        let metaData = TransactionMetaData(date: TestUtils.date20170609, payee: "Payee", narration: "Narration", flag: .complete, tags: [])
        let transaction = Transaction(metaData: metaData, postings: [posting1, posting2])
        ledger.add(transaction)

        // With the nounused plugin, used accounts should not generate errors
        XCTAssertTrue(ledger.errors.isEmpty)
    }

    func testValidateMultipleUnusedAccountsWithPlugin() throws {
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.nounused")

        let account1 = Account(name: TestUtils.cash)
        let account2 = Account(name: TestUtils.chequing)
        try ledger.add(account1)
        try ledger.add(account2)

        // Both accounts should generate errors
        XCTAssertFalse(ledger.errors.isEmpty)
        XCTAssertEqual(ledger.errors.count, 2)
        XCTAssert(ledger.errors.contains("Account Assets:Cash has no postings"))
        XCTAssert(ledger.errors.contains("Account Assets:Chequing has no postings"))
    }

    func testValidateMixedAccountsWithPlugin() throws {
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.nounused")

        // Add commodity with opening date
        try ledger.add(Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170608))

        let unusedAccount = Account(name: TestUtils.cash)
        let usedAccount = Account(name: TestUtils.chequing, opening: TestUtils.date20170608)
        let incomeAccount = Account(name: TestUtils.income, opening: TestUtils.date20170608)
        try ledger.add(unusedAccount)
        try ledger.add(usedAccount)
        try ledger.add(incomeAccount)

        // Add a balanced transaction that only uses one account
        let posting1 = Posting(accountName: TestUtils.chequing, amount: Amount(number: 10, commoditySymbol: TestUtils.cad))
        let posting2 = Posting(accountName: TestUtils.income, amount: Amount(number: -10, commoditySymbol: TestUtils.cad))
        let metaData = TransactionMetaData(date: TestUtils.date20170609, payee: "Payee", narration: "Narration", flag: .complete, tags: [])
        let transaction = Transaction(metaData: metaData, postings: [posting1, posting2])
        ledger.add(transaction)

        // Only the unused account should generate an error
        XCTAssertFalse(ledger.errors.isEmpty)
        XCTAssertEqual(ledger.errors.count, 1)
        XCTAssertEqual(ledger.errors[0], "Account Assets:Cash has no postings")
    }

    func testValidateCommodityUsageDatesIntegration() throws {
        // Integration test for commodity usage date validation across different entities
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodity with opening date
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170609)
        try ledger.add(eurCommodity)

        // Add transaction using commodity before opening date
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170608, payee: "Test", narration: "Test", flag: .complete, tags: [])
        let posting = Posting(accountName: TestUtils.cash, amount: Amount(number: Decimal(100), commoditySymbol: TestUtils.eur))
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting])
        ledger.add(transaction)

        // Add price using commodity before opening date
        let priceAmount = Amount(number: Decimal(1.2), commoditySymbol: TestUtils.cad)
        let price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: priceAmount)
        try ledger.add(price)

        // Add balance using commodity before opening date (this will create the account)
        let balanceAmount = Amount(number: Decimal(50), commoditySymbol: TestUtils.eur)
        let balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: balanceAmount)
        ledger.add(balance)

        // Check that all validation errors are present
        let errors = ledger.errors
        let commodityUsageErrors = errors.filter { $0.contains("EUR used on 2017-06-08 before its opening date of 2017-06-09") }

        // Should have commodity usage errors showing that the validation is working
        XCTAssertTrue(commodityUsageErrors.count >= 1, "Should have commodity usage errors showing validation is working")
    }

    func testValidateCommodityUsageDatesIntegrationValid() throws {
        // Integration test for valid commodity usage dates
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodity with opening date before usage
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170608)
        try ledger.add(eurCommodity)

        // Add transaction using commodity on opening date
        let transactionMetaData = TransactionMetaData(date: TestUtils.date20170608, payee: "Test", narration: "Test", flag: .complete, tags: [])
        let posting1 = Posting(accountName: TestUtils.cash, amount: Amount(number: Decimal(100), commoditySymbol: TestUtils.eur))
        let posting2 = Posting(accountName: TestUtils.chequing, amount: Amount(number: Decimal(-100), commoditySymbol: TestUtils.eur))
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])
        ledger.add(transaction)

        // Add price using commodity on opening date
        let priceAmount = Amount(number: Decimal(1.2), commoditySymbol: TestUtils.cad)
        let price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: priceAmount)
        try ledger.add(price)

        // Add balance using commodity on opening date (this will create the account)
        let balanceAmount = Amount(number: Decimal(100), commoditySymbol: TestUtils.eur)
        let balance = Balance(date: TestUtils.date20170608, accountName: TestUtils.cash, amount: balanceAmount)
        ledger.add(balance)

        // Check that no commodity usage errors are present
        let errors = ledger.errors
        let commodityUsageErrors = errors.filter { $0.contains("used on") && $0.contains("before its opening date") }

        // Should have no commodity usage errors (balance error is expected due to transaction not being balanced)
        XCTAssertTrue(commodityUsageErrors.isEmpty, "Should have no commodity usage date errors when all commodities are used on or after opening dates")
    }

}
