//
//  TransactionMetaDataTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-18.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

final class TransactionMetaDataTests: XCTestCase {

    private let payee = "Payee"
    private let narration = "Narration"
    private let flag = Flag.complete
    private let date = TestUtils.date20170608
    private let dateString = "2017-06-08"
    private var transactionMetaData: TransactionMetaData?

    override func setUp() {
        super.setUp()
        transactionMetaData = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [])
    }

    func testDescription() {
        XCTAssertEqual(String(describing: transactionMetaData!), "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\"")
    }

    func testDescriptionMetaData() {
        let transactionMetaData = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [], metaData: ["A": "B"])
        XCTAssertEqual(String(describing: transactionMetaData), "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\"\n  A: \"B\"")
    }

    func testDescriptionSpecialCharacters() {
        let payee = "🏫"
        let narration = "🎓"
        let transactionMetaData = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [])
        XCTAssertEqual(String(describing: transactionMetaData), "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\"")
    }

    func testDescriptionTag() {
        let tag = Tag(name: "🎁")
        let transactionMetaData = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [tag])
        XCTAssertEqual(String(describing: transactionMetaData), "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\" \(String(describing: tag))")
    }

    func testDescriptionTags() {
        let tag1 = Tag(name: "tag1")
        let tag2 = Tag(name: "tag2")
        let transactionMetaData = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [tag1, tag2])
        XCTAssertEqual(String(describing: transactionMetaData),
                       "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\" \(String(describing: tag1)) \(String(describing: tag2))")
    }

    func testEqual() {
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [])
        XCTAssertEqual(transactionMetaData, transactionMetaData1)
    }

    func testEqualWithTags() {
        let tag1 = Tag(name: "tag1")
        let tag2 = Tag(name: "tag2")
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [tag1, tag2])
        let transactionMetaData2 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [tag1, tag2])
        XCTAssertEqual(transactionMetaData1, transactionMetaData2)
    }

    func testEqualRespectsMetaData() {
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [], metaData: ["A": "B"])
        XCTAssertNotEqual(transactionMetaData, transactionMetaData1)
    }

    func testEqualRespectsDate() {
        let transactionMetaData1 = TransactionMetaData(date: date.addingTimeInterval(TimeInterval(1)), payee: payee, narration: narration, flag: flag, tags: [])
        XCTAssertNotEqual(transactionMetaData, transactionMetaData1)
    }

    func testEqualRespectsPayee() {
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee + "1", narration: narration, flag: flag, tags: [])
        XCTAssertNotEqual(transactionMetaData, transactionMetaData1)
    }

    func testEqualRespectsNarration() {
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration + "1", flag: flag, tags: [])
        XCTAssertNotEqual(transactionMetaData, transactionMetaData1)
    }

    func testEqualRespectsTags() {
        let tag1 = Tag(name: "tag1")
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: Flag.incomplete, tags: [tag1])
        XCTAssertNotEqual(transactionMetaData, transactionMetaData1)
    }

}
