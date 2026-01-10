//
//  ParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountParser
import SwiftBeanCountModel
import Testing

@Suite

struct ParserTests {

    private enum TestFile: String {
        case minimal = "Minimal"
        case postingWithoutTransaction = "PostingWithoutTransaction"
        case transactionWithoutPosting = "TransactionWithoutPosting"
        case comments = "Comments"
        case commentsEndOfLine = "CommentsEndOfLine"
        case whitespace = "Whitespace"
        case big = "Big"
        case invalidCost = "InvalidCost"
        case metaData = "MetaData"

        static let withoutError = [minimal, comments, commentsEndOfLine, whitespace, big, metaData]
    }

    private let basicAccountOpeningString = "2017-06-09 open Assets:Cash"
    private let accountOpeningStringCommodity = "2017-06-09 open Assets:Cash EUR"
    private let basicAccountClosingString = "2017-06-09 close Assets:Cash"

    private let commodityString = "2017-06-09 commodity EUR"
    private let priceString = "2017-06-09 price EUR 1.50 CAD"
    private let balanceString = "2017-06-09 balance Assets:Cash 0.00 CAD"
    private let invalidBalanceString = "2017-06-09 balance TEST:Cash 0.00 CAD"
    private let optionString = "option \"ABC\" \"DEF\""
    private let pluginString = "plugin \"ABC\""
    private let eventString = "2017-06-09 event \"ABC\" \"DEF\""
    private let customString = "2017-06-09 custom \"ABC\" \"DEF\""

    private let metaDataString = "  metaData: \"TestString\""
    private let metaDataString2 = "  metaData2: \"TestString2\""
    private let metaData = ["metaData": "TestString"]
    private let metaData2 = ["metaData": "TestString", "metaData2": "TestString2"]
    private let comment = "; TEST comment"

    func testMinimal() {
        ensureMinimal(testFile: .minimal)
    }

    func testWhitespace() {
        ensureMinimal(testFile: .whitespace)
    }

    func testPostingWithoutTransaction() {
        let ledger = ensureEmpty(testFile: .postingWithoutTransaction)
        #expect(ledger.errors.count == 1)
    }

    func testTransactionWithoutPosting() {
        let ledger = ledgerFor(testFile: .transactionWithoutPosting)
        #expect(ledger.errors.count == 1)
        #expect(ledger.parsingErrors.count == 0)
    }

    func testComments() {
        let ledger = ensureEmpty(testFile: .comments)
        #expect(ledger.errors.count == 0)
    }

    func testCommentsEndOfLine() {
        ensureMinimal(testFile: .commentsEndOfLine)
    }

