//
//  TransactionMetaDataTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-18.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite
struct TransactionMetaDataTests {

    private let payee = "Payee"
    private let narration = "Narration"
    private let flag = Flag.complete
    private let date = TestUtils.date20170608
    private let dateString = "2017-06-08"
    private var transactionMetaData: TransactionMetaData

    init() {
        transactionMetaData = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [])
    }

    @Test
    func description() {
        #expect(String(describing: transactionMetaData) == "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\"")
    }

    @Test
    func descriptionMetaData() {
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [], metaData: ["A": "B"])
        #expect(String(describing: transactionMetaData1) == "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\"\n  A: \"B\"")
    }

    @Test
    func descriptionSpecialCharacters() {
        let payee = "🏫"
        let narration = "🎓"
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [])
        #expect(String(describing: transactionMetaData1) == "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\"")
    }

    @Test
    func descriptionTag() {
        let tag = Tag(name: "🎁")
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [tag])
        #expect(String(describing: transactionMetaData1) == "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\" \(String(describing: tag))")
    }

    @Test
    func descriptionTags() {
        let tag1 = Tag(name: "tag1")
        let tag2 = Tag(name: "tag2")
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [tag1, tag2])
        #expect(String(describing: transactionMetaData1)
            == "\(dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\" \(String(describing: tag1)) \(String(describing: tag2))")
    }

    @Test
    func equal() {
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [])
        #expect(transactionMetaData == transactionMetaData1)
    }

    @Test
    func equalWithTags() {
        let tag1 = Tag(name: "tag1")
        let tag2 = Tag(name: "tag2")
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [tag1, tag2])
        let transactionMetaData2 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [tag1, tag2])
        #expect(transactionMetaData1 == transactionMetaData2)
    }

    @Test
    func equalRespectsMetaData() {
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: flag, tags: [], metaData: ["A": "B"])
        #expect(transactionMetaData != transactionMetaData1)
    }

    @Test
    func equalRespectsDate() {
        let transactionMetaData1 = TransactionMetaData(date: date.addingTimeInterval(TimeInterval(1)), payee: payee, narration: narration, flag: flag, tags: [])
        #expect(transactionMetaData != transactionMetaData1)
    }

    @Test
    func equalRespectsPayee() {
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee + "1", narration: narration, flag: flag, tags: [])
        #expect(transactionMetaData != transactionMetaData1)
    }

    @Test
    func equalRespectsNarration() {
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration + "1", flag: flag, tags: [])
        #expect(transactionMetaData != transactionMetaData1)
    }

    @Test
    func equalRespectsTags() {
        let tag1 = Tag(name: "tag1")
        let transactionMetaData1 = TransactionMetaData(date: date, payee: payee, narration: narration, flag: Flag.incomplete, tags: [tag1])
        #expect(transactionMetaData != transactionMetaData1)
    }

}
