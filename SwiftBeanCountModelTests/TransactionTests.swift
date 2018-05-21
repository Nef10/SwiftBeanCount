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

    var transaction1WithoutPosting: Transaction?
    var transaction2WithoutPosting: Transaction?
    var transaction1WithPosting1: Transaction?
    var transaction3WithPosting1: Transaction?
    var transaction1WithPosting1And2: Transaction?
    var transaction2WithPosting1And2: Transaction?
    var account1: Account?
    var account2: Account?
    var date: Date?

    override func setUp() {
        super.setUp()
        date = Date(timeIntervalSince1970: 1_496_905_200)
        account1 = try! Account(name: "Assets:Cash")
        account2 = try! Account(name: "Assets:Checking")
        let transactionMetaData1 = TransactionMetaData(date: date!, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transactionMetaData2 = TransactionMetaData(date: date!, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transactionMetaData3 = TransactionMetaData(date: date!, payee: "Payee", narration: "Narration", flag: Flag.incomplete, tags: [])

        let amount1 = Amount(number: Decimal(10), commodity: Commodity(symbol: "EUR"))
        let amount2 = Amount(number: Decimal(-10), commodity: Commodity(symbol: "EUR"))

        transaction1WithoutPosting = Transaction(metaData: transactionMetaData1)

        transaction2WithoutPosting = Transaction(metaData: transactionMetaData2)

        transaction1WithPosting1 = Transaction(metaData: transactionMetaData1)
        let transaction1Posting1 = Posting(account: account1!, amount: amount1, transaction: transaction1WithPosting1!)
        transaction1WithPosting1?.postings.append(transaction1Posting1)

        transaction3WithPosting1 = Transaction(metaData: transactionMetaData3)
        let transaction3Posting1 = Posting(account: account2!, amount: amount1, transaction: transaction3WithPosting1!)
        transaction3WithPosting1?.postings.append(transaction3Posting1)

        transaction1WithPosting1And2 = Transaction(metaData: transactionMetaData1)
        let transaction1WithPosting1And2Posting1 = Posting(account: account1!, amount: amount1, transaction: transaction1WithPosting1And2!)
        let transaction1WithPosting1And2Posting2 = Posting(account: account2!, amount: amount2, transaction: transaction1WithPosting1And2!)
        transaction1WithPosting1And2?.postings.append(transaction1WithPosting1And2Posting1)
        transaction1WithPosting1And2?.postings.append(transaction1WithPosting1And2Posting2)

        transaction2WithPosting1And2 = Transaction(metaData: transactionMetaData1)
        let transaction2WithPosting1And2Posting1 = Posting(account: account1!, amount: amount1, transaction: transaction2WithPosting1And2!)
        let transaction2WithPosting1And2Posting2 = Posting(account: account2!, amount: amount2, transaction: transaction2WithPosting1And2!)
        transaction2WithPosting1And2?.postings.append(transaction2WithPosting1And2Posting1)
        transaction2WithPosting1And2?.postings.append(transaction2WithPosting1And2Posting2)

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
    }

    func testEqualWithPostings() {
        XCTAssertEqual(transaction1WithPosting1And2, transaction2WithPosting1And2)
    }

    func testEqualRespectsPostings() {
        XCTAssertNotEqual(transaction1WithPosting1, transaction1WithPosting1And2)
    }

    func testEqualRespectsTransactionMetaData() {
        XCTAssertNotEqual(transaction1WithPosting1, transaction3WithPosting1)
    }

    func testIsValid() {
        account1!.opening = date
        account2!.opening = date
        guard case .valid = transaction2WithPosting1And2!.validate() else {
            XCTFail("\(transaction2WithPosting1And2!) is not valid")
            return
        }
    }

    func testIsValidWithoutPosting() {
        if case .invalid(let error) = transaction1WithoutPosting!.validate() {
            XCTAssertEqual(error, "2017-06-08 * \"Payee\" \"Narration\" has no postings")
        } else {
            XCTFail("\(transaction1WithoutPosting!) is valid")
        }
    }

    func testIsValidInvalidPosting() {
        // Accounts are not opened
        if case .invalid(let error) = transaction1WithPosting1And2!.validate() {
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
        if case .invalid(let error) = transaction1WithPosting1!.validate() {
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

        account1!.opening = date
        account2!.opening = date
        let transactionMetaData = TransactionMetaData(date: date!, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transaction = Transaction(metaData: transactionMetaData)
        let amount1 = Amount(number: Decimal(-1), commodity: Commodity(symbol: "EUR"), decimalDigits: 0)
        let amount2 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        // 0.101
        let price = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -3, significand: Decimal(101)), commodity: Commodity(symbol: "EUR"), decimalDigits: 3)
        let posting1 = Posting(account: account1!, amount: amount1, transaction: transaction)
        let posting2 = Posting(account: account2!, amount: amount2, transaction: transaction, price: price)
        transaction.postings.append(posting1)
        transaction.postings.append(posting2)

        // 10 * 0.101  = 1.01
        // |1 - 1.01| = 0.01
        // -1 EUR has 0 decimal digits -> tolerance is 0 !
        // (Percision of price is irrelevant, percision of CAD is not used because no posting in CAD)
        // 0.01 > 0 -> is invalid
        if case .invalid(let error) = transaction.validate() {
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

        account1!.opening = date
        account2!.opening = date
        let transactionMetaData = TransactionMetaData(date: date!, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transaction = Transaction(metaData: transactionMetaData)
        // -8.52
        let amount1 = Amount(number: Decimal(sign: FloatingPointSign.minus, exponent: -2, significand: Decimal(852)), commodity: Commodity(symbol: "EUR"), decimalDigits: 2)
        let amount2 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        // 0.85251
        let price = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -5, significand: Decimal(85_251)), commodity: Commodity(symbol: "EUR"), decimalDigits: 5)
        let posting1 = Posting(account: account1!, amount: amount1, transaction: transaction)
        let posting2 = Posting(account: account2!, amount: amount2, transaction: transaction, price: price)
        transaction.postings.append(posting1)
        transaction.postings.append(posting2)

        // 10 * 0.85251  = 8.5251
        // |8.52 - 8.5251| = 0.0051
        // -8.52 EUR has 2 decimal digits -> tolerance is 0.005
        // (Percision of price is irrelevant, percision of CAD is not used because no posting in CAD)
        // 0.0051 > 0.005 -> is invalid
        if case .invalid(let error) = transaction.validate() {
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

        account1!.opening = date
        let transactionMetaData = TransactionMetaData(date: date!, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transaction = Transaction(metaData: transactionMetaData)
        let amount1 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        // 0.85251
        let price = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -5, significand: Decimal(85_251)), commodity: Commodity(symbol: "EUR"), decimalDigits: 5)
        let posting1 = Posting(account: account1!, amount: amount1, transaction: transaction, price: price)
        transaction.postings.append(posting1)

        if case .invalid(let error) = transaction.validate() {
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

        account1!.opening = date
        account2!.opening = date
        let transactionMetaData = TransactionMetaData(date: date!, payee: "Payee", narration: "Narration", flag: Flag.complete, tags: [])
        let transaction = Transaction(metaData: transactionMetaData)
        let amount1 = Amount(number: Decimal(sign: FloatingPointSign.minus, exponent: -2, significand: Decimal(852)), commodity: Commodity(symbol: "EUR"), decimalDigits: 2)
        let amount2 = Amount(number: Decimal(10.000_00), commodity: Commodity(symbol: "CAD"), decimalDigits: 5)
        let price = Amount(number: Decimal(sign: FloatingPointSign.plus, exponent: -5, significand: Decimal(85_250)), commodity: Commodity(symbol: "EUR"), decimalDigits: 5)
        let posting1 = Posting(account: account1!, amount: amount1, transaction: transaction)
        let posting2 = Posting(account: account2!, amount: amount2, transaction: transaction, price: price)
        transaction.postings.append(posting1)
        transaction.postings.append(posting2)

        // 10 * 0.8525  = 8.525
        // |8.52 - 8.525| = 0.005
        // -8.52 EUR has 2 decimal digits -> tolerance is 0.005
        // (Percision of price is irrelevant, percision of CAD is not used because no posting in CAD)
        // 0.005 <= 0.005 -> is valid
        guard case .valid = transaction.validate() else {
            XCTFail("\(transaction) is not valid")
            return
        }
    }

}
