//
//  PostingParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-09.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import Testing

@Suite
struct PostingParserTests {

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

    @Test
    func basic() throws {
        let posting = try PostingParser.parseFrom(line: basicPostingString)!
        #expect(posting == basicPosting!)
    }

    @Test
    func integer() throws {
        let posting = try PostingParser.parseFrom(line: integerPostingString)!
        #expect(posting.amount == Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 0))
    }

    @Test
    func noThousandsSeparator() throws {
        let posting = try PostingParser.parseFrom(line: noThousandsSeparatorPostingString)!
        #expect(posting.amount == Amount(number: Decimal(100_000), commoditySymbol: "EUR", decimalDigits: 0))
    }

    @Test
    func thousandsSeparator() throws {
        let posting = try PostingParser.parseFrom(line: thousandsSeparatorPostingString)!
        #expect(posting.amount == Amount(number: Decimal(100_000), commoditySymbol: "EUR", decimalDigits: 0))
    }

    @Test
    func negative() throws {
        let posting = try PostingParser.parseFrom(line: negativePostingString)!
        #expect(posting.amount == Amount(number: Decimal(-1.2), commoditySymbol: "EUR", decimalDigits: 1))
    }

    @Test
    func positive() throws {
        let posting = try PostingParser.parseFrom(line: positivePostingString)!
        #expect(posting == basicPosting!)
    }

    @Test
    func separator() throws {
        let posting = try PostingParser.parseFrom(line: separatorPostingString)!
        #expect(posting.amount == Amount(number: Decimal(-1_000.23), commoditySymbol: "EUR", decimalDigits: 2))
    }

    @Test
    func whitespace() throws {
        let posting = try PostingParser.parseFrom(line: whitespacePostingString)!
        #expect(posting == basicPosting!)
    }

    @Test
    func specialCharacterPosting() throws {
        let posting = try PostingParser.parseFrom(line: specialCharacterPostingString)!
        #expect(try AccountName("Assets:💰") == posting.accountName)
        #expect(posting.amount == Amount(number: Decimal(1), commoditySymbol: "💵", decimalDigits: 2))
    }

    @Test
    func invalidAccount() throws {
        #expect(try PostingParser.parseFrom(line: invalidAccountPostingString) == nil)
    }

    @Test
    func endOfLineCommentPosting() throws {
        let posting = try PostingParser.parseFrom(line: endOfLineCommentPostingString)!
        #expect(posting == basicPosting!)
    }

    @Test
    func totalPrice() throws {
        let posting = try PostingParser.parseFrom(line: totalPricePostingString)!
        #expect(posting.amount == Amount(number: Decimal(-2.00), commoditySymbol: "💵", decimalDigits: 2))
        #expect(posting.price == Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 1))
    }

    @Test
    func unitPrice() throws {
        let posting = try PostingParser.parseFrom(line: unitPricePostingString)!
        #expect(posting.amount == Amount(number: Decimal(2), commoditySymbol: "💵", decimalDigits: 1))
        #expect(posting.price == Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3))
    }

    @Test
    func cost() throws {
        let posting = try PostingParser.parseFrom(line: costPostingString)!
        #expect(try Cost(amount: Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3), date: TestUtils.date20170609, label: "TEST") == posting.cost!)
    }

    @Test
    func invalidCost() throws {
        #expect(throws: (any Error).self) { try PostingParser.parseFrom(line: invalidCostPostingString) }
    }

    @Test
    func costAndUnitPrice() throws {
        let posting = try PostingParser.parseFrom(line: costAndUnitPricePostingString)!
        #expect(try Cost(amount: Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3), date: TestUtils.date20170609, label: nil) == posting.cost!)
        #expect(posting.price == Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3))
    }

    @Test
    func costAndTotalPrice() throws {
        let posting = try PostingParser.parseFrom(line: costAndTotalPricePostingString)!
        #expect(try Cost(amount: Amount(number: Decimal(1.003), commoditySymbol: "EUR", decimalDigits: 3), date: nil, label: "TEST") == posting.cost!)
        #expect(posting.price == Amount(number: Decimal(1), commoditySymbol: "EUR", decimalDigits: 1))
    }

}
