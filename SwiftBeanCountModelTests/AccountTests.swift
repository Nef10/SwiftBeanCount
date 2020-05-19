// swiftlint:disable file_length
//
//  AccountTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-11.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

//swiftlint:disable:next type_body_length
class AccountTests: XCTestCase {

    let date20170608 = Date(timeIntervalSince1970: 1_496_905_200)
    let date20170609 = Date(timeIntervalSince1970: 1_496_991_600)
    let date20170610 = Date(timeIntervalSince1970: 1_497_078_000)

    let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR"))
    var accountName, accountNameSpecial: AccountName!
    let invalidNames = ["Assets", "Liabilities", "Income", "Expenses", "Equity", "Assets:", "Assets:Test:", "Assets:Test:", "Assets:Test::Test", "💰", ""]
    let validNames = ["Assets:Cash", "Assets:Cash:Test:Test:A", "Assets:Cash:💰", "Assets:Cash:Ca💰h:Test:💰", "Liabilities:Test", "Income:Test", "Expenses:Test", "Equity:Test"]

    override func setUp() {
        super.setUp()
        accountName = try! AccountName("Assets:Cash")
        accountNameSpecial = try! AccountName("Assets:💰")
    }

    func testBookingMethod() {
        let defaultAccount = Account(name: accountName)
        XCTAssertEqual(defaultAccount.bookingMethod, .strict)

        let fifoAccount = Account(name: accountName, bookingMethod: .fifo)
        XCTAssertEqual(fifoAccount.bookingMethod, .fifo)

        let lifoAccount = Account(name: accountName, bookingMethod: .lifo)
        XCTAssertEqual(lifoAccount.bookingMethod, .lifo)
    }

