//
//  TransactionMetaDataParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-09.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountParser
import SwiftBeanCountModel
import Testing

@Suite

struct TransactionMetaDataParserTests {

    private let basicTransactionMetaDataString = "2017-06-09 * \"Payee\" \"Narration\""
    private let whitespaceTransactionMetaDataString = "2017-06-09   *    \"Payee\"   \"Narration\""
    private let endOfLineCommentTransactionMetaDataString = "2017-06-09 * \"Payee\" \"Narration\" ;TESTgfdsgds      "
    private let specialCharacterTransactionMetaDataString = "2017-06-09 * \"öøuß´@🇩🇪🇨🇦💵\" \"🎉😊💵Test⚅℃⁒♾\" #🇨🇦"
    private let incompleteTransactionMetaDataString = "2017-06-09 ! \"Payee\" \"Narration\""
    private let tagsTransactionMetaDataString = "2017-06-09 * \"Payee\" \"Narration\" #1 #two"
    private let invalidDateTransactionMetaDataString = "2017-02-30 * \"Payee\" \"Narration\""

    func testBasic() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: basicTransactionMetaDataString)!
        assertBasicTransactionMetaData(transactionMetaData)
    }

    func testWhitespace() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: whitespaceTransactionMetaDataString)!
        assertBasicTransactionMetaData(transactionMetaData)
    }

    func testEndOfLineCommentTransactionMetaDataString() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: endOfLineCommentTransactionMetaDataString)!
        assertBasicTransactionMetaData(transactionMetaData)
    }

    func testSpecialCharacterTransactionMetaDataString() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: specialCharacterTransactionMetaDataString)!
        #expect(transactionMetaData.narration == "🎉😊💵Test⚅℃⁒♾")
        #expect(transactionMetaData.payee == "öøuß´@🇩🇪🇨🇦💵")
        #expect(transactionMetaData.flag == Flag.complete)
        #expect(transactionMetaData.date == TestUtils.date20170609)
        #expect(transactionMetaData.tags.count == 1)
        #expect(transactionMetaData.tags[0].name == "🇨🇦")
        #expect(String(describing: transactionMetaData) == specialCharacterTransactionMetaDataString)
    }

    func testIncompleteTransactionMetaDataString() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: incompleteTransactionMetaDataString)!
        #expect(transactionMetaData.narration == "Narration")
        #expect(transactionMetaData.payee == "Payee")
        #expect(transactionMetaData.flag == Flag.incomplete)
        #expect(transactionMetaData.date == TestUtils.date20170609)
        #expect(transactionMetaData.tags.count == 0)
        #expect(String(describing: transactionMetaData) == incompleteTransactionMetaDataString)
    }

    func testTags() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: tagsTransactionMetaDataString)!
        #expect(transactionMetaData.narration == "Narration")
        #expect(transactionMetaData.payee == "Payee")
        #expect(transactionMetaData.flag == Flag.complete)
        #expect(transactionMetaData.date == TestUtils.date20170609)
        #expect(transactionMetaData.tags.count == 2)
        #expect(transactionMetaData.tags[0].name == "1")
        #expect(transactionMetaData.tags[1].name == "two")
        #expect(String(describing: transactionMetaData) == tagsTransactionMetaDataString)
    }

    func testInvalidDate() {
        #expect(TransactionMetaDataParser.parseFrom(line: invalidDateTransactionMetaDataString == nil))
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = TransactionMetaDataParser.parseFrom(line: basicTransactionMetaDataString)!
                _ = TransactionMetaDataParser.parseFrom(line: whitespaceTransactionMetaDataString)!
                _ = TransactionMetaDataParser.parseFrom(line: endOfLineCommentTransactionMetaDataString)!
                _ = TransactionMetaDataParser.parseFrom(line: specialCharacterTransactionMetaDataString)!
            }
        }
    }

    // Helper

    private func assertBasicTransactionMetaData(_ transactionMetaData: TransactionMetaData) {
        #expect(transactionMetaData.narration == "Narration")
        #expect(transactionMetaData.payee == "Payee")
        #expect(transactionMetaData.flag == Flag.complete)
        #expect(transactionMetaData.tags.count == 0)
        #expect(transactionMetaData.date == TestUtils.date20170609)
        #expect(String(describing: transactionMetaData) == basicTransactionMetaDataString)
    }

}
