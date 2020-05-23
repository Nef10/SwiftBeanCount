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
        case metaData = "MetaData"

        static let withoutError = [minimal, comments, commentsEndOfLine, whitespace, big, metaData]
    }

    let basicAccountOpeningString = "2017-06-09 open Assets:Cash"
    let accountOpeningStringCommodity = "2017-06-09 open Assets:Cash EUR"
    let basicAccountClosingString = "2017-06-09 close Assets:Cash"

    let commodityString = "2017-06-09 commodity EUR"
    let priceString = "2017-06-09 price EUR 1.50 CAD"
    let balanceString = "2017-06-09 balance Assets:Cash 0.00 CAD"
    let invalidBalanceString = "2017-06-09 balance TEST:Cash 0.00 CAD"
    let optionString = "option \"ABC\" \"DEF\""
    let pluginString = "plugin \"ABC\""
    let eventString = "2017-06-09 event \"ABC\" \"DEF\""
    let customString = "2017-06-09 custom \"ABC\" \"DEF\""

    let metaDataString = "  metaData: \"TestString\""
    let metaDataString2 = "  metaData2: \"TestString2\""
    let metaData = ["metaData": "TestString"]
    let metaData2 = ["metaData": "TestString", "metaData2": "TestString2"]
    let comment = "; TEST comment"

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
        let ledger = ledgerFor(testFile: .transactionWithoutPosting)
        XCTAssertEqual(ledger.errors.count, 1)
        XCTAssertEqual(ledger.parsingErrors.count, 0)
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
        let ledger1 = ledgerFor(testFile: .invalidCost)
        XCTAssertEqual(ledger1.errors.count, 2)
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

        // meta data
        parser = Parser(string: "\(basicAccountOpeningString)\n\(metaDataString)")
        ledger = parser.parse()
        XCTAssertEqual(ledger.accounts.first?.metaData, metaData)

        // no meta data on closing
        parser = Parser(string: "\(basicAccountOpeningString)\n\(basicAccountClosingString)\n\(metaDataString)")
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

        parser = Parser(string: "\(commodityString)\n\(metaDataString)")
        ledger = parser.parse()
        XCTAssertEqual(ledger.commodities.first?.metaData, metaData)
    }

    func testPrice() {
        var parser = Parser(string: "\(priceString)")
        var ledger = parser.parse()
        XCTAssertTrue(ledger.errors.isEmpty)

        parser = Parser(string: "\(priceString)\n\(priceString)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)

        parser = Parser(string: "\(priceString)\n\(metaDataString)")
        ledger = parser.parse()
        XCTAssertEqual(ledger.prices.first?.metaData, metaData)
    }

    func testBalance() {
        var parser = Parser(string: "\(balanceString)")
        var ledger = parser.parse()
        XCTAssertTrue(ledger.errors.isEmpty)

        parser = Parser(string: "\(invalidBalanceString)")
        ledger = parser.parse()
        XCTAssertFalse(ledger.errors.isEmpty)

        parser = Parser(string: "\(balanceString)\n\(metaDataString)")
        ledger = parser.parse()
        XCTAssertEqual(ledger.accounts.first?.balances.first?.metaData, metaData)
    }

    func testOption() {
        let parser = Parser(string: "\(optionString)")
        let ledger = parser.parse()
        XCTAssertEqual(ledger.option.first, Option(name: "ABC", value: "DEF"))
    }

    func testPlugin() {
        let parser = Parser(string: "\(pluginString)")
        let ledger = parser.parse()
        XCTAssertEqual(ledger.plugins.first, "ABC")
    }

    func testEvent() {
        var parser = Parser(string: "\(eventString)")
        var ledger = parser.parse()
        XCTAssertEqual(ledger.events.first, Event(date: TestUtils.date20170609, name: "ABC", value: "DEF"))

        parser = Parser(string: "\(eventString)\n\(metaDataString)")
        ledger = parser.parse()
        XCTAssertEqual(ledger.events.first?.metaData, metaData)
    }

    func testCustom() {
        var parser = Parser(string: "\(customString)")
        var ledger = parser.parse()
        XCTAssertEqual(ledger.custom.first, Custom(date: TestUtils.date20170609, name: "ABC", values: ["DEF"]))

        parser = Parser(string: "\(customString)\n\(metaDataString)")
        ledger = parser.parse()
        XCTAssertEqual(ledger.custom.first?.metaData, metaData)
    }

    func testCommentsMetaData() {
        var parser = Parser(string: "\(comment)")
        var ledger = parser.parse()
        XCTAssertTrue(ledger.errors.isEmpty)

        parser = Parser(string: "\(comment)\n\(eventString)")
        ledger = parser.parse()
        XCTAssertEqual(ledger.events.first, Event(date: TestUtils.date20170609, name: "ABC", value: "DEF"))

        parser = Parser(string: "\((comment))\n\(eventString)\n\(metaDataString)")
        ledger = parser.parse()
        XCTAssertEqual(ledger.events.first?.metaData, metaData)

        parser = Parser(string: "\((comment))\n\(eventString)\n\(metaDataString)\n\(comment)\n\(metaDataString2)")
        ledger = parser.parse()
        XCTAssertEqual(ledger.events.first?.metaData, metaData2)
    }

    func testMetaData() {
        let ledger = ledgerFor(testFile: .metaData)
        XCTAssertEqual(ledger.accounts[0].metaData, metaData2)
        XCTAssertEqual(ledger.accounts[1].metaData, metaData2)
        XCTAssertEqual(ledger.commodities.first?.metaData, metaData2)
        XCTAssertEqual(ledger.transactions[0].metaData.metaData, metaData2)
        XCTAssertEqual(ledger.transactions[0].postings[0].metaData, metaData2)
        XCTAssertEqual(ledger.transactions[0].postings[1].metaData, metaData2)
        XCTAssertEqual(ledger.transactions[1].metaData.metaData, metaData2)
        XCTAssertEqual(ledger.transactions[1].postings[0].metaData, metaData2)
        XCTAssertEqual(ledger.transactions[1].postings[1].metaData, metaData2)
    }

    func testRoundTrip() {
        for testFile in TestFile.withoutError {
            let ledger1 = ledgerFor(testFile: testFile)
            let parser2 = Parser(string: String(describing: ledger1))
            let ledger2 = parser2.parse()
            let result = ledger1 == ledger2
            XCTAssert(result)
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
        XCTAssertEqual(ledger.transactions.count, 0)
        return ledger
    }

    private func ensureMinimal(testFile: TestFile) {
        let ledger = ledgerFor(testFile: testFile)
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
    }

    private func ledgerFor(testFile: TestFile) -> Ledger {
        do {
            let url = NSURL.fileURL(withPath: Bundle(for: type(of: self)).path(forResource: testFile.rawValue, ofType: "beancount")!)
            let parser = try Parser(url: url)
            let ledger = parser.parse()
            return ledger
        } catch {
            XCTFail(String(describing: error))
        }
        return Ledger()

    }

}
