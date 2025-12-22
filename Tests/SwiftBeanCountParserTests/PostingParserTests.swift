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

final class PostingParserTests: XCTestCase {

    private let transaction = Transaction(metaData: TransactionMetaData(date: Date(), payee: "Payee", narration: "Narration"), postings: [])

    private var basicPosting: Posting?

    private let basicPostingString = "  Assets:Checking 1.23 EUR"
    private let integerPostingString = "  Assets:Checking 1 EUR"
    private let noThousandsSeparatorPostingString = "  Assets:Checking 100000 EUR"
    private let thousandsSeparatorPostingString = "  Assets:Checking 100,000 EUR"
    private let negativePostingString = "  Assets:Checking -1.2 EUR"
    private let positivePostingString = "  Assets:Checking +1.23 EUR"
    private let separatorPostingString = "  Assets:Checking -1,000.23 EUR"
    private let whitespacePostingString = "         Assets:Checking        1.23    EUR     "
    private let invalidAccountPostingString = "  Invalid:Checking 1.23 EUR"
    private let endOfLineCommentPostingString = " Assets:Checking 1.23 EUR    ;gfdsg f gfds   "
    private let specialCharacterPostingString = "  Assets:💰 1.00 💵"
    private let totalPricePostingString = "  Assets:💰 -2.00 💵 @@ 2.0 EUR"
    private let unitPricePostingString = "  Assets:💰 2.0 💵 @ 1.003 EUR"
    private let costPostingString = "  Assets:💰 2.0 💵 {2017-06-09, 1.003 EUR, \"TEST\"}"
    private let invalidCostPostingString = "  Assets:💰 2.0 💵 {2017-06-09, -1.003 EUR, \"TEST\"}"
    private let costAndUnitPricePostingString = "  Assets:💰 2.0 💵 {2017-06-09, 1.003 EUR} @ 1.003 EUR"
    private let costAndTotalPricePostingString = "  Assets:💰 2.0 💵 {1.003 EUR, \"TEST\"} @@ 2.0 EUR"

    override func setUpWithError() throws {
        try super.setUpWithError()
        basicPosting = Posting(accountName: try AccountName("Assets:Checking"),
                               amount: Amount(number: Decimal(1.23),
                                              commoditySymbol: "EUR",
                                              decimalDigits: 2))
    }

    func testBasic() throws {
        let posting = try PostingParser.parseFrom(line: basicPostingString)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testInteger() throws {
        let posting = try PostingParser.parseFrom(line: integerPostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 0))
    }

    func testNoThousandsSeparator() throws {
        let posting = try PostingParser.parseFrom(line: noThousandsSeparatorPostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(100_000), commoditySymbol: "EUR", decimalDigits: 0))
    }

    func testThousandsSeparator() throws {
        let posting = try PostingParser.parseFrom(line: thousandsSeparatorPostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(100_000), commoditySymbol: "EUR", decimalDigits: 0))
    }

    func testNegative() throws {
        let posting = try PostingParser.parseFrom(line: negativePostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-1.2), commoditySymbol: "EUR", decimalDigits: 1))
    }

    func testPositive() throws {
        let posting = try PostingParser.parseFrom(line: positivePostingString)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testSeparator() throws {
        let posting = try PostingParser.parseFrom(line: separatorPostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-1_000.23), commoditySymbol: "EUR", decimalDigits: 2))
    }

    func testWhitespace() throws {
        let posting = try PostingParser.parseFrom(line: whitespacePostingString)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testSpecialCharacterPostingString() throws {
        let posting = try PostingParser.parseFrom(line: specialCharacterPostingString)!
        XCTAssertEqual(posting.accountName, try AccountName("Assets:💰"))
        XCTAssertEqual(posting.amount, Amount(number: Decimal(1), commoditySymbol: "💵", decimalDigits: 2))
    }

    func testInvalidAccount() throws {
        XCTAssertNil(try PostingParser.parseFrom(line: invalidAccountPostingString))
    }

    func testEndOfLineCommentPostingString() throws {
        let posting = try PostingParser.parseFrom(line: endOfLineCommentPostingString)!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testTotalPrice() throws {
        let posting = try PostingParser.parseFrom(line: totalPricePostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-2.00), commoditySymbol: "💵", decimalDigits: 2))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 1))
    }

    func testUnitPrice() throws {
        let posting = try PostingParser.parseFrom(line: unitPricePostingString)!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(2), commoditySymbol: "💵", decimalDigits: 1))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3))
    }

    func testCost() throws {
        let posting = try PostingParser.parseFrom(line: costPostingString)!
        XCTAssertEqual(posting.cost!,
                       try Cost(amount: Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3), date: TestUtils.date20170609, label: "TEST"))
    }

    func testInvalidCost() throws {
        XCTAssertThrowsError(try PostingParser.parseFrom(line: invalidCostPostingString))
    }

    func testCostAndUnitPrice() throws {
        let posting = try PostingParser.parseFrom(line: costAndUnitPricePostingString)!
        XCTAssertEqual(posting.cost!,
                       try Cost(amount: Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3), date: TestUtils.date20170609, label: nil))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3))
    }

    func testCostAndTotalPrice() throws {
        let posting = try PostingParser.parseFrom(line: costAndTotalPricePostingString)!
        XCTAssertEqual(posting.cost!, try Cost(amount: Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3), date: nil, label: "TEST"))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 1))
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                // swiftlint:disable force_try
                _ = try! PostingParser.parseFrom(line: basicPostingString)!
                _ = try! PostingParser.parseFrom(line: whitespacePostingString)!
                _ = try! PostingParser.parseFrom(line: endOfLineCommentPostingString)!
                _ = try! PostingParser.parseFrom(line: specialCharacterPostingString)!
                // swiftlint:enable force_try
            }
        }
    }

}
