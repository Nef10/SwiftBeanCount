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
        XCTAssertFalse(AccountParser.parseFrom(line: invalidCloseWithCommodityString, for: Ledger()))
    }

    func testInvalidCloseDate() {
        XCTAssertFalse(AccountParser.parseFrom(line: invalidCloseDateString, for: Ledger()))
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                let basicLedger = Ledger()
                _ = AccountParser.parseFrom(line: basicOpeningString, for: basicLedger)
                _ = AccountParser.parseFrom(line: basicClosingString, for: basicLedger)

                let whitespaceLedger = Ledger()
                _ = AccountParser.parseFrom(line: whitespaceOpeningString, for: whitespaceLedger)
                _ = AccountParser.parseFrom(line: whitespaceClosingString, for: whitespaceLedger)

                let endOfLineCommentLedger = Ledger()
                _ = AccountParser.parseFrom(line: endOfLineCommentOpeningString, for: endOfLineCommentLedger)
                _ = AccountParser.parseFrom(line: endOfLineCommentClosingString, for: endOfLineCommentLedger)

                let specialCharacterLedger = Ledger()
                _ = AccountParser.parseFrom(line: specialCharacterOpeningString, for: specialCharacterLedger)
                _ = AccountParser.parseFrom(line: specialCharacterClosingString, for: specialCharacterLedger)
            }
        }
    }

    // Helper
    private func testWith(openingString: String, closingString: String, commodity: Commodity?) {
        let ledger = Ledger()

        XCTAssert(AccountParser.parseFrom(line: openingString, for: ledger))
        XCTAssertEqual(ledger.accounts[0].opening!, TestUtils.date20170609)
        XCTAssertEqual(ledger.accounts[0].closing, nil)
        XCTAssertEqual(ledger.accounts[0].commodity, commodity)

        XCTAssert(AccountParser.parseFrom(line: closingString, for: ledger))
        XCTAssertEqual(ledger.accounts[0].opening!, TestUtils.date20170609)
        XCTAssertEqual(ledger.accounts[0].closing!, TestUtils.date20170609)
    }

}
