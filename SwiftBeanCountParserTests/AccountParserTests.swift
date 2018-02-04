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

    let basicOpeningString = "2017-06-09 open Assets:Cash"
    let basicClosingString = "2017-06-09 close Assets:Cash"

    let whitespaceOpeningString = "2017-06-09    open    Assets:Cash      CAD"
    let whitespaceClosingString = "2017-06-09   close      Assets:Cash"

    let endOfLineCommentOpeningString = "2017-06-09 open Assets:Cash EUR ;gfsdt     "
    let endOfLineCommentClosingString = "2017-06-09 close Assets:Cash   ;gfd "

    let specialCharacterOpeningString = "2017-06-09 open Assets:💵 💵"
    let specialCharacterClosingString = "2017-06-09 close Assets:💵"

    let invalidCloseWithCommodityString = "2017-06-09 close Assets:Cash CAD"
    let invalidCloseDateString = "2017-02-30 close Assets:Cash CAD"

    func testBasic() {
        testWith(openingString: basicOpeningString, closingString: basicClosingString, commodity: nil)
    }

    func testWhitespace() {
        testWith(openingString: whitespaceOpeningString, closingString: whitespaceClosingString, commodity: Commodity(symbol: "CAD"))
    }

    func testEndOfLineComment() {
        testWith(openingString: endOfLineCommentOpeningString, closingString: endOfLineCommentClosingString, commodity: Commodity(symbol: "EUR"))
    }

    func testSpecialCharacter() {
        testWith(openingString: specialCharacterOpeningString, closingString: specialCharacterClosingString, commodity: Commodity(symbol: "💵"))
    }

    func testInvalidCloseWithCommodity() {
        XCTAssertNil(AccountParser.parseFrom(line: invalidCloseWithCommodityString))
    }

    func testInvalidCloseDate() {
        XCTAssertNil(AccountParser.parseFrom(line: invalidCloseDateString))
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
    private func testWith(openingString: String, closingString: String, commodity: Commodity?) {
        let account1 = AccountParser.parseFrom(line: openingString)

        XCTAssertNotNil(account1)
        XCTAssertEqual(account1!.opening!, TestUtils.date20170609)
        XCTAssertNil(account1!.closing)
        XCTAssertEqual(account1!.commodity, commodity)

        let account2 = AccountParser.parseFrom(line: closingString)
        XCTAssertNotNil(account2)
        XCTAssertNil(account2!.opening)
        XCTAssertEqual(account2!.closing!, TestUtils.date20170609)
    }

}
