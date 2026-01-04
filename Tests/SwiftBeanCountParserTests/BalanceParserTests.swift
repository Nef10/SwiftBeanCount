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

final class BalanceParserTests: XCTestCase {

    private let basicString = "2017-06-09 balance Assets:Cash 10.00 CAD"
    private let whitespaceString = "2017-06-09    balance    Assets:Cash     10.00      CAD"
    private let endOfLineCommentString = "2017-06-09 balance Assets:Cash 10.00 CAD ;gfsdt     "
    private let specialCharacterString = "2017-06-09 balance Assets:💵 10.00 💵"
    private let invalidDateString = "2017-02-30 balance Assets:Cash 10.00 CAD"
    private let accountName = try! AccountName("Assets:Cash") // swiftlint:disable:this force_try

    func testBasic() {
        let balance = BalanceParser.parseFrom(line: basicString)
        XCTAssertEqual(balance, Balance(date: TestUtils.date20170609,
                                        accountName: accountName,
                                        amount: Amount(number: 10, commoditySymbol: "CAD", decimalDigits: 2)))
    }

    func testWhitespace() {
        let balance = BalanceParser.parseFrom(line: whitespaceString)
        XCTAssertEqual(balance, Balance(date: TestUtils.date20170609,
                                        accountName: accountName,
                                        amount: Amount(number: 10, commoditySymbol: "CAD", decimalDigits: 2)))
    }

    func testEndOfLineComment() {
        let balance = BalanceParser.parseFrom(line: endOfLineCommentString)
        XCTAssertEqual(balance, Balance(date: TestUtils.date20170609,
                                        accountName: accountName,
                                        amount: Amount(number: 10, commoditySymbol: "CAD", decimalDigits: 2)))
    }

    func testSpecialCharacter() throws {
        let balance = BalanceParser.parseFrom(line: specialCharacterString)
        XCTAssertEqual(balance, Balance(date: TestUtils.date20170609,
                                        accountName: try AccountName("Assets:💵"),
                                        amount: Amount(number: 10, commoditySymbol: "💵", decimalDigits: 2)))
    }

    func testInvalidCloseDate() {
        let balance = BalanceParser.parseFrom(line: invalidDateString)
        XCTAssertNil(balance)
    }

    func testPerformance() {
        measure {
            for _ in 0...1_000 {
                _ = BalanceParser.parseFrom(line: basicString)
                _ = BalanceParser.parseFrom(line: whitespaceString)
                _ = BalanceParser.parseFrom(line: endOfLineCommentString)
                _ = BalanceParser.parseFrom(line: specialCharacterString)
            }
        }
    }

}
