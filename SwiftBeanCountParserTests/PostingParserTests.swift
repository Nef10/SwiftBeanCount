//
//  PostingParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-09.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class PostingParserTests: XCTestCase {

    let transaction = Transaction(metaData: TransactionMetaData(date: Date(), payee: "Payee", narration: "Narration", flag: Flag.complete, tags: []))

    var basicPosting: Posting?

    override func setUp() {
        super.setUp()
        basicPosting = Posting(account: try! Account(name: "Assets:Checking"),
                               amount: Amount(number: Decimal(1.23),
                                              commodity: Commodity(symbol: "EUR"),
                                              decimalDigits: 2),
                               transaction: transaction)
    }

    let basicPostingString = "  Assets:Checking 1.23 EUR"
    let integerPostingString = "  Assets:Checking 1 EUR"
    let noThousandsSeparatorPostingString = "  Assets:Checking 100000 EUR"
    let thousandsSeparatorPostingString = "  Assets:Checking 100,000 EUR"
    let negativePostingString = "  Assets:Checking -1.2 EUR"
    let positivePostingString = "  Assets:Checking +1.23 EUR"
    let separatorPostingString = "  Assets:Checking -1,000.23 EUR"
    let whitespacePostingString = "         Assets:Checking        1.23    EUR     "
    let invalidAccountPostingString = "  Invalid:Checking 1.23 EUR"
    let endOfLineCommentPostingString = " Assets:Checking 1.23 EUR    ;gfdsg f gfds   "
    let specialCharacterPostingString = "  Assets:💰 1.00 💵"
    let totalPricePostingString = "  Assets:💰 -2.00 💵 @@ 2.0 EUR"
    let unitPricePostingString = "  Assets:💰 2.0 💵 @ 1.003 EUR"
    let costPostingString = "  Assets:💰 2.0 💵 {2017-06-09, 1.003 EUR, \"TEST\"}"
    let invalidCostPostingString = "  Assets:💰 2.0 💵 {2017-06-09, -1.003 EUR, \"TEST\"}"
    let costAndUnitPricePostingString = "  Assets:💰 2.0 💵 {2017-06-09, 1.003 EUR} @ 1.003 EUR"
    let costAndTotalPricePostingString = "  Assets:💰 2.0 💵 {1.003 EUR, \"TEST\"} @@ 2.0 EUR"

    func testBasic() {
        let posting = try! PostingParser.parseFrom(line: basicPostingString, into: transaction)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testInteger() {
        let posting = try! PostingParser.parseFrom(line: integerPostingString, into: transaction)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR"), decimalDigits: 0))
    }

    func testNoThousandsSeparator() {
        let posting = try! PostingParser.parseFrom(line: noThousandsSeparatorPostingString, into: transaction)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(100_000), commodity: Commodity(symbol: "EUR"), decimalDigits: 0))
    }

    func testThousandsSeparator() {
        let posting = try! PostingParser.parseFrom(line: thousandsSeparatorPostingString, into: transaction)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(100_000), commodity: Commodity(symbol: "EUR"), decimalDigits: 0))
    }

    func testNegative() {
        let posting = try! PostingParser.parseFrom(line: negativePostingString, into: transaction)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-1.2), commodity: Commodity(symbol: "EUR"), decimalDigits: 1))
    }

    func testPositive() {
        let posting = try! PostingParser.parseFrom(line: positivePostingString, into: transaction)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testSeparator() {
        let posting = try! PostingParser.parseFrom(line: separatorPostingString, into: transaction)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-1_000.23), commodity: Commodity(symbol: "EUR"), decimalDigits: 2))
    }

    func testWhitespace() {
        let posting = try! PostingParser.parseFrom(line: whitespacePostingString, into: transaction)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testSpecialCharacterPostingString() {
        let posting = try! PostingParser.parseFrom(line: specialCharacterPostingString, into: transaction)!
        XCTAssertEqual(posting.account, try! Account(name: "Assets:💰"))
        XCTAssertEqual(posting.amount, Amount(number: Decimal(1), commodity: Commodity(symbol: "💵"), decimalDigits: 2))
    }

    func testInvalidAccount() {
        XCTAssertNil(try! PostingParser.parseFrom(line: invalidAccountPostingString, into: transaction))
    }

    func testEndOfLineCommentPostingString() {
        let posting = try! PostingParser.parseFrom(line: endOfLineCommentPostingString, into: transaction)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testTotalPrice() {
        let posting = try! PostingParser.parseFrom(line: totalPricePostingString, into: transaction)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-2.00), commodity: Commodity(symbol: "💵"), decimalDigits: 2))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR"), decimalDigits: 1))
    }

    func testUnitPrice() {
        let posting = try! PostingParser.parseFrom(line: unitPricePostingString, into: transaction)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(2), commodity: Commodity(symbol: "💵"), decimalDigits: 1))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1.003), commodity: Commodity(symbol: "EUR"), decimalDigits: 3))
    }

    func testCost() {
        let posting = try! PostingParser.parseFrom(line: costPostingString, into: transaction)!
        XCTAssertEqual(posting.cost!,
                       try! Cost(amount: Amount(number: Decimal(1.003), commodity: Commodity(symbol: "EUR"), decimalDigits: 3), date: TestUtils.date20170609, label: "TEST"))
    }

    func testInvalidCost() {
        XCTAssertThrowsError(try PostingParser.parseFrom(line: invalidCostPostingString, into: transaction))
    }

    func testCostAndUnitPrice() {
        let posting = try! PostingParser.parseFrom(line: costAndUnitPricePostingString, into: transaction)!
        XCTAssertEqual(posting.cost!,
                       try! Cost(amount: Amount(number: Decimal(1.003), commodity: Commodity(symbol: "EUR"), decimalDigits: 3), date: TestUtils.date20170609, label: nil))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1.003), commodity: Commodity(symbol: "EUR"), decimalDigits: 3))
    }

    func testCostAndTotalPrice() {
        let posting = try! PostingParser.parseFrom(line: costAndTotalPricePostingString, into: transaction)!
        XCTAssertEqual(posting.cost!, try! Cost(amount: Amount(number: Decimal(1.003), commodity: Commodity(symbol: "EUR"), decimalDigits: 3), date: nil, label: "TEST"))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR"), decimalDigits: 1))
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = try! PostingParser.parseFrom(line: basicPostingString, into: transaction)!
                _ = try! PostingParser.parseFrom(line: whitespacePostingString, into: transaction)!
                _ = try! PostingParser.parseFrom(line: endOfLineCommentPostingString, into: transaction)!
                _ = try! PostingParser.parseFrom(line: specialCharacterPostingString, into: transaction)!
            }
        }
    }

}