    func testDescription() {
        var accout = Account(name: accountName)
        XCTAssertEqual(String(describing: accout), "")
        accout = Account(name: accountName, opening: date20170608)
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountName!)")
        let symbol = "EUR"
        accout = Account(name: accountName, commodity: Commodity(symbol: symbol), opening: date20170608)
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountName!) \(symbol)")
        accout.closing = date20170609
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountName!) \(symbol)\n2017-06-09 close \(accountName!)")
        accout = Account(name: accountName, commodity: Commodity(symbol: symbol), opening: date20170608, metaData: ["A": "B"])
        accout.closing = date20170609
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountName!) \(symbol)\n  A: \"B\"\n2017-06-09 close \(accountName!)")
    }

    func testDescriptionBookingMethod() {
        for bookingMethod in [BookingMethod.fifo, BookingMethod.lifo] {
            var accout = Account(name: accountName, bookingMethod: bookingMethod)
            XCTAssertEqual(String(describing: accout), "")
            accout = Account(name: accountName, bookingMethod: bookingMethod, opening: date20170608)
            XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountName!) \"\(bookingMethod)\"")
            let symbol = "EUR"
            accout = Account(name: accountName, bookingMethod: bookingMethod, commodity: Commodity(symbol: symbol), opening: date20170608)
            XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountName!) \(symbol) \"\(bookingMethod)\"")
            accout.closing = date20170609
            XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountName!) \(symbol) \"\(bookingMethod)\"\n2017-06-09 close \(accountName!)")
        }
    }

    func testDescriptionSpecialCharacters() {
        var accout = Account(name: accountNameSpecial)
        XCTAssertEqual(String(describing: accout), "")
        accout = Account(name: accountNameSpecial, opening: date20170608)
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountNameSpecial!)")
        let symbol = "💵"
        accout = Account(name: accountNameSpecial, commodity: Commodity(symbol: symbol), opening: date20170608)
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountNameSpecial!) \(symbol)")
        accout.closing = date20170609
        XCTAssertEqual(String(describing: accout), "2017-06-08 open \(accountNameSpecial!) \(symbol)\n2017-06-09 close \(accountNameSpecial!)")
    }

    func testIsPostingValid_NotOpenPast() {
        let account = Account(name: accountName)
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(accountName: accountName, amount: Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR")))
        transaction.add(posting)
        if case .invalid(let error) = account.validate(transaction.postings[0]) {
            XCTAssertEqual(error, """
                2017-06-08 * "Payee" "Narration"
                  Assets:Cash 1 EUR was posted while the accout Assets:Cash was closed
                """)
        } else {
            XCTFail("\(posting) is valid on \(account)")
        }
    }

    func testIsPostingValid_NoOpenPresent() {
        let account = Account(name: accountName)
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(accountName: accountName, amount: Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR")))
        transaction.add(posting)
        if case .invalid(let error) = account.validate(transaction.postings[0]) {
            XCTAssertEqual(error, """
                2017-06-08 * "Payee" "Narration"
                  Assets:Cash 1 EUR was posted while the accout Assets:Cash was closed
                """)
        } else {
            XCTFail("\(posting) is valid on \(account)")
        }
    }

    func testIsPostingValid_BeforeOpening() {
        let account = Account(name: accountName, opening: date20170609)
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(accountName: accountName, amount: Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR")))
        transaction.add(posting)
        if case .invalid(let error) = account.validate(transaction.postings[0]) {
            XCTAssertEqual(error, """
                2017-06-08 * "Payee" "Narration"
                  Assets:Cash 1 EUR was posted while the accout Assets:Cash was closed
                """)
        } else {
            XCTFail("\(posting) is valid on \(account)")
        }
    }

    func testIsPostingValid_AfterOpening() {
        let account = Account(name: accountName, opening: date20170609)
        let transaction1 = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting1 = Posting(accountName: accountName, amount: amount)
        transaction1.add(posting1)
        guard case .valid = account.validate(transaction1.postings[0]) else {
            XCTFail("\(posting1) is not valid on \(account)")
            return
        }

        let transaction2 = Transaction(metaData: TransactionMetaData(date: Date(), payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting2 = Posting(accountName: accountName, amount: amount)
        transaction2.add(posting2)
        guard case .valid = account.validate(transaction2.postings[0]) else {
            XCTFail("\(posting2) is not valid on \(account)")
            return
        }
    }

    func testIsPostingValid_BeforeClosing() {
        let account = Account(name: accountName, opening: date20170609)
        account.closing = date20170609
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(accountName: accountName, amount: amount)
        transaction.add(posting)
        guard case .valid = account.validate(transaction.postings[0]) else {
            XCTFail("\(posting) is not valid on \(account)")
            return
        }
    }

    func testIsPostingValid_AfterClosing() {
        let account = Account(name: accountName, opening: date20170609)
        account.closing = date20170609
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170610, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(accountName: accountName, amount: amount)
        transaction.add(posting)
        if case .invalid(let error) = account.validate(transaction.postings[0]) {
            XCTAssertEqual(error, """
                2017-06-10 * "Payee" "Narration"
                  Assets:Cash 1 EUR was posted while the accout Assets:Cash was closed
                """)
        } else {
            XCTFail("\(posting) is valid on \(account)")
        }
    }

    func testIsPostingValid_WithoutCommodity() {
        let account = Account(name: accountName, opening: date20170608)
        let transaction1 = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting1 = Posting(accountName: accountName, amount: amount)
        transaction1.add(posting1)
        guard case .valid = account.validate(transaction1.postings[0]) else {
            XCTFail("\(posting1) is not valid on \(account)")
            return
        }

        let transaction2 = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting2 = Posting(accountName: accountName, amount: amount)
        transaction2.add(posting2)
        guard case .valid = account.validate(transaction2.postings[0]) else {
            XCTFail("\(posting2) is not valid on \(account)")
            return
        }
    }

    func testIsPostingValid_CorrectCommodity() {
        let account = Account(name: accountName, commodity: amount.commodity, opening: date20170608)
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(accountName: accountName, amount: amount)
        transaction.add(posting)
        guard case .valid = account.validate(transaction.postings[0]) else {
            XCTFail("\(posting) is not valid on \(account)")
            return
        }
    }

    func testIsPostingValid_WrongCommodity() {
        let account = Account(name: accountName, commodity: Commodity(symbol: "\(amount.commodity.symbol)1"), opening: date20170608)
        let transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))
        let posting = Posting(accountName: accountName, amount: amount)
        transaction.add(posting)
        if case .invalid(let error) = account.validate(transaction.postings[0]) {
            XCTAssertEqual(error, """
                2017-06-09 * "Payee" "Narration"
                  Assets:Cash 1 EUR uses a wrong commodiy for account Assets:Cash - Only EUR1 is allowed
                """)
        } else {
            XCTFail("\(posting) is valid on \(account)")
        }
    }

    func testIsValid() {
        var account = Account(name: accountName)

        // neither closing nor opening
        guard case .valid = account.validate() else {
            XCTFail("\(account) is not valid")
            return
        }

        // only opening
         account = Account(name: accountName, opening: date20170608)
        guard case .valid = account.validate() else {
            XCTFail("\(account) is not valid")
            return
        }

        // Closing == opening
        account.closing = date20170608
        guard case .valid = account.validate() else {
            XCTFail("\(account) is not valid")
            return
        }

        // Closing > opening
        account.closing = date20170609
        guard case .valid = account.validate() else {
            XCTFail("\(account) is not valid")
            return
        }

        // Closing < opening
        account = Account(name: accountName, opening: date20170609)
        account.closing = date20170608
        if case .invalid(let error) = account.validate() {
            XCTAssertEqual(error, "Account Assets:Cash was closed on 2017-06-08 before it was opened on 2017-06-09")
        } else {
            XCTFail("\(account) is valid")
        }

        // only closing
        account = Account(name: accountName)
        account.closing = date20170608
        if case .invalid(let error) = account.validate() {
            XCTAssertEqual(error, "Account Assets:Cash has a closing date but no opening")
        } else {
            XCTFail("\(account) is valid")
        }
    }

    func testValidateBalance() {
        let ledger = Ledger()
        let commodity = Commodity(symbol: "CAD")
        let account = Account(name: accountName, commodity: commodity)
        try! ledger.add(account)

        account.balances.append(Balance(date: date20170608, account: account, amount: Amount(number: 0, commodity: commodity)))
        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }

        account.balances.append(Balance(date: date20170609, account: account, amount: Amount(number: 1, commodity: commodity)))
        if case .invalid(let error) = account.validateBalance(in: ledger) {
            XCTAssertEqual(error, "Balance failed for 2017-06-09 balance Assets:Cash 1 CAD - 1 CAD too much (0 tolerance)")
        } else {
            XCTFail("\(account) is valid")
        }

        var transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "", narration: "", flag: .complete, tags: []))
        var posting = Posting(accountName: accountName, amount: Amount(number: 1, commodity: commodity))
        transaction.add(posting)
        _ = ledger.add(transaction)

        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }

        transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "", narration: "", flag: .complete, tags: []))
        posting = Posting(accountName: accountName, amount: Amount(number: 10, commodity: commodity))
        transaction.add(posting)
        _ = ledger.add(transaction)
        account.balances.append(Balance(date: date20170610, account: account, amount: Amount(number: 11, commodity: commodity)))
        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }
    }

    func testValidateBalanceEmpty() {
        let ledger = Ledger()
        let commodity = Commodity(symbol: "CAD")
        let account = Account(name: accountName, commodity: commodity)
        try! ledger.add(account)

        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }

        let transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "", narration: "", flag: .complete, tags: []))
        let posting = Posting(accountName: accountName, amount: Amount(number: 1, commodity: commodity))
        transaction.add(posting)
        _ = ledger.add(transaction)

        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }
    }

    func testValidateBalanceDifferentCommodity() {
        let ledger = Ledger()
        let commodity1 = Commodity(symbol: "CAD")
        let commodity2 = Commodity(symbol: "EUR")
        let account = Account(name: accountName)
        try! ledger.add(account)

        account.balances.append(Balance(date: date20170608, account: account, amount: Amount(number: 0, commodity: commodity2)))

        account.balances.append(Balance(date: date20170609, account: account, amount: Amount(number: 1, commodity: commodity1)))
        if case .invalid(let error) = account.validateBalance(in: ledger) {
            XCTAssertEqual(error, "Balance failed for 2017-06-09 balance Assets:Cash 1 CAD - 1 CAD too much (0 tolerance)")
        } else {
            XCTFail("\(account) is valid")
        }

        var transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName, amount: Amount(number: 1, commodity: commodity1)))
        _ = ledger.add(transaction)

        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }

        // Ignores other commodity without currency
        transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName, amount: Amount(number: 1, commodity: Commodity(symbol: "USD"))))
        _ = ledger.add(transaction)
        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }

        account.balances.append(Balance(date: date20170609, account: account, amount: Amount(number: 1, commodity: commodity2)))
        transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName, amount: Amount(number: 1, commodity: commodity2)))
        _ = ledger.add(transaction)
        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }
    }

    func testValidateBalanceTolerance() {
        let ledger = Ledger()
        let commodity = Commodity(symbol: "CAD")
        let account = Account(name: accountName, commodity: commodity)
        try! ledger.add(account)

        var transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName, amount: Amount(number: 1.1, commodity: commodity, decimalDigits: 1)))
        _ = ledger.add(transaction)

        account.balances = [Balance(date: date20170609, account: account, amount: Amount(number: 1.15, commodity: commodity, decimalDigits: 2))]
        if case .invalid(let error) = account.validateBalance(in: ledger) {
            XCTAssertEqual(error, "Balance failed for 2017-06-09 balance Assets:Cash 1.15 CAD - 0.05 CAD too much (0.005 tolerance)")
        } else {
            XCTFail("\(account) is valid")
        }

        account.balances = [Balance(date: date20170609, account: account, amount: Amount(number: 1.15, commodity: commodity, decimalDigits: 1))]
        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }

        transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName, amount: Amount(number: 0.055, commodity: commodity, decimalDigits: 3)))
        _ = ledger.add(transaction)

        account.balances = [Balance(date: date20170609, account: account, amount: Amount(number: 1.16, commodity: commodity, decimalDigits: 2))]
        if case .invalid(let error) = account.validateBalance(in: ledger) {
            XCTAssertEqual(error, "Balance failed for 2017-06-09 balance Assets:Cash 1.16 CAD - 0.005 CAD too much (0.0005 tolerance)")
        } else {
            XCTFail("\(account) is valid")
        }

        account.balances = [Balance(date: date20170609, account: account, amount: Amount(number: 1.155_5, commodity: commodity, decimalDigits: 3))]
        guard case .valid = account.validateBalance(in: ledger) else {
            XCTFail("\(account) is not valid")
            print(account.validateBalance(in: ledger))
            return
        }
    }

    func testValidateInventoryEmpty() {
        let ledger = Ledger()
        let commodity = Commodity(symbol: "CAD")
        let account = Account(name: accountName, commodity: commodity)
        try! ledger.add(account)

        guard case .valid = account.validateInventory(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }
    }

    func testValidateInventory() {
        let ledger = Ledger()
        let commodity = Commodity(symbol: "CAD")
        let account = Account(name: accountName, commodity: commodity)
        try! ledger.add(account)

        var transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName,
                                amount: Amount(number: 1.1, commodity: commodity, decimalDigits: 1),
                                price: nil,
                                cost: try! Cost(amount: Amount(number: 5, commodity: commodity), date: nil, label: "1")))
        _ = ledger.add(transaction)

        transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName,
                                amount: Amount(number: 1.1, commodity: commodity, decimalDigits: 1),
                                price: nil,
                                cost: try! Cost(amount: Amount(number: 5, commodity: commodity), date: nil, label: nil)))
        _ = ledger.add(transaction)

        transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName,
                                amount: Amount(number: -1, commodity: commodity, decimalDigits: 0),
                                price: nil,
                                cost: try! Cost(amount: Amount(number: 5, commodity: commodity), date: nil, label: "1")))
        _ = ledger.add(transaction)

        guard case .valid = account.validateInventory(in: ledger) else {
            XCTFail("\(account) is not valid")
            return
        }
    }

    func testValidateInvalidInventory() {
        let ledger = Ledger()
        let commodity = Commodity(symbol: "CAD")
        let account = Account(name: accountName, commodity: commodity)
        let amount = Amount(number: 1.1, commodity: commodity, decimalDigits: 1)
        let cost = try! Cost(amount: Amount(number: 5, commodity: commodity), date: nil, label: "1")
        try! ledger.add(account)

        var transaction = Transaction(metaData: TransactionMetaData(date: date20170608, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName, amount: amount, price: nil, cost: cost))
        _ = ledger.add(transaction)

        transaction = Transaction(metaData: TransactionMetaData(date: date20170609, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName, amount: amount, price: nil, cost: cost))
        _ = ledger.add(transaction)

        transaction = Transaction(metaData: TransactionMetaData(date: date20170610, payee: "", narration: "", flag: .complete, tags: []))
        transaction.add(Posting(accountName: accountName,
                                amount: Amount(number: -1.0, commodity: commodity, decimalDigits: 0),
                                price: nil,
                                cost: try! Cost(amount: Amount(number: 5, commodity: commodity), date: nil, label: nil)))
        _ = ledger.add(transaction)

        if case .invalid(let error) = account.validateInventory(in: ledger) {
            XCTAssertEqual(error, """
                Ambigious Booking: -1 CAD {5 CAD}, matches: 1.1 CAD {2017-06-08, 5 CAD, "1"}
                1.1 CAD {2017-06-09, 5 CAD, "1"}, inventory: 1.1 CAD {2017-06-08, 5 CAD, "1"}
                1.1 CAD {2017-06-09, 5 CAD, "1"}
                """)
        } else {
            XCTFail("\(account) is valid")
        }
    }

    func testEqualName() {
        let account1 = Account(name: accountName)
        let account2 = Account(name: accountNameSpecial)
        XCTAssertNotEqual(account1, account2)
    }

    func testEqualProperties() {
        let commodity1 = Commodity(symbol: "EUR")
        let commodity2 = Commodity(symbol: "💵")
        let date1 = date20170608
        let date2 = date20170609

        var account1 = Account(name: accountName)
        var account2 = Account(name: accountName)

        // equal
        XCTAssertEqual(account1, account2)

        account1 = Account(name: accountName, commodity: commodity1, opening: date1)
        account2 = Account(name: accountName, commodity: commodity1, opening: date1)
        account1.closing = date1
        account2.closing = date1

        // equal
        XCTAssertEqual(account1, account2)
        // different meta data
        account1 = Account(name: accountName, commodity: commodity1, opening: date1, metaData: ["A": "B"])
        account2 = Account(name: accountName, commodity: commodity1, opening: date1, metaData: ["A": "C"])
        XCTAssertNotEqual(account1, account2)
        // same meta data
        account2 = Account(name: accountName, commodity: commodity1, opening: date1, metaData: ["A": "B"])
        XCTAssertEqual(account1, account2)
        // different commodity
        account1 = Account(name: accountName, commodity: commodity1)
        account2 = Account(name: accountName, commodity: commodity2)
        XCTAssertNotEqual(account1, account2)
        // different opening
        account1 = Account(name: accountName, commodity: commodity1, opening: date1)
        account2 = Account(name: accountName, commodity: commodity2, opening: date2)
        XCTAssertNotEqual(account1, account2)
        // different closing
        account2.closing = date2
        XCTAssertNotEqual(account1, account2)
        account1.closing = date1
        XCTAssertNotEqual(account1, account2)
    }

}