    func testInvalidCost() {
        var errorMessage = "" // do not check for the exact error message from library, just check that the parser correctly copies it
        do {
            _ = try Cost(amount: Amount(number: Decimal(-1), commoditySymbol: "EUR", decimalDigits: 2), date: nil, label: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
        let ledger1 = ledgerFor(testFile: .invalidCost)
        #expect(ledger1.errors.count == 2)
        #expect(ledger1.errors[0] == "\(errorMessage) (line 7)")
    }

    func testAccounts() {
        // open and close is ok
        var ledger = Parser.parse(string: "\(basicAccountOpeningString)\n\(basicAccountClosingString)")
        #expect(ledger.errors.isEmpty)

        // only open is ok
        ledger = Parser.parse(string: "\(basicAccountOpeningString)")
        #expect(ledger.errors.isEmpty)

        // only close is not ok
        ledger = Parser.parse(string: "\(basicAccountClosingString)")
        #expect(!(ledger.errors.isEmpty))

        // open twice is not ok
        ledger = Parser.parse(string: "\(basicAccountOpeningString)\n\(basicAccountOpeningString)")
        #expect(!(ledger.errors.isEmpty))
        ledger = Parser.parse(string: "\(accountOpeningStringCommodity)\n\(accountOpeningStringCommodity)")
        #expect(!(ledger.errors.isEmpty))

        // close twice is not ok
        ledger = Parser.parse(string: "\(basicAccountClosingString)\n\(basicAccountClosingString)")
        #expect(!(ledger.errors.isEmpty))

        // close twice (+ normal open) is not ok
        ledger = Parser.parse(string: "\(basicAccountOpeningString)\n\(basicAccountClosingString)\n\(basicAccountClosingString)")
        #expect(!(ledger.errors.isEmpty))

        // meta data
        ledger = Parser.parse(string: "\(basicAccountOpeningString)\n\(metaDataString)")
        #expect(ledger.accounts.first?.metaData == metaData)

        // no meta data on closing
        ledger = Parser.parse(string: "\(basicAccountOpeningString)\n\(basicAccountClosingString)\n\(metaDataString)")
        #expect(!(ledger.errors.isEmpty))
    }

    func testCommodity() {
        var ledger = Parser.parse(string: "\(commodityString)")
        #expect(ledger.errors.isEmpty)

        ledger = Parser.parse(string: "\(commodityString)\n\(commodityString)")
        #expect(!(ledger.errors.isEmpty))

        ledger = Parser.parse(string: "\(commodityString)\n\(metaDataString)")
        #expect(ledger.commodities.first?.metaData == metaData)
    }

    func testPrice() {
        var ledger = Parser.parse(string: "\(priceString)")
        #expect(ledger.parsingErrors.isEmpty)

        ledger = Parser.parse(string: "\(priceString)\n\(priceString)")
        #expect(!(ledger.parsingErrors.isEmpty))

        ledger = Parser.parse(string: "\(priceString)\n\(metaDataString)")
        #expect(ledger.prices.first?.metaData == metaData)
    }

    func testBalance() {
        var ledger = Parser.parse(string: "\(balanceString)")
        #expect(ledger.parsingErrors.isEmpty)

        ledger = Parser.parse(string: "\(invalidBalanceString)")
        #expect(!(ledger.parsingErrors.isEmpty))

        ledger = Parser.parse(string: "\(balanceString)\n\(metaDataString)")
        #expect(ledger.accounts.first?.balances.first?.metaData == metaData)
    }

    func testOption() {
        let ledger = Parser.parse(string: "\(optionString)")
        #expect(ledger.option.first == Option(name: "ABC", value: "DEF"))
    }

    func testPlugin() {
        let ledger = Parser.parse(string: "\(pluginString)")
        #expect(ledger.plugins.first == "ABC")
    }

    func testEvent() {
        var ledger = Parser.parse(string: "\(eventString)")
        #expect(ledger.events.first == Event(date: TestUtils.date20170609, name: "ABC", value: "DEF"))

        ledger = Parser.parse(string: "\(eventString)\n\(metaDataString)")
        #expect(ledger.events.first?.metaData == metaData)
    }

    func testCustom() {
        var ledger = Parser.parse(string: "\(customString)")
        #expect(ledger.custom.first == Custom(date: TestUtils.date20170609, name: "ABC", values: ["DEF"]))

        ledger = Parser.parse(string: "\(customString)\n\(metaDataString)")
        #expect(ledger.custom.first?.metaData == metaData)
    }

    func testCommentsMetaData() {
        var ledger = Parser.parse(string: "\(comment)")
        #expect(ledger.errors.isEmpty)

        ledger = Parser.parse(string: "\(comment)\n\(eventString)")
        #expect(ledger.events.first == Event(date: TestUtils.date20170609, name: "ABC", value: "DEF"))

        ledger = Parser.parse(string: "\((comment))\n\(eventString)\n\(metaDataString)")
        #expect(ledger.events.first?.metaData == metaData)

        ledger = Parser.parse(string: "\((comment))\n\(eventString)\n\(metaDataString)\n\(comment)\n\(metaDataString2)")
        #expect(ledger.events.first?.metaData == metaData2)
    }

    func testMetaData() {
        let ledger = ledgerFor(testFile: .metaData)
        #expect(ledger.accounts[0].metaData == metaData2)
        #expect(ledger.accounts[1].metaData == metaData2)
        #expect(ledger.commodities.first?.metaData == metaData2)
        #expect(ledger.transactions[0].metaData.metaData == metaData2)
        #expect(ledger.transactions[0].postings[0].metaData == metaData2)
        #expect(ledger.transactions[0].postings[1].metaData == metaData2)
        #expect(ledger.transactions[1].metaData.metaData == metaData2)
        #expect(ledger.transactions[1].postings[0].metaData == metaData2)
        #expect(ledger.transactions[1].postings[1].metaData == metaData2)
    }

    func testRoundTrip() {
        for testFile in TestFile.withoutError {
            let ledger1 = ledgerFor(testFile: testFile)
            let ledger2 = Parser.parse(string: String(describing: ledger1))
            let result = ledger1 == ledger2
            #expect(result)
        }
    }

    func testPerformance() {
        self.measure {
            _ = ledgerFor(testFile: .big)
        }
    }

    //  Helper

    private func ensureEmpty(testFile: TestFile) -> Ledger {
        let ledger = ledgerFor(testFile: testFile)
        #expect(ledger.transactions.count == 0)
        return ledger
    }

    private func ensureMinimal(testFile: TestFile) {
        let ledger = ledgerFor(testFile: testFile)
        #expect(ledger.transactions.count == 1)
        #expect(ledger.errors.isEmpty)
        #expect(ledger.commodities.count == 1)
        #expect(ledger.accounts.count == 2)
        let transaction = ledger.transactions[0]
        #expect(transaction.postings.count == 2)
        #expect(transaction.metaData.payee == "Payee")
        #expect(transaction.metaData.narration == "Narration")
        #expect(transaction.metaData.date == TestUtils.date20170608)
        let posting1 = transaction.postings.first { $0.amount.number == Decimal(-1) }!
        #expect(posting1.accountName.fullName == "Equity:OpeningBalance")
        #expect(posting1.amount.commoditySymbol == "EUR")
        let posting2 = transaction.postings.first { $0.amount.number == Decimal(1) }!
        #expect(posting2.accountName.fullName == "Assets:Checking")
        #expect(posting2.amount.commoditySymbol == "EUR")
    }

    private func ledgerFor(testFile: TestFile) -> Ledger {
        let url: URL
        switch testFile {
        case .minimal:
            url = Bundle.module.url(forResource: "Resource/Minimal", withExtension: "beancount")!
        case .postingWithoutTransaction:
            url = Bundle.module.url(forResource: "Resource/PostingWithoutTransaction", withExtension: "beancount")!
        case .transactionWithoutPosting:
            url = Bundle.module.url(forResource: "Resource/TransactionWithoutPosting", withExtension: "beancount")!
        case .comments:
            url = Bundle.module.url(forResource: "Resource/Comments", withExtension: "beancount")!
        case .commentsEndOfLine:
            url = Bundle.module.url(forResource: "Resource/CommentsEndOfLine", withExtension: "beancount")!
        case .whitespace:
            url = Bundle.module.url(forResource: "Resource/Whitespace", withExtension: "beancount")!
        case .big:
            url = Bundle.module.url(forResource: "Resource/Big", withExtension: "beancount")!
        case .invalidCost:
            url = Bundle.module.url(forResource: "Resource/InvalidCost", withExtension: "beancount")!
        case .metaData:
            url = Bundle.module.url(forResource: "Resource/MetaData", withExtension: "beancount")!
        }
        guard let ledger = try? Parser.parse(contentOf: url) else {
            Issue.record("Failed to parse ledger at URL: \(url.absoluteString)")
            return Ledger()
        }
        return ledger
    }

}
