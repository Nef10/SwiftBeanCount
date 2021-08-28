//
//  BaseImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class BaseImporterTests: XCTestCase {

    func testInit() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        XCTAssertEqual(importer.ledger, TestUtils.ledger)
    }

    func testImporterType() {
        XCTAssertEqual(BaseImporter.importerType, "")
    }

    func testLoad() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        importer.load()
    }

    func testImportName() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        XCTAssertEqual(importer.importName, "")
    }

    func testNextTransaction() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        XCTAssertNil(importer.nextTransaction())
    }

    func testBalancesToImport() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        XCTAssertTrue(importer.balancesToImport().isEmpty)
    }

    func testPricesToImport() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        XCTAssertTrue(importer.pricesToImport().isEmpty)
    }

    func testCommoditySymbol() {
        var importer = BaseImporter(ledger: TestUtils.ledger)
        XCTAssertEqual(importer.commoditySymbol, Settings.fallbackCommodity)

        importer = BaseImporter(ledger: TestUtils.ledgerCashUSD)
        importer.useAccount(name: TestUtils.cash)
        XCTAssertEqual(importer.commoditySymbol, TestUtils.usd)
    }

    func testUseAccount() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        XCTAssertNil(importer.accountName)

        importer.useAccount(name: TestUtils.cash)
        XCTAssertEqual(importer.accountName, TestUtils.cash)
    }

    func testPossibleAccountNames() {
        let ledger = TestUtils.ledger
        var importer = BaseImporter(ledger: ledger)
        var possibleAccountNames = importer.possibleAccountNames()
        XCTAssertEqual(possibleAccountNames.count, 0)

        var account = Account(name: TestUtils.cash, commoditySymbol: TestUtils.usd, metaData: [Settings.importerTypeKey: ""])
        try! ledger.add(account)
        importer = BaseImporter(ledger: ledger)
        possibleAccountNames = importer.possibleAccountNames()
        XCTAssertEqual(possibleAccountNames.count, 1)
        XCTAssertEqual(possibleAccountNames[0], TestUtils.cash)

        account = Account(name: TestUtils.chequing, commoditySymbol: TestUtils.usd, metaData: [Settings.importerTypeKey: ""])
        try! ledger.add(account)
        importer = BaseImporter(ledger: ledger)
        possibleAccountNames = importer.possibleAccountNames()
        XCTAssertEqual(possibleAccountNames.count, 2)
        XCTAssertTrue(possibleAccountNames.contains(TestUtils.cash))
        XCTAssertTrue(possibleAccountNames.contains(TestUtils.chequing))

        // When account is set returns exactly this one
        importer.useAccount(name: TestUtils.cash)
        possibleAccountNames = importer.possibleAccountNames()
        XCTAssertEqual(possibleAccountNames.count, 1)
        XCTAssertEqual(possibleAccountNames[0], TestUtils.cash)
    }

    func testSavedPayee() {
        let description = "abcd"
        let payeeMapping = "efg"
        Settings.storage = TestStorage()

        Settings.setPayeeMapping(key: description, payee: payeeMapping)
        let importer = BaseImporter(ledger: TestUtils.ledger)
        let (_, savedPayee) = importer.savedDescriptionAndPayeeFor(description: description)
        XCTAssertEqual(savedPayee, payeeMapping)
    }

    func testSavedDescription() {
        let description = "abcd"
        let descriptionMapping = "efg"
        Settings.storage = TestStorage()

        Settings.setDescriptionMapping(key: description, description: descriptionMapping)
        let importer = BaseImporter(ledger: TestUtils.ledger)
        let (savedDescription, _) = importer.savedDescriptionAndPayeeFor(description: description)
        XCTAssertEqual(savedDescription, descriptionMapping)
    }

    func testSavedAccount() {
        let payee = "abcd"
        Settings.storage = TestStorage()

        Settings.setAccountMapping(key: payee, account: TestUtils.chequing.fullName)
        let importer = BaseImporter(ledger: TestUtils.ledger)
        XCTAssertEqual(importer.savedAccountNameFor(payee: payee), TestUtils.chequing)
    }

    func testGetPossibleDuplicateFor() {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = BaseImporter(ledger: ledger)
        XCTAssertEqual(importer.getPossibleDuplicateFor(transaction), transaction)
    }

    func testGetPossibleDuplicateForDateToleranceInside() {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = BaseImporter(ledger: ledger)

        var importedTransactionMetaData = TransactionMetaData(date: transaction.metaData.date - Settings.dateTolerance,
                                                              payee: "",
                                                              narration: "",
                                                              flag: transaction.metaData.flag,
                                                              tags: [])
        var importedTransaction = Transaction(metaData: importedTransactionMetaData, postings: transaction.postings)

        XCTAssertEqual(importer.getPossibleDuplicateFor(importedTransaction), transaction)

        importedTransactionMetaData = TransactionMetaData(date: transaction.metaData.date + Settings.dateTolerance,
                                                          payee: transaction.metaData.payee,
                                                          narration: transaction.metaData.narration,
                                                          flag: transaction.metaData.flag,
                                                          tags: transaction.metaData.tags)
        importedTransaction = Transaction(metaData: importedTransactionMetaData, postings: transaction.postings)

        XCTAssertEqual(importer.getPossibleDuplicateFor(importedTransaction), transaction)
    }

    func testGetPossibleDuplicateForDateToleranceOutside() {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = BaseImporter(ledger: ledger)

        var importedTransactionMetaData = TransactionMetaData(date: transaction.metaData.date - (Settings.dateTolerance + 1),
                                                              payee: "",
                                                              narration: "",
                                                              flag: transaction.metaData.flag,
                                                              tags: [])
        var importedTransaction = Transaction(metaData: importedTransactionMetaData, postings: transaction.postings)

        XCTAssertNil(importer.getPossibleDuplicateFor(importedTransaction))

        importedTransactionMetaData = TransactionMetaData(date: transaction.metaData.date + (Settings.dateTolerance + 1),
                                                          payee: transaction.metaData.payee,
                                                          narration: transaction.metaData.narration,
                                                          flag: transaction.metaData.flag,
                                                          tags: transaction.metaData.tags)
        importedTransaction = Transaction(metaData: importedTransactionMetaData, postings: transaction.postings)

        XCTAssertNil(importer.getPossibleDuplicateFor(importedTransaction))
    }

    func testSanitizeDescription() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        XCTAssertEqual(importer.sanitize(description: "Shop1 C-IDP PURCHASE - 1234  BC  CA"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 IDP PURCHASE-1234"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 VISA DEBIT REF-1234"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 VISA DEBIT PUR-1234"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 INTERAC E-TRF- 1234"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 WWWINTERAC PUR 1234"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 1234 ~ Internet Withdrawal"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 - SAP"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 SAP"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: " SAP CANADA"), "SAP CANADA")
        XCTAssertEqual(importer.sanitize(description: "Shop1 -MAY 2014"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 - JUNE 2016"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1  BC  CA"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 #12345"), "Shop1")
        XCTAssertEqual(importer.sanitize(description: "Shop1 # 12"), "Shop1")
    }
}
