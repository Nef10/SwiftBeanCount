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

        static let withoutError = [minimal, comments, commentsEndOfLine, whitespace, big]
    }

    let basicAccountOpeningString = "2017-06-09 open Assets:Cash"
    let accountOpeningStringCommodity = "2017-06-09 open Assets:Cash EUR"
    let basicAccountClosingString = "2017-06-09 close Assets:Cash"

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

    func testAccounts() {
        // open and close is ok
        var ledger = Parser.parse(string: "\(basicAccountOpeningString)\n\(basicAccountClosingString)")
        XCTAssertTrue(ledger.errors.isEmpty)

        // only open is ok
        ledger = Parser.parse(string: "\(basicAccountOpeningString)")
        XCTAssertTrue(ledger.errors.isEmpty)

        // only close is not ok
        ledger = Parser.parse(string: "\(basicAccountClosingString)")
        XCTAssertFalse(ledger.errors.isEmpty)

        // open twice is not ok
        ledger = Parser.parse(string: "\(basicAccountOpeningString)\n\(basicAccountOpeningString)")
        XCTAssertFalse(ledger.errors.isEmpty)
        ledger = Parser.parse(string: "\(accountOpeningStringCommodity)\n\(accountOpeningStringCommodity)")
        XCTAssertFalse(ledger.errors.isEmpty)

        // close twice is not ok
        ledger = Parser.parse(string: "\(basicAccountClosingString)\n\(basicAccountClosingString)")
        XCTAssertFalse(ledger.errors.isEmpty)

        // close twice (+ normal open) is not ok
        ledger = Parser.parse(string: "\(basicAccountOpeningString)\n\(basicAccountClosingString)\n\(basicAccountClosingString)")
        XCTAssertFalse(ledger.errors.isEmpty)
    }

    func testRoundTrip() {
        do {
            for testFile in TestFile.withoutError {
                let ledger1 = try Parser.parse(contentOf: urlFor(testFile: testFile))
                let ledger2 = Parser.parse(string: String(describing: ledger1))
                let result = ledger1 == ledger2
                XCTAssert(result)
            }
        } catch let error {
            XCTFail(String(describing: error))
        }
    }

    func testPerformance() {
        self.measure {
            do {
                _ = try Parser.parse(contentOf: urlFor(testFile: .big))
            } catch let error {
                XCTFail(String(describing: error))
            }
        }
    }

    //  Helper

    private func urlFor(testFile: TestFile) -> URL {
        return NSURL.fileURL(withPath: Bundle(for: type(of: self)).path(forResource: testFile.rawValue, ofType: "beancount")!)
    }

    private func ensureEmpty(testFile: TestFile) -> Ledger {
        do {
            let ledger = try Parser.parse(contentOf: urlFor(testFile: testFile))
            XCTAssertEqual(ledger.transactions.count, 0)
            return ledger
        } catch let error {
            XCTFail(String(describing: error))
        }
        return Ledger()
    }

    private func ensureMinimal(testFile: TestFile) {
        do {
            let ledger = try Parser.parse(contentOf: urlFor(testFile: testFile))
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
            XCTAssertEqual(posting1.account.name, "Equity:OpeningBalance")
            XCTAssertEqual(posting1.account.opening, TestUtils.date20170608)
            XCTAssertEqual(posting1.amount.commodity, Commodity(symbol: "EUR"))
            let posting2 = transaction.postings.first { $0.amount.number == Decimal(1) }!
            XCTAssertEqual(posting2.account.name, "Assets:Checking")
            XCTAssertEqual(posting2.account.opening, TestUtils.date20170608)
            XCTAssertEqual(posting2.amount.commodity, Commodity(symbol: "EUR"))
        } catch let error {
            XCTFail(String(describing: error))
        }
    }

}
