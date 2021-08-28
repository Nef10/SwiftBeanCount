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

    func testSettingsName() {
        XCTAssertEqual(BaseImporter.settingsName, "")
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

    func testSettings() {
        let settings = BaseImporter.settings
        XCTAssertEqual(settings.count, 1)
        XCTAssertEqual(settings[0].identifier, BaseImporter.accountsSetting.identifier)
        XCTAssertEqual(settings[0].name, BaseImporter.accountsSetting.name)
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
        let importer = BaseImporter(ledger: TestUtils.ledger)
        let key = BaseImporter.getUserDefaultsKey(for: BaseImporter.accountsSetting)

        UserDefaults.standard.removeObject(forKey: key)
        var possibleAccountNames = importer.possibleAccountNames(for: nil)
        XCTAssertEqual(possibleAccountNames.count, 0)

        UserDefaults.standard.set(TestUtils.cash.fullName, forKey: key)
        possibleAccountNames = importer.possibleAccountNames(for: nil)
        XCTAssertEqual(possibleAccountNames.count, 1)
        XCTAssertEqual(possibleAccountNames[0], TestUtils.cash)

        UserDefaults.standard.set("\(TestUtils.cash.fullName), \(TestUtils.chequing.fullName)", forKey: key)
        possibleAccountNames = importer.possibleAccountNames(for: nil)
        XCTAssertEqual(possibleAccountNames.count, 2)
        XCTAssertTrue(possibleAccountNames.contains(TestUtils.cash))
        XCTAssertTrue(possibleAccountNames.contains(TestUtils.chequing))

        // When account is set returns exactly this one
        importer.useAccount(name: TestUtils.cash)
        possibleAccountNames = importer.possibleAccountNames(for: nil)
        XCTAssertEqual(possibleAccountNames.count, 1)
        XCTAssertEqual(possibleAccountNames[0], TestUtils.cash)

        UserDefaults.standard.removeObject(forKey: key)
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
