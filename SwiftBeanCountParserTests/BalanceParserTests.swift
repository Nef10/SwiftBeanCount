//
//  BalanceParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-07-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class BalanceParserTests: XCTestCase {

    let basicString = "2017-06-09 balance Assets:Cash 10.00 CAD"
    let whitespaceString = "2017-06-09    balance    Assets:Cash     10.00      CAD"
    let endOfLineCommentString = "2017-06-09 balance Assets:Cash 10.00 CAD ;gfsdt     "
    let specialCharacterString = "2017-06-09 balance Assets:💵 10.00 💵"
    let invalidDateString = "2017-02-30 balance Assets:Cash 10.00 CAD"
    let accountName = try! AccountName("Assets:Cash")

    func testBasic() {
        let balance = BalanceParser.parseFrom(line: basicString)
        XCTAssertEqual(balance, Balance(date: TestUtils.date20170609,
                                        accountName: accountName,
                                        amount: Amount(number: 10, commodity: Commodity(symbol: "CAD"), decimalDigits: 2)))
    }

    func testWhitespace() {
        let balance = BalanceParser.parseFrom(line: whitespaceString)
        XCTAssertEqual(balance, Balance(date: TestUtils.date20170609,
                                        accountName: accountName,
                                        amount: Amount(number: 10, commodity: Commodity(symbol: "CAD"), decimalDigits: 2)))
    }

    func testEndOfLineComment() {
        let balance = BalanceParser.parseFrom(line: endOfLineCommentString)
        XCTAssertEqual(balance, Balance(date: TestUtils.date20170609,
                                        accountName: accountName,
                                        amount: Amount(number: 10, commodity: Commodity(symbol: "CAD"), decimalDigits: 2)))
    }

    func testSpecialCharacter() {
        let balance = BalanceParser.parseFrom(line: specialCharacterString)
        XCTAssertEqual(balance, Balance(date: TestUtils.date20170609,
                                        accountName: try! AccountName("Assets:💵"),
                                        amount: Amount(number: 10, commodity: Commodity(symbol: "💵"), decimalDigits: 2)))
    }

    func testInvalidCloseDate() {
        let balance = BalanceParser.parseFrom(line: invalidDateString)
        XCTAssertNil(balance)
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = BalanceParser.parseFrom(line: basicString)
                _ = BalanceParser.parseFrom(line: whitespaceString)
                _ = BalanceParser.parseFrom(line: endOfLineCommentString)
                _ = BalanceParser.parseFrom(line: specialCharacterString)
            }
        }
    }

}
