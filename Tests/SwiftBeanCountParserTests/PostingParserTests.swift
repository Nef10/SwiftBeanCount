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

    let transaction = Transaction(metaData: TransactionMetaData(date: Date(), payee: "Payee", narration: "Narration"), postings: [])

    var basicPosting: Posting?

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

    override func setUp() {
        super.setUp()
        basicPosting = Posting(accountName: try! AccountName("Assets:Checking"),
                               amount: Amount(number: Decimal(1.23),
                                              commoditySymbol: "EUR",
                                              decimalDigits: 2))
    }

    func testBasic() {
        let posting = try! PostingParser.parseFrom(line: basicPostingString)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testInteger() {
        let posting = try! PostingParser.parseFrom(line: integerPostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 0))
    }

    func testNoThousandsSeparator() {
        let posting = try! PostingParser.parseFrom(line: noThousandsSeparatorPostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(100_000), commoditySymbol: "EUR", decimalDigits: 0))
    }

    func testThousandsSeparator() {
        let posting = try! PostingParser.parseFrom(line: thousandsSeparatorPostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(100_000), commoditySymbol: "EUR", decimalDigits: 0))
    }

    func testNegative() {
        let posting = try! PostingParser.parseFrom(line: negativePostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-1.2), commoditySymbol: "EUR", decimalDigits: 1))
    }

    func testPositive() {
        let posting = try! PostingParser.parseFrom(line: positivePostingString)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testSeparator() {
        let posting = try! PostingParser.parseFrom(line: separatorPostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-1_000.23), commoditySymbol: "EUR", decimalDigits: 2))
    }

    func testWhitespace() {
        let posting = try! PostingParser.parseFrom(line: whitespacePostingString)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testSpecialCharacterPostingString() {
        let posting = try! PostingParser.parseFrom(line: specialCharacterPostingString)!
        XCTAssertEqual(posting.accountName, try! AccountName("Assets:💰"))
        XCTAssertEqual(posting.amount, Amount(number: Decimal(1), commoditySymbol: "💵", decimalDigits: 2))
    }

    func testInvalidAccount() {
        XCTAssertNil(try! PostingParser.parseFrom(line: invalidAccountPostingString))
    }

    func testEndOfLineCommentPostingString() {
        let posting = try! PostingParser.parseFrom(line: endOfLineCommentPostingString)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testTotalPrice() {
        let posting = try! PostingParser.parseFrom(line: totalPricePostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-2.00), commoditySymbol: "💵", decimalDigits: 2))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 1))
    }

    func testUnitPrice() {
        let posting = try! PostingParser.parseFrom(line: unitPricePostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(2), commoditySymbol: "💵", decimalDigits: 1))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3))
    }

    func testCost() {
        let posting = try! PostingParser.parseFrom(line: costPostingString)!
        XCTAssertEqual(posting.cost!,
                       try! Cost(amount: Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3), date: TestUtils.date20170609, label: "TEST"))
    }

    func testInvalidCost() {
        XCTAssertThrowsError(try PostingParser.parseFrom(line: invalidCostPostingString))
    }

    func testCostAndUnitPrice() {
        let posting = try! PostingParser.parseFrom(line: costAndUnitPricePostingString)!
        XCTAssertEqual(posting.cost!,
                       try! Cost(amount: Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3), date: TestUtils.date20170609, label: nil))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3))
    }

    func testCostAndTotalPrice() {
        let posting = try! PostingParser.parseFrom(line: costAndTotalPricePostingString)!
        XCTAssertEqual(posting.cost!, try! Cost(amount: Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3), date: nil, label: "TEST"))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 1))
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = try! PostingParser.parseFrom(line: basicPostingString)!
                _ = try! PostingParser.parseFrom(line: whitespacePostingString)!
                _ = try! PostingParser.parseFrom(line: endOfLineCommentPostingString)!
                _ = try! PostingParser.parseFrom(line: specialCharacterPostingString)!
            }
        }
    }

}
