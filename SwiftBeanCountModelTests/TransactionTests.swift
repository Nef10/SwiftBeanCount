//
//  TransactionTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-18.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class TransactionTests: XCTestCase {

    var transaction1WithoutPosting: Transaction!
    var transaction2WithoutPosting: Transaction!
    var transaction1WithPosting1: Transaction!
    var transaction3WithPosting1: Transaction!
    var transaction1WithPosting1And2: Transaction!
    var transaction2WithPosting1And2: Transaction!
    let accountName1 = try! AccountName("Assets:Cash")
    let accountName2 = try! AccountName("Assets:Checking")
    var account1: Account?
    var account2: Account?
    var date = TestUtils.date20170608
    let ledger = Ledger()

    override func setUp() {
        super.setUp()
        account1 = Account(name: accountName1, opening: date)
        account2 = Account(name: accountName2, opening: date)
        try! ledger.add(account1!)
        try! ledger.add(account2!)
        let transactionMetaData1 = TransactionMetaData(date: date, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transactionMetaData2 = TransactionMetaData(date: date, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transactionMetaData3 = TransactionMetaData(date: date, payee: "Payee", narration: "Narration", flag: Flag.incomplete, tags: [])

        let amount1 = Amount(number: Decimal(10), commodity: Commodity(symbol: "EUR"))
        let amount2 = Amount(number: Decimal(-10), commodity: Commodity(symbol: "EUR"))

        transaction1WithoutPosting = Transaction(metaData: transactionMetaData1, postings: [])

        transaction2WithoutPosting = Transaction(metaData: transactionMetaData2, postings: [])

        let transaction1Posting1 = Posting(accountName: accountName1, amount: amount1)
        transaction1WithPosting1 = Transaction(metaData: transactionMetaData1, postings: [transaction1Posting1])

        let transaction3Posting1 = Posting(accountName: accountName2, amount: amount1)
        transaction3WithPosting1 = Transaction(metaData: transactionMetaData3, postings: [transaction3Posting1])

        let transaction1WithPosting1And2Posting1 = Posting(accountName: accountName1, amount: amount1)
        let transaction1WithPosting1And2Posting2 = Posting(accountName: accountName2, amount: amount2)
        transaction1WithPosting1And2 = Transaction(metaData: transactionMetaData1, postings: [transaction1WithPosting1And2Posting1, transaction1WithPosting1And2Posting2])

        let transaction2WithPosting1And2Posting1 = Posting(accountName: accountName1, amount: amount1)
        let transaction2WithPosting1And2Posting2 = Posting(accountName: accountName2, amount: amount2)
        transaction2WithPosting1And2 = Transaction(metaData: transactionMetaData1, postings: [transaction2WithPosting1And2Posting1, transaction2WithPosting1And2Posting2])

        transaction1WithoutPosting = ledger.add(transaction1WithoutPosting)
        transaction2WithoutPosting = ledger.add(transaction2WithoutPosting)
        transaction1WithPosting1 = ledger.add(transaction1WithPosting1)
        transaction3WithPosting1 = ledger.add(transaction3WithPosting1)
        transaction1WithPosting1And2 = ledger.add(transaction1WithPosting1And2)
        transaction2WithPosting1And2 = ledger.add(transaction2WithPosting1And2)

    }

    func testDescriptionWithoutPosting() {
        XCTAssertEqual(String(describing: transaction1WithoutPosting!), String(describing: transaction1WithoutPosting!.metaData))
    }

    func testDescriptionWithPostings() {
        XCTAssertEqual(String(describing: transaction1WithPosting1And2!),
                       String(describing: transaction1WithPosting1And2!.metaData) + "\n"
                         + String(describing: transaction1WithPosting1And2!.postings[0]) + "\n"
                         + String(describing: transaction1WithPosting1And2!.postings[1]))
    }

    func testEqual() {
        XCTAssertEqual(transaction1WithoutPosting, transaction2WithoutPosting)
        XCTAssertFalse(transaction1WithoutPosting < transaction2WithoutPosting)
        XCTAssertFalse(transaction2WithoutPosting < transaction1WithoutPosting)
    }

    func testEqualWithPostings() {
        XCTAssertEqual(transaction1WithPosting1And2, transaction2WithPosting1And2)
        XCTAssertFalse(transaction1WithPosting1And2 < transaction2WithPosting1And2)
        XCTAssertFalse(transaction2WithPosting1And2 < transaction1WithPosting1And2)
    }

    func testEqualRespectsPostings() {
        XCTAssertNotEqual(transaction1WithPosting1, transaction1WithPosting1And2)
        XCTAssert(transaction1WithPosting1 < transaction1WithPosting1And2)
        XCTAssertFalse(transaction1WithPosting1And2 < transaction1WithPosting1)
    }

    func testEqualRespectsTransactionMetaData() {
        XCTAssertNotEqual(transaction1WithPosting1, transaction3WithPosting1)
        XCTAssertFalse(transaction1WithPosting1 < transaction3WithPosting1)
        XCTAssert(transaction3WithPosting1 < transaction1WithPosting1)
    }

    func testIsValid() {
        guard case .valid = transaction2WithPosting1And2!.validate(in: ledger) else {
            XCTFail("\(transaction2WithPosting1And2!) is not valid")
            return
        }
    }

    func testIsValidFromOutsideLedger() {
        let ledger = Ledger()
        guard case .invalid = transaction2WithPosting1And2!.validate(in: ledger) else {
            XCTFail("\(transaction2WithPosting1And2!) is valid")
            return
        }
    }

    func testIsValidWithoutPosting() {
        if case .invalid(let error) = transaction1WithoutPosting!.validate(in: ledger) {
            XCTAssertEqual(error, "2017-06-08 * \"Payee\" \"Narration\" has no postings")
        } else {
            XCTFail("\(transaction1WithoutPosting!) is valid")
        }
    }

    func testIsValidInvalidPosting() {
        // Accounts are not opened
        let ledger = Ledger()
        try! ledger.add(try! Account(name: AccountName("Assets:Cash")))
        try! ledger.add(try! Account(name: AccountName("Assets:Checking"), opening: date))
        let transaction = ledger.add(transaction1WithPosting1And2)
        if case .invalid(let error) = transaction.validate(in: ledger) {
            XCTAssertEqual(error, """
                2017-06-08 * "Payee" "Narration"
                  Assets:Cash 10 EUR
                  Assets:Checking -10 EUR was posted while the accout Assets:Cash was closed
                """)
        } else {
            XCTFail("\(transaction1WithPosting1And2!) is valid")
        }
    }

    func testIsValidUnbalanced() {
        if case .invalid(let error) = transaction1WithPosting1!.validate(in: ledger) {
            XCTAssertEqual(error, """
                2017-06-08 * "Payee" "Narration"
                  Assets:Cash 10 EUR is not balanced - 10 EUR too much (0 tolerance)
                """)
        } else {
            XCTFail("\(transaction1WithPosting1!) is valid")
        }
    }

    func testIsValidUnbalancedIntegerTolerance() {
        //Assets:Cash     -1  EUR
        //Assets:Checking 10.00000 CAD @ 0.101 EUR

        let transactionMetaData = TransactionMetaData(date: date, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let amount1 = Amount(number: Decimal(-1), commodity: Commodity(symbol: "EUR"), decimalDigits: 0)
        let amount2 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        // 0.101
        let price = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -3, significand: Decimal(101)), commodity: Commodity(symbol: "EUR"), decimalDigits: 3)
        let posting1 = Posting(accountName: accountName1, amount: amount1)
        let posting2 = Posting(accountName: accountName2, amount: amount2, price: price)
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])
        // 10 * 0.101  = 1.01
        // |1 - 1.01| = 0.01
        // -1 EUR has 0 decimal digits -> tolerance is 0 !
        // (Percision of price is irrelevant, percision of CAD is not used because no posting in CAD)
        // 0.01 > 0 -> is invalid
        if case .invalid(let error) = transaction.validate(in: ledger) {
            XCTAssertEqual(error, """
                2017-06-08 * "Payee" "Narration"
                  Assets:Cash -1 EUR
                  Assets:Checking 10.00000 CAD @ 0.101 EUR is not balanced - 0.01 EUR too much (0 tolerance)
                """)
        } else {
            XCTFail("\(transaction) is valid")
        }
    }

    func testIsValidUnbalancedTolerance() {
        //Assets:Cash     -8.52  EUR
        //Assets:Checking 10.00000 CAD @ 0.85251 EUR

        let transactionMetaData = TransactionMetaData(date: date, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        // -8.52
        let amount1 = Amount(number: Decimal(sign: FloatingPointSign.minus, exponent: -2, significand: Decimal(852)), commodity: Commodity(symbol: "EUR"), decimalDigits: 2)
        let amount2 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        // 0.85251
        let price = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -5, significand: Decimal(85_251)), commodity: Commodity(symbol: "EUR"), decimalDigits: 5)
        let posting1 = Posting(accountName: accountName1, amount: amount1)
        let posting2 = Posting(accountName: accountName2, amount: amount2, price: price)
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])

        // 10 * 0.85251  = 8.5251
        // |8.52 - 8.5251| = 0.0051
        // -8.52 EUR has 2 decimal digits -> tolerance is 0.005
        // (Percision of price is irrelevant, percision of CAD is not used because no posting in CAD)
        // 0.0051 > 0.005 -> is invalid
        if case .invalid(let error) = transaction.validate(in: ledger) {
            XCTAssertEqual(error, """
                2017-06-08 * "Payee" "Narration"
                  Assets:Cash -8.52 EUR
                  Assets:Checking 10.00000 CAD @ 0.85251 EUR is not balanced - 0.0051 EUR too much (0.005 tolerance)
                """)
        } else {
            XCTFail("\(transaction) is valid")
        }
    }

    func testIsValidUnusedCommodity() {
        //Assets:Checking 10.00000 CAD @ 0.85251 EUR

        let transactionMetaData = TransactionMetaData(date: date, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let amount1 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        // 0.85251
        let price = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -5, significand: Decimal(85_251)), commodity: Commodity(symbol: "EUR"), decimalDigits: 5)
        let posting1 = Posting(accountName: accountName1, amount: amount1, price: price)
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1])

        if case .invalid(let error) = transaction.validate(in: ledger) {
            XCTAssertEqual(error, """
                2017-06-08 * "Payee" "Narration"
                  Assets:Cash 10.00000 CAD @ 0.85251 EUR is not balanced - 8.5251 EUR too much (0 tolerance)
                """)
        } else {
            XCTFail("\(transaction) is valid")
        }
    }

    func testIsValidBalancedTolerance() {
        //Assets:Cash     -8.52  EUR
        //Assets:Checking 10.00000 CAD @ 0.85250 EUR

        let transactionMetaData = TransactionMetaData(date: date, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let amount1 = Amount(number: Decimal(sign: FloatingPointSign.minus, exponent: -2, significand: Decimal(852)), commodity: Commodity(symbol: "EUR"), decimalDigits: 2)
        let amount2 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        let price = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -5, significand: Decimal(85_250)), commodity: Commodity(symbol: "EUR"), decimalDigits: 5)
        let posting1 = Posting(accountName: accountName1, amount: amount1)
        let posting2 = Posting(accountName: accountName2, amount: amount2, price: price)
        var transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])
        transaction = ledger.add(transaction)

        // 10 * 0.8525  = 8.525
        // |8.52 - 8.525| = 0.005
        // -8.52 EUR has 2 decimal digits -> tolerance is 0.005
        // (Percision of price is irrelevant, percision of CAD is not used because no posting in CAD)
        // 0.005 <= 0.005 -> is valid
        guard case .valid = transaction.validate(in: ledger) else {
            XCTFail("\(transaction) is not valid")
            return
        }
    }

    func testIsValidBalancedToleranceCost() {
        //Assets:Cash     -8.52  EUR
        //Assets:Checking 10.00000 CAD { 0.85250 EUR }

        let transactionMetaData = TransactionMetaData(date: date, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let amount1 = Amount(number: Decimal(sign: FloatingPointSign.minus, exponent: -2, significand: Decimal(852)), commodity: Commodity(symbol: "EUR"), decimalDigits: 2)
        let amount2 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        let costAmount = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -5, significand: Decimal(85_250)),
                                commodity: Commodity(symbol: "EUR"),
                                decimalDigits: 5)
        let cost = try! Cost(amount: costAmount, date: date, label: nil)
        let posting1 = Posting(accountName: accountName1, amount: amount1)
        let posting2 = Posting(accountName: accountName2, amount: amount2, price: nil, cost: cost)
        var transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])
        transaction = ledger.add(transaction)

        // 10 * 0.8525  = 8.525
        // |8.52 - 8.525| = 0.005
        // -8.52 EUR has 2 decimal digits -> tolerance is 0.005
        // (Percision of price is irrelevant, percision of CAD is not used because no posting in CAD)
        // 0.005 <= 0.005 -> is valid
        guard case .valid = transaction.validate(in: ledger) else {
            XCTFail("\(transaction) is not valid")
            return
        }
    }

    func testIsValidUnbalancedToleranceCost() {
        //Assets:Cash     -8.52  EUR
        //Assets:Checking 10.00000 CAD { 0.85251 EUR }

        let transactionMetaData = TransactionMetaData(date: date, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        // -8.52
        let amount1 = Amount(number: Decimal(sign: FloatingPointSign.minus, exponent: -2, significand: Decimal(852)), commodity: Commodity(symbol: "EUR"), decimalDigits: 2)
        let amount2 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        // 0.85251
        let costAmount = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -5, significand: Decimal(85_251)),
                                commodity: Commodity(symbol: "EUR"),
                                decimalDigits: 5)
        let cost = try! Cost(amount: costAmount, date: nil, label: nil)
        let posting1 = Posting(accountName: accountName1, amount: amount1)
        let posting2 = Posting(accountName: accountName2, amount: amount2, price: nil, cost: cost)
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting1, posting2])

        // 10 * 0.85251  = 8.5251
        // |8.52 - 8.5251| = 0.0051
        // -8.52 EUR has 2 decimal digits -> tolerance is 0.005
        // (Percision of cost is irrelevant, percision of CAD is not used because no posting in CAD)
        // 0.0051 > 0.005 -> is invalid
        if case .invalid(let error) = transaction.validate(in: ledger) {
            XCTAssertEqual(error, """
                2017-06-08 * "Payee" "Narration"
                  Assets:Cash -8.52 EUR
                  Assets:Checking 10.00000 CAD {0.85251 EUR} is not balanced - 0.0051 EUR too much (0.005 tolerance)
                """)
        } else {
            XCTFail("\(transaction) is valid")
        }
    }

}
