//
//  BalanceParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-07-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import Testing

@Suite
struct BalanceParserTests {

    private let basicString = "2017-06-09 balance Assets:Cash 10.00 CAD"
    private let whitespaceString = "2017-06-09    balance    Assets:Cash     10.00      CAD"
    private let endOfLineCommentString = "2017-06-09 balance Assets:Cash 10.00 CAD ;gfsdt     "
    private let specialCharacterString = "2017-06-09 balance Assets:💵 10.00 💵"
    private let invalidDateString = "2017-02-30 balance Assets:Cash 10.00 CAD"
    private let accountName = try! AccountName("Assets:Cash") // swiftlint:disable:this force_try

    @Test
    func basic() {
        let balance = BalanceParser.parseFrom(line: basicString)
        #expect(balance == Balance(date: TestUtils.date20170609,
                                   accountName: accountName,
                                   amount: Amount(number: 10, commoditySymbol: "CAD", decimalDigits: 2)))
    }

    @Test
    func whitespace() {
        let balance = BalanceParser.parseFrom(line: whitespaceString)
        #expect(balance == Balance(date: TestUtils.date20170609,
                                   accountName: accountName,
                                   amount: Amount(number: 10, commoditySymbol: "CAD", decimalDigits: 2)))
    }

    @Test
    func endOfLineComment() {
        let balance = BalanceParser.parseFrom(line: endOfLineCommentString)
        #expect(balance == Balance(date: TestUtils.date20170609,
                                   accountName: accountName,
                                   amount: Amount(number: 10, commoditySymbol: "CAD", decimalDigits: 2)))
    }

    @Test
    func specialCharacter() throws {
        let balance = BalanceParser.parseFrom(line: specialCharacterString)
        #expect(balance == Balance(date: TestUtils.date20170609,
                                   accountName: try AccountName("Assets:💵"),
                                   amount: Amount(number: 10, commoditySymbol: "💵", decimalDigits: 2)))
    }

    @Test
    func invalidCloseDate() {
        let balance = BalanceParser.parseFrom(line: invalidDateString)
        #expect(balance == nil)
    }

}