extension AccountTests { // AccountName Tests

    func testInitNames() {
        for name in validNames {
            XCTAssertNoThrow(try AccountName(name))
        }
        for name in invalidNames {
            XCTAssertThrowsError(try AccountName(name)) {
                XCTAssertEqual($0.localizedDescription, "Invalid Account name: \(name)")
            }
        }
    }

    func testIsAccountNameVaild() {
        for name in validNames {
            XCTAssert(AccountName.isNameValid(name))
        }
        for name in invalidNames {
            XCTAssertFalse(AccountName.isNameValid(name))
        }
    }

    func testNameItem() {
        XCTAssertEqual(try! AccountName("Assets:Cash").nameItem, "Cash")
        XCTAssertEqual(try! AccountName("Assets:A:B:C:D:E:Cash").nameItem, "Cash")
        XCTAssertEqual(try! AccountName("Assets:💰").nameItem, "💰")
    }

    func testAccountType() {
        XCTAssertEqual(try! AccountName("Assets:Test").accountType, AccountType.asset)
        XCTAssertEqual(try! AccountName("Liabilities:Test").accountType, AccountType.liability)
        XCTAssertEqual(try! AccountName("Income:Test").accountType, AccountType.income)
        XCTAssertEqual(try! AccountName("Expenses:Test").accountType, AccountType.expense)
        XCTAssertEqual(try! AccountName("Equity:Test").accountType, AccountType.equity)
    }

    func testAccountNameEqual() {
        let name1 = try! AccountName("Assets:Test")
        let name2 = try! AccountName("Assets:Test")
        let name3 = try! AccountName("Assets:Test:Test")
        XCTAssertEqual(name1, name2)
        XCTAssertNotEqual(name1, name3)
    }

}
