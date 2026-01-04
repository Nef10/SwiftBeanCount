//
//  TransactionMetaDataParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-09.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

final class TransactionMetaDataParserTests: XCTestCase {

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
        XCTAssertEqual(transactionMetaData.narration, "🎉😊💵Test⚅℃⁒♾")
        XCTAssertEqual(transactionMetaData.payee, "öøuß´@🇩🇪🇨🇦💵")
        XCTAssertEqual(transactionMetaData.flag, Flag.complete)
        XCTAssertEqual(transactionMetaData.date, TestUtils.date20170609)
        XCTAssertEqual(transactionMetaData.tags.count, 1)
        XCTAssertEqual(transactionMetaData.tags[0].name, "🇨🇦")
        XCTAssertEqual(String(describing: transactionMetaData), specialCharacterTransactionMetaDataString)
    }

    func testIncompleteTransactionMetaDataString() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: incompleteTransactionMetaDataString)!
        XCTAssertEqual(transactionMetaData.narration, "Narration")
        XCTAssertEqual(transactionMetaData.payee, "Payee")
        XCTAssertEqual(transactionMetaData.flag, Flag.incomplete)
        XCTAssertEqual(transactionMetaData.date, TestUtils.date20170609)
        XCTAssertEqual(transactionMetaData.tags.count, 0)
        XCTAssertEqual(String(describing: transactionMetaData), incompleteTransactionMetaDataString)
    }

    func testTags() {
        let transactionMetaData = TransactionMetaDataParser.parseFrom(line: tagsTransactionMetaDataString)!
        XCTAssertEqual(transactionMetaData.narration, "Narration")
        XCTAssertEqual(transactionMetaData.payee, "Payee")
        XCTAssertEqual(transactionMetaData.flag, Flag.complete)
        XCTAssertEqual(transactionMetaData.date, TestUtils.date20170609)
        XCTAssertEqual(transactionMetaData.tags.count, 2)
        XCTAssertEqual(transactionMetaData.tags[0].name, "1")
        XCTAssertEqual(transactionMetaData.tags[1].name, "two")
        XCTAssertEqual(String(describing: transactionMetaData), tagsTransactionMetaDataString)
    }

    func testInvalidDate() {
        XCTAssertNil(TransactionMetaDataParser.parseFrom(line: invalidDateTransactionMetaDataString))
    }

    func testPerformance() {
        measure {
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
        XCTAssertEqual(transactionMetaData.narration, "Narration")
        XCTAssertEqual(transactionMetaData.payee, "Payee")
        XCTAssertEqual(transactionMetaData.flag, Flag.complete)
        XCTAssertEqual(transactionMetaData.tags.count, 0)
        XCTAssertEqual(transactionMetaData.date, TestUtils.date20170609)
        XCTAssertEqual(String(describing: transactionMetaData), basicTransactionMetaDataString)
    }

}
