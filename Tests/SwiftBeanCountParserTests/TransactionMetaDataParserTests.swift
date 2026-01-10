//
//  TransactionMetaDataParserTests.swift
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

struct TransactionMetaDataParserTests {

    private let basicTransactionMetaDataString = "2017-06-09 * \"Payee\" \"Narration\""
    private let whitespaceTransactionMetaDataString = "2017-06-09   *    \"Payee\"   \"Narration\""
    private let endOfLineCommentTransactionMetaDataString = "2017-06-09 * \"Payee\" \"Narration\" ;TESTgfdsgds      "
    private let specialCharacterTransactionMetaDataString = "2017-06-09 * \"öøuß´@🇩🇪🇨🇦💵\" \"🎉😊💵Test⚅℃⁒♾\" #🇨🇦"
    private let incompleteTransactionMetaDataString = "2017-06-09 ! \"Payee\" \"Narration\""
    private let tagsTransactionMetaDataString = "2017-06-09 * \"Payee\" \"Narration\" #1 #two"
    private let invalidDateTransactionMetaDataString = "2017-02-30 * \"Payee\" \"Narration\""

   @Test
   func testBasic() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: basicTransactionMetaDataString)!
        assertBasicTransactionMetaData(transactionMetaData)
    }

   @Test
   func testWhitespace() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: whitespaceTransactionMetaDataString)!
        assertBasicTransactionMetaData(transactionMetaData)
    }

   @Test
   func testEndOfLineCommentTransactionMetaDataString() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: endOfLineCommentTransactionMetaDataString)!
        assertBasicTransactionMetaData(transactionMetaData)
    }

   @Test
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

   @Test
   func testIncompleteTransactionMetaDataString() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: incompleteTransactionMetaDataString)!
        #expect(transactionMetaData.narration == "Narration")
        #expect(transactionMetaData.payee == "Payee")
        #expect(transactionMetaData.flag == Flag.incomplete)
        #expect(transactionMetaData.date == TestUtils.date20170609)
        #expect(transactionMetaData.tags.isEmpty)
        #expect(String(describing: transactionMetaData) == incompleteTransactionMetaDataString)
    }

   @Test
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

   @Test
   func testInvalidDate() {
        #expect(TransactionMetaDataParser.parseFrom(line: invalidDateTransactionMetaDataString == nil))
    }

   @Test
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
        #expect(transactionMetaData.tags.isEmpty)
        #expect(transactionMetaData.date == TestUtils.date20170609)
        #expect(String(describing: transactionMetaData) == basicTransactionMetaDataString)
    }

}
