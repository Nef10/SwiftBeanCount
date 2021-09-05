//
//  AccountParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-12.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class AccountParserTests: XCTestCase {

    private let basicOpeningString = "2017-06-09 open Assets:Cash"
    private let basicClosingString = "2017-06-09 close Assets:Cash"

    private let whitespaceOpeningString = "2017-06-09    open    Assets:Cash      CAD"
    private let whitespaceClosingString = "2017-06-09   close      Assets:Cash"

    private let endOfLineCommentOpeningString = "2017-06-09 open Assets:Cash EUR ;gfsdt     "
    private let endOfLineCommentClosingString = "2017-06-09 close Assets:Cash   ;gfd "

    private let specialCharacterOpeningString = "2017-06-09 open Assets:💵 💵"
    private let specialCharacterClosingString = "2017-06-09 close Assets:💵"

    private let invalidCloseWithCommodityString = "2017-06-09 close Assets:Cash CAD"
    private let invalidCloseDateString = "2017-02-30 close Assets:Cash CAD"

    private let commodityWithSemicolonOpeningString = "2017-06-09 open Assets:Cash EUR;test ;gfsd"
    private let commodityWithSemicolonClosingString = "2017-06-09 close Assets:Cash ;gfsd"

    private let invalidNameOpeningString = "2017-06-09 open Assets::Cash"

    private let bookingMethodStrictOpeningString = "2017-06-09 open Assets:Cash EUR;test \"STRICT\" ;gfsd" // Commodity with Semicolon
    private let bookingMethodLifoOpeningString = "2017-06-09    open    Assets:Cash    EUR      \"LIFO\"     ;gfsd" // Whitespace
    private let bookingMethodFifoOpeningString = "2017-06-09 open Assets:Cash 💵 \"FIFO\" ;gfsd" // Special Character
    private let bookingMethodClosingString = "2017-06-09 close Assets:Cash ;gfsd"
    private let bookingMethodInClosingString = "2017-06-09 close Assets:Cash \"FIFO\" ;gfsd"

    func testBasic() {
        testWith(openingString: basicOpeningString, closingString: basicClosingString, commoditySymbol: nil)
    }

    func testInvalidName() {
        let account = AccountParser.parseFrom(line: invalidNameOpeningString)
        XCTAssertNil(account)
    }

    func testWhitespace() {
        testWith(openingString: whitespaceOpeningString, closingString: whitespaceClosingString, commoditySymbol: "CAD")
    }

    func testEndOfLineComment() {
        testWith(openingString: endOfLineCommentOpeningString, closingString: endOfLineCommentClosingString, commoditySymbol: "EUR")
    }

    func testSpecialCharacter() {
        testWith(openingString: specialCharacterOpeningString, closingString: specialCharacterClosingString, commoditySymbol: "💵")
    }

    func testInvalidCloseWithCommodity() {
        XCTAssertNil(AccountParser.parseFrom(line: invalidCloseWithCommodityString))
    }

    func testInvalidCloseDate() {
        XCTAssertNil(AccountParser.parseFrom(line: invalidCloseDateString))
    }

    func testCommodityWithSemicolon() {
        testWith(openingString: commodityWithSemicolonOpeningString, closingString: commodityWithSemicolonClosingString, commoditySymbol: "EUR;test")
    }

    func testBookingMethodStrict() {
        testWith(openingString: bookingMethodStrictOpeningString, closingString: bookingMethodClosingString, commoditySymbol: "EUR;test", bookingMethod: .strict)
    }

    func testBookingMethodLifo() {
        testWith(openingString: bookingMethodLifoOpeningString, closingString: bookingMethodClosingString, commoditySymbol: "EUR", bookingMethod: .lifo)
    }

    func testBookingMethodFifo() {
        testWith(openingString: bookingMethodFifoOpeningString, closingString: bookingMethodClosingString, commoditySymbol: "💵", bookingMethod: .fifo)
    }

    func testBookingMethodInClosingString() {
        let account = AccountParser.parseFrom(line: bookingMethodInClosingString)
        XCTAssertNil(account)
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = AccountParser.parseFrom(line: basicOpeningString)
                _ = AccountParser.parseFrom(line: basicClosingString)

                _ = AccountParser.parseFrom(line: whitespaceOpeningString)
                _ = AccountParser.parseFrom(line: whitespaceClosingString)

                _ = AccountParser.parseFrom(line: endOfLineCommentOpeningString)
                _ = AccountParser.parseFrom(line: endOfLineCommentClosingString)

                _ = AccountParser.parseFrom(line: specialCharacterOpeningString)
                _ = AccountParser.parseFrom(line: specialCharacterClosingString)
            }
        }
    }

    // Helper
    private func testWith(openingString: String, closingString: String, commoditySymbol: CommoditySymbol?, bookingMethod: BookingMethod? = nil) {
        let account1 = AccountParser.parseFrom(line: openingString)

        XCTAssertNotNil(account1)
        XCTAssertEqual(account1!.opening!, TestUtils.date20170609)
        XCTAssertNil(account1!.closing)
        XCTAssertEqual(account1!.commoditySymbol, commoditySymbol)

        if let bookingMethod = bookingMethod {
            XCTAssertEqual(account1!.bookingMethod, bookingMethod)
        }

        let account2 = AccountParser.parseFrom(line: closingString)
        XCTAssertNotNil(account2)
        XCTAssertNil(account2!.opening)
        XCTAssertEqual(account2!.closing!, TestUtils.date20170609)
    }

}
