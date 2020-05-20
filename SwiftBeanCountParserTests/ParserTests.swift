//
//  ParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class ParserTests: XCTestCase {

    enum TestFile: String {
        case minimal = "Minimal"
        case postingWithoutTransaction = "PostingWithoutTransaction"
        case transactionWithoutPosting = "TransactionWithoutPosting"
        case comments = "Comments"
        case commentsEndOfLine = "CommentsEndOfLine"
        case whitespace = "Whitespace"
        case big = "Big"
        case invalidCost = "InvalidCost"

        static let withoutError = [minimal, comments, commentsEndOfLine, whitespace, big]
    }

    let basicAccountOpeningString = "2017-06-09 open Assets:Cash"
    let accountOpeningStringCommodity = "2017-06-09 open Assets:Cash EUR"
    let basicAccountClosingString = "2017-06-09 close Assets:Cash"

    let commodityString = "2017-06-09 commodity EUR"
    let priceString = "2017-06-09 price EUR 1.50 CAD"
    let balanceString = "2017-06-09 balance Assets:Cash 0.00 CAD"
    let invalidBalanceString = "2017-06-09 balance TEST:Cash 0.00 CAD"

    func testMinimal() {
        ensureMinimal(testFile: .minimal)
    }

    func testWhitespace() {
        ensureMinimal(testFile: .whitespace)
    }

    func testPostingWithoutTransaction() {
        let ledger = ensureEmpty(testFile: .postingWithoutTransaction)
        XCTAssertEqual(ledger.errors.count, 1)
    }

    func testTransactionWithoutPosting() {
        let ledger = ensureEmpty(testFile: .transactionWithoutPosting)
        XCTAssertEqual(ledger.errors.count, 1)
        XCTAssertEqual(ledger.errors[0], "Invalid format in line 2: previous Transaction 2017-06-08 * \"Payee\" \"Narration\" without postings")
    }

    func testComments() {
        let ledger = ensureEmpty(testFile: .comments)
        XCTAssertEqual(ledger.errors.count, 0)
    }

    func testCommentsEndOfLine() {
        ensureMinimal(testFile: .commentsEndOfLine)
    }

    func testInvalidCost() {
        var errorMessage = "" // do not check for the exact error message from library, just check that the parser correctly copies it
        do {
            _ = try Cost(amount: Amount(number: Decimal(-1), commodity: Commodity(symbol: "EUR"), decimalDigits: 2), date: nil, label: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
        let parser = try! Parser(url: urlFor(testFile: TestFile.invalidCost))
        let ledger1 = parser.parse()
        XCTAssertEqual(ledger1.errors.count, 1)
        XCTAssertEqual(ledger1.errors[0], "\(errorMessage) (line 7)")
    }

    func testAccounts() {
        // open and close is ok
        var parser = Parser(string: "\(basicAccountOpeningString)\n\(basicAccountClosingString)")
        var ledger = parser.parse()
        XCTAssertTrue(ledger.errors.isEmpty)

        // only open is ok
        parser = Parser(string: "\(basicAccountOpeningString)")
        ledger = parser.parse()
        XCTAssertTrue(ledger.errors.isEmpty)

        // only close is not ok
        parser = Parser(string: "\(basicAccountClosingString)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)

        // open twice is not ok
        parser = Parser(string: "\(basicAccountOpeningString)\n\(basicAccountOpeningString)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)
        parser = Parser(string: "\(accountOpeningStringCommodity)\n\(accountOpeningStringCommodity)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)

        // close twice is not ok
        parser = Parser(string: "\(basicAccountClosingString)\n\(basicAccountClosingString)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)

        // close twice (+ normal open) is not ok
        parser = Parser(string: "\(basicAccountOpeningString)\n\(basicAccountClosingString)\n\(basicAccountClosingString)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testCommodity() {
        var parser = Parser(string: "\(commodityString)")
        var ledger = parser.parse()
        XCTAssertTrue(ledger.errors.isEmpty)

        parser = Parser(string: "\(commodityString)\n\(commodityString)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testPrice() {
        var parser = Parser(string: "\(priceString)")
        var ledger = parser.parse()
        XCTAssertTrue(ledger.errors.isEmpty)

        parser = Parser(string: "\(priceString)\n\(priceString)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testBalance() {
        var parser = Parser(string: "\(balanceString)")
        var ledger = parser.parse()
        XCTAssertTrue(ledger.errors.isEmpty)

        parser = Parser(string: "\(invalidBalanceString)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testRoundTrip() {
        do {
            for testFile in TestFile.withoutError {
                let parser1 = try Parser(url: urlFor(testFile: testFile))
                let ledger1 = parser1.parse()
                let parser2 = Parser(string: String(describing: ledger1))
                let ledger2 = parser2.parse()
                let result = ledger1 == ledger2
                XCTAssert(result)
            }
        } catch {
            XCTFail(String(describing: error))
        }
    }

    func testPerformance() {
        self.measure {
            do {
                let parser = try Parser(url: urlFor(testFile: .big))
                _ = parser.parse()
            } catch {
                XCTFail(String(describing: error))
            }
        }
    }

    //  Helper

    private func urlFor(testFile: TestFile) -> URL {
        NSURL.fileURL(withPath: Bundle(for: type(of: self)).path(forResource: testFile.rawValue, ofType: "beancount")!)
    }

    private func ensureEmpty(testFile: TestFile) -> Ledger {
        do {
            let parser = try Parser(url: urlFor(testFile: testFile))
            let ledger = parser.parse()
            XCTAssertEqual(ledger.transactions.count, 0)
            return ledger
        } catch {
            XCTFail(String(describing: error))
        }
        return Ledger()
    }

    private func ensureMinimal(testFile: TestFile) {
        do {
            let parser = try Parser(url: urlFor(testFile: testFile))
            let ledger = parser.parse()
            XCTAssertEqual(ledger.transactions.count, 1)
            XCTAssert(ledger.errors.isEmpty)
            XCTAssertEqual(ledger.commodities.count, 1)
            XCTAssertEqual(ledger.accounts.count, 2)
            let transaction = ledger.transactions[0]
            XCTAssertEqual(transaction.postings.count, 2)
            XCTAssertEqual(transaction.metaData.payee, "Payee")
            XCTAssertEqual(transaction.metaData.narration, "Narration")
            XCTAssertEqual(transaction.metaData.date, TestUtils.date20170608)
            let posting1 = transaction.postings.first { $0.amount.number == Decimal(-1) }!
            XCTAssertEqual(posting1.accountName.fullName, "Equity:OpeningBalance")
            XCTAssertEqual(posting1.amount.commodity, Commodity(symbol: "EUR"))
            let posting2 = transaction.postings.first { $0.amount.number == Decimal(1) }!
            XCTAssertEqual(posting2.accountName.fullName, "Assets:Checking")
            XCTAssertEqual(posting2.amount.commodity, Commodity(symbol: "EUR"))
        } catch {
            XCTFail(String(describing: error))
        }
    }

}
