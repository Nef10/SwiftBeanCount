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

//swiftlint:disable:next type_body_length
class LedgerTests: XCTestCase {

    func testCommodities() {
        let ledger = Ledger()
        XCTAssertEqual(ledger.commodities.count, 0)

        let commodity1 = Commodity(symbol: "EUR")
        commodity1.metaData["A"] = "B"
        try! ledger.add(commodity1)
        XCTAssertEqual(ledger.commodities.count, 1)
        XCTAssertThrowsError(try ledger.add(commodity1)) {
            XCTAssertEqual($0.localizedDescription, "Entry already exists in Ledger: \(commodity1)")
        }
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

        let account1 = try! Account(name: AccountName("Assets:Checking"))
        account1.metaData["A"] = "B"
        try! ledger.add(account1)
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertThrowsError(try ledger.add(account1))
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertEqual(ledger.accounts.first, account1)

        let account2 = try! Account(name: AccountName("Assets:💰"))
        try! ledger.add(account2)
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
            XCTAssert(AccountType.allValues().map { $0.rawValue }.contains(accountGroup.nameItem))
        }
    }

    func testAccountGroup() {
        let ledger = Ledger()
        let account1 = try! Account(name: AccountName("Assets:Checking:RBC"))
        try! ledger.add(account1)
        let account2 = try! Account(name: AccountName("Assets:Cash"))
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

    func testTransactions() {
        let ledger = Ledger()
        let date = Date(timeIntervalSince1970: 1_496_991_600)
        var transactionMetaData = TransactionMetaData(date: date,
                                                      payee: "Payee",
                                                      narration: "Narration",
                                                      flag: Flag.complete,
                                                      tags: [Tag(name: "test")])
        transactionMetaData.metaData["A"] = "B"
        let transaction = Transaction(metaData: transactionMetaData)
        let account = try! Account(name: AccountName("Assets:Cash"), opening: date)
        try! ledger.add(account)
        var posting = Posting(account: account,
                              amount: Amount(number: Decimal(10), commodity: Commodity(symbol: "EUR")),
                              transaction: transaction,
                              price: Amount(number: Decimal(15), commodity: Commodity(symbol: "USD")),
                              cost: try! Cost(amount: Amount(number: Decimal(5), commodity: Commodity(symbol: "CAD")), date: date, label: "TEST"))
        posting.metaData["C"] = "D"
        transaction.postings.append(posting)

        let addedTransaction = ledger.add(transaction)
        XCTAssertEqual(addedTransaction, transaction)
        XCTAssert(ledger.transactions.contains(addedTransaction))
        XCTAssertEqual(ledger.commodities.count, 3)
        XCTAssertEqual(ledger.accounts.count, 1)
        XCTAssertEqual(ledger.tags.count, 1)

        // Test that properties on accounts are not overridden
        let date2 = date.addingTimeInterval(1_000_000)
        let ledger2 = Ledger()
        let account2 = try! Account(name: AccountName("Assets:Cash"), opening: date2)
        try! ledger2.add(account2)
        _ = ledger2.add(transaction)
        XCTAssertEqual(ledger2.accounts.first!.opening, date2)
    }

    func testPrices() {
        let ledger = Ledger()

        let date = Date(timeIntervalSince1970: 1_496_905_200)
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "CAD"))
        let commodity = Commodity(symbol: "EUR")

        var price = try! Price(date: date, commodity: commodity, amount: amount)
        price.metaData["A"] = "B"

        XCTAssertNoThrow(try ledger.add(price))
        XCTAssertThrowsError(try ledger.add(price))

        // Date different
        let date2 = Date(timeIntervalSince1970: 1_496_991_600)
        let price2 = try! Price(date: date2, commodity: commodity, amount: amount)
        XCTAssertNoThrow(try ledger.add(price2))
        XCTAssertThrowsError(try ledger.add(price2))

        // Commodity different
        let commodity2 = Commodity(symbol: "USD")
        let price3 = try! Price(date: date, commodity: commodity2, amount: amount)
        XCTAssertNoThrow(try ledger.add(price3))
        XCTAssertThrowsError(try ledger.add(price3))

        // Amount commodity different
        let amount2 = Amount(number: Decimal(1), commodity: Commodity(symbol: "USD"))
        let price4 = try! Price(date: date, commodity: commodity, amount: amount2)
        XCTAssertNoThrow(try ledger.add(price4))
        XCTAssertThrowsError(try ledger.add(price4))

        // Amount number different
        let amount3 = Amount(number: Decimal(2), commodity: Commodity(symbol: "CAD"))
        let price5 = try! Price(date: date, commodity: commodity, amount: amount3)
        XCTAssertThrowsError(try ledger.add(price5))

        XCTAssertEqual(ledger.prices.count, 4)

        XCTAssertTrue(ledger.prices.contains(price))
        XCTAssertTrue(ledger.prices.contains(price2))
        XCTAssertTrue(ledger.prices.contains(price3))
        XCTAssertTrue(ledger.prices.contains(price4))

    }

    func testBalances() {
        let ledger = Ledger()
        let account = try! Account(name: AccountName("Assets:Test"))
        let date = Date(timeIntervalSince1970: 1_496_905_200)
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "CAD"))
        var balance = Balance(date: date, account: account, amount: amount)
        balance.metaData["A"] = "B"

        try! ledger.add(account)
        XCTAssertTrue(ledger.accounts.first!.balances.isEmpty)

        try! ledger.add(balance)
        XCTAssertTrue(ledger.accounts.first!.balances.first! == balance)
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
        let transactionMetaData = TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_991_600),
                                                      payee: "Payee",
                                                      narration: "Narration",
                                                      flag: Flag.complete,
                                                      tags: [Tag(name: "test")])
        let transaction = Transaction(metaData: transactionMetaData)
        _ = ledger.add(transaction)
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testValidateTransactionsAtCost() {
        let ledger = Ledger()

        let commodity1 = Commodity(symbol: "STOCK", opening: Date(timeIntervalSince1970: 1_396_991_600))
        let commodity2 = Commodity(symbol: "CAD", opening: Date(timeIntervalSince1970: 1_396_991_600))
        let account1 = try! Account(name: AccountName("Assets:Cash"), opening: Date(timeIntervalSince1970: 1_396_991_600))
        let account2 = try! Account(name: AccountName("Assets:Holding"), opening: Date(timeIntervalSince1970: 1_396_991_600))

        try! ledger.add(commodity1)
        try! ledger.add(commodity2)
        try! ledger.add(account1)
        try! ledger.add(account2)

        let transaction1 = Transaction(metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_991_600), payee: "1", narration: "2", flag: .complete, tags: []))
        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let costAmount = Amount(number: 3.0, commodity: commodity2, decimalDigits: 1)
        let amount2 = Amount(number: -6.0, commodity: commodity2, decimalDigits: 1)
        let posting1 = Posting(account: account2, amount: amount1, transaction: transaction1, price: nil, cost: try! Cost(amount: costAmount, date: nil, label: nil))
        let posting2 = Posting(account: account1, amount: amount2, transaction: transaction1)
        transaction1.postings.append(contentsOf: [posting1, posting2])

        _ = ledger.add(transaction1)
        XCTAssertTrue(ledger.errors.isEmpty)

        let transaction2 = Transaction(metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_596_991_600), payee: "3", narration: "4", flag: .complete, tags: []))
        let amount3 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let amount4 = Amount(number: 6.0, commodity: commodity2, decimalDigits: 1)
        let posting3 = Posting(account: account2, amount: amount3, transaction: transaction2, price: nil, cost: try! Cost(amount: nil, date: nil, label: nil))
        let posting4 = Posting(account: account1, amount: amount4, transaction: transaction2)
        transaction2.postings.append(contentsOf: [posting3, posting4])

        _ = ledger.add(transaction2)
        XCTAssertTrue(ledger.errors.isEmpty)
    }

    func testValidateAccounts() {
        let account = try! Account(name: AccountName("Assets:Test"))

        // valid account
        let validLedger = Ledger()
        try! validLedger.add(account)
        XCTAssertTrue(validLedger.errors.isEmpty)

        // invalid account with only a closing date
        let invalidLedger = Ledger()
        account.closing = Date(timeIntervalSince1970: 1_496_991_600)
        try! invalidLedger.add(account)
        XCTAssertFalse(invalidLedger.errors.isEmpty)
    }

    func testValidateAccountBalance() {
        let account = try! Account(name: AccountName("Assets:Test"))

        let validLedger = Ledger()
        try! validLedger.add(account)
        XCTAssertTrue(validLedger.errors.isEmpty)

        let invalidLedger = Ledger()
        account.balances = [Balance(date: Date(timeIntervalSince1970: 1_496_905_200), account: account, amount: Amount(number: 1, commodity: Commodity(symbol: "CAD")))]
        try! invalidLedger.add(account)
        XCTAssertFalse(invalidLedger.errors.isEmpty)
    }

    func testValidateAccountInventory() {
        let ledger = Ledger()
        let commodity = Commodity(symbol: "CAD")
        let account = try! Account(name: AccountName("Assets:Test"), commodity: commodity)
        let amount = Amount(number: 1.1, commodity: commodity, decimalDigits: 1)
        let cost = try! Cost(amount: Amount(number: 5, commodity: commodity), date: nil, label: "1")
        try! ledger.add(account)

        var transaction = Transaction(metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_905_200), payee: "", narration: "", flag: .complete, tags: []))
        transaction.postings.append(Posting(account: account, amount: amount, transaction: transaction, price: nil, cost: cost))
        _ = ledger.add(transaction)

        transaction = Transaction(metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_991_600), payee: "", narration: "", flag: .complete, tags: []))
        transaction.postings.append(Posting(account: account, amount: amount, transaction: transaction, price: nil, cost: cost))
        _ = ledger.add(transaction)

        transaction = Transaction(metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_497_078_000), payee: "", narration: "", flag: .complete, tags: []))
        transaction.postings.append(Posting(account: account,
                                            amount: Amount(number: -1.0, commodity: commodity, decimalDigits: 0),
                                            transaction: transaction,
                                            price: nil,
                                            cost: try! Cost(amount: Amount(number: 5, commodity: commodity), date: nil, label: nil)))
        _ = ledger.add(transaction)
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testValidateCommodities() {
        let validCommodity = Commodity(symbol: "EUR", opening: Date(timeIntervalSince1970: 1_496_905_200))
        let validLedger = Ledger()
        try! validLedger.add(validCommodity)
        XCTAssertTrue(validLedger.errors.isEmpty)

        let invalidCommodity = Commodity(symbol: "EUR")
        let invalidLedger = Ledger()
        try! invalidLedger.add(invalidCommodity)
        XCTAssertFalse(invalidLedger.errors.isEmpty)
    }

    func testDescriptionTransactionsAccountsCommodities() {
        let accountName = try! AccountName("Assets:Cash")
        let transactionMetaData = TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_991_600), payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transaction = Transaction(metaData: transactionMetaData)
        let commodity = Commodity(symbol: "EUR", opening: Date(timeIntervalSince1970: 1_496_991_600))
        let account = Account(name: accountName, opening: Date(timeIntervalSince1970: 1_496_991_600))
        let posting = Posting(account: account, amount: Amount(number: Decimal(10), commodity: commodity), transaction: transaction)
        transaction.postings.append(posting)
        let ledger = Ledger()

        // Empty ledger
        XCTAssertEqual(String(describing: ledger), "")

        // Ledger with commodity only
        try! ledger.add(commodity)
        XCTAssertEqual(String(describing: ledger), String(describing: commodity))

        // Ledger with account opening and commodity
        try! ledger.add(account)
        XCTAssertEqual(String(describing: ledger), "\(String(describing: commodity))\n\(String(describing: ledger.accounts.first { $0.name == accountName }!))")

        // Ledger with transactions, account opening and commodity
        _ = ledger.add(transaction)
        XCTAssertEqual(String(describing: ledger),
                       "\(String(describing: commodity))\n\(String(describing: ledger.accounts.first { $0.name == accountName }!))\n\(String(describing: transaction))")

        // Ledger with transaction, account opening as well as closing and commodity
        ledger.accounts.first { $0.name == accountName }!.closing = Date(timeIntervalSince1970: 1_497_078_000)
        XCTAssertEqual(String(describing: ledger),
                       "\(String(describing: commodity))\n\(String(describing: ledger.accounts.first { $0.name == accountName }!))\n\(String(describing: transaction))")

        // ledger with only account opening
        let ledger2 = Ledger()
        let account2 = Account(name: accountName, opening: Date(timeIntervalSince1970: 1_496_991_600))
        try! ledger2.add(account2)
        XCTAssertEqual(String(describing: ledger2), String(describing: ledger2.accounts.first!))
    }

    func testDescriptionOptions() {
        let ledger = Ledger()
        let option1 = Option(name: "a", value: "b")
        ledger.option.append(option1)
        XCTAssertEqual(String(describing: ledger), String(describing: option1))
        let option2 = Option(name: "z", value: "y")
        ledger.option.append(option2)
        XCTAssert(String(describing: ledger) == "\(String(describing: option1))\n\(String(describing: option2))")
        ledger.plugins.append("p") // Test new line after options
        XCTAssert(String(describing: ledger) == "\(String(describing: option1))\n\(String(describing: option2))\nplugin \"p\"")
    }

    func testDescriptionPlugins() {
        let ledger = Ledger()
        ledger.plugins.append("p")
        XCTAssertEqual(String(describing: ledger), "plugin \"p\"")
        ledger.plugins.append("p1")
        XCTAssert(String(describing: ledger) == "plugin \"p\"\nplugin \"p1\"")
        let custom = Custom(date: Date(timeIntervalSince1970: 1_497_078_000), name: "a", values: ["b"])
        ledger.custom.append(custom) // Test new line after plugins
        XCTAssert(String(describing: ledger) == "plugin \"p\"\nplugin \"p1\"\n\(String(describing: custom))")
    }

    func testDescriptionCustoms() {
        let ledger = Ledger()
        let custom1 = Custom(date: Date(timeIntervalSince1970: 1_497_078_000), name: "a", values: ["b"])
        let custom2 = Custom(date: Date(timeIntervalSince1970: 1_496_991_600), name: "c", values: ["d", "e"])
        ledger.custom.append(custom1)
        XCTAssertEqual(String(describing: ledger), String(describing: custom1))
        ledger.custom.append(custom2)
        XCTAssert(String(describing: ledger) == "\(String(describing: custom1))\n\(String(describing: custom2))")
        let event = Event(date: Date(timeIntervalSince1970: 1_497_078_000), name: "e", value: "e1")
        ledger.events.append(event) // Test new line after customs
        XCTAssert(String(describing: ledger) == "\(String(describing: custom1))\n\(String(describing: custom2))\n\(String(describing: event))")
    }

    func testDescriptionEvents() {
        let ledger = Ledger()
        let event1 = Event(date: Date(timeIntervalSince1970: 1_497_078_000), name: "e", value: "e1")
        let event2 = Event(date: Date(timeIntervalSince1970: 1_496_991_600), name: "c", value: "d")
        ledger.events.append(event1)
        XCTAssertEqual(String(describing: ledger), String(describing: event1))
        ledger.events.append(event2)
        XCTAssert(String(describing: ledger) == "\(String(describing: event1))\n\(String(describing: event2))")
        let commodity = Commodity(symbol: "EUR", opening: Date(timeIntervalSince1970: 1_496_991_600))
        try! ledger.add(commodity) // Test new line after events
        XCTAssert(String(describing: ledger) == "\(String(describing: event1))\n\(String(describing: event2))\n\(String(describing: commodity))")
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

        let commodity = Commodity(symbol: "Name1")
        let account = try! Account(name: AccountName("Assets:Cash"))
        let amount1 = Amount(number: 1, commodity: commodity, decimalDigits: 1)
        let amount2 = Amount(number: 1, commodity: commodity, decimalDigits: 2)

        // same meta data but different posting
        let transactionMetaData = TransactionMetaData(date: Date(), payee: name, narration: name, flag: Flag.complete, tags: [])
        let transaction1 = Transaction(metaData: transactionMetaData)
        let transaction2 = Transaction(metaData: transactionMetaData)
        let posting1 = Posting(account: account, amount: amount1, transaction: transaction1)
        transaction1.postings.append(posting1)
        let posting2 = Posting(account: account, amount: amount2, transaction: transaction1)
        transaction2.postings.append(posting2)

        _ = ledger1.add(transaction1)
        XCTAssertNotEqual(ledger1, ledger2)
        _ = ledger2.add(transaction2)
        XCTAssertNotEqual(ledger1, ledger2)
        _ = ledger1.add(transaction2)
        XCTAssertNotEqual(ledger1, ledger2)
        _ = ledger2.add(transaction1)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualCommodities() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        let commodity1 = Commodity(symbol: "Name1")
        let commodity2 = Commodity(symbol: "Name2")

        try! ledger1.add(commodity1)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger2.add(commodity2)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger1.add(commodity2)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger2.add(commodity1)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualAccounts() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        let account1 = try! Account(name: AccountName("Assets:Cash"))
        let account2 = try! Account(name: AccountName("Assets:Cash1"))

        try! ledger1.add(account1)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger2.add(account2)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger1.add(account2)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger2.add(account1)
        XCTAssertEqual(ledger1, ledger2)
    }

    func testEqualPrices() {
        let ledger1 = Ledger()
        let ledger2 = Ledger()

        let commodity1 = Commodity(symbol: "Name1")
        let commodity2 = Commodity(symbol: "Name2")
        let amount1 = Amount(number: 1, commodity: commodity1, decimalDigits: 1)
        let amount2 = Amount(number: 1, commodity: commodity1, decimalDigits: 2)
        let price1 = try! Price(date: Date(), commodity: commodity2, amount: amount1)
        let price2 = try! Price(date: Date(), commodity: commodity2, amount: amount2)

        try! ledger1.add(price1)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger2.add(price2)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger1.add(price2)
        XCTAssertNotEqual(ledger1, ledger2)
        try! ledger2.add(price1)
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

}
