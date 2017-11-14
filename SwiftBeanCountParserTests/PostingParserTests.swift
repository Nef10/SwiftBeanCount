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
        basicPosting = Posting(account: Account(name: "Assets:Checking", accountType: .asset),
                               amount: Amount(number: Decimal(1.23),
                                              commodity: Commodity(symbol: "EUR"),
                                              decimalDigits: 2),
                               transaction: transaction)
    }

    let basicPostingString = "  Assets:Checking 1.23 EUR"
    let integerPostingString = "  Assets:Checking 1 EUR"
    let negativePostingString = "  Assets:Checking -1.2 EUR"
    let positivePostingString = "  Assets:Checking +1.23 EUR"
    let separatorPostingString = "  Assets:Checking -1,000.23 EUR"
    let whitespacePostingString = "         Assets:Checking        1.23    EUR     "
    let invalidAccountPostingString = "  Invalid:Checking 1.23 EUR"
    let endOfLineCommentPostingString = " Assets:Checking 1.23 EUR    ;gfdsg f gfds   "
    let specialCharacterPostingString = "  Assets:💰 1.00 💵"
    let totalPricePostingString = "  Assets:💰 2.00 💵 @@ 2.0 EUR"
    let unitPricePostingString = "  Assets:💰 2.0 💵 @ 1.003 EUR"

    func testBasic() {
        let posting = PostingParser.parseFrom(line: basicPostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testInteger() {
        let posting = PostingParser.parseFrom(line: integerPostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR"), decimalDigits: 0))
    }

    func testNegative() {
        let posting = PostingParser.parseFrom(line: negativePostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-1.2), commodity: Commodity(symbol: "EUR"), decimalDigits: 1))
    }

    func testPositive() {
        let posting = PostingParser.parseFrom(line: positivePostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testSeparator() {
        let posting = PostingParser.parseFrom(line: separatorPostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(-1_000.23), commodity: Commodity(symbol: "EUR"), decimalDigits: 2))
    }

    func testWhitespace() {
        let posting = PostingParser.parseFrom(line: whitespacePostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testSpecialCharacterPostingString() {
        let posting = PostingParser.parseFrom(line: specialCharacterPostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting.account, Account(name: "Assets:💰", accountType: .asset))
        XCTAssertEqual(posting.amount, Amount(number: Decimal(1), commodity: Commodity(symbol: "💵"), decimalDigits: 2))
    }

    func testInvalidAccount() {
        XCTAssertNil(PostingParser.parseFrom(line: invalidAccountPostingString, into: transaction, for: Ledger()))
    }

    func testEndOfLineCommentPostingString() {
        let posting = PostingParser.parseFrom(line: endOfLineCommentPostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting, basicPosting!)
    }

    func testTotalPrice() {
        let posting = PostingParser.parseFrom(line: totalPricePostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(2.00), commodity: Commodity(symbol: "💵"), decimalDigits: 2))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1), commodity: Commodity(symbol: "EUR"), decimalDigits: 1))
    }

    func testUnitPrice() {
        let posting = PostingParser.parseFrom(line: unitPricePostingString, into: transaction, for: Ledger())!
        XCTAssertEqual(posting.amount, Amount(number: Decimal(2), commodity: Commodity(symbol: "💵"), decimalDigits: 1))
        XCTAssertEqual(posting.price, Amount(number: Decimal(1.003), commodity: Commodity(symbol: "EUR"), decimalDigits: 3))
    }

    func testPerformance() {
        let ledger = Ledger()
        self.measure {
            for _ in 0...1_000 {
                _ = PostingParser.parseFrom(line: basicPostingString, into: transaction, for: ledger)!
                _ = PostingParser.parseFrom(line: whitespacePostingString, into: transaction, for: ledger)!
                _ = PostingParser.parseFrom(line: endOfLineCommentPostingString, into: transaction, for: ledger)!
                _ = PostingParser.parseFrom(line: specialCharacterPostingString, into: transaction, for: ledger)!
            }
        }
    }

}
