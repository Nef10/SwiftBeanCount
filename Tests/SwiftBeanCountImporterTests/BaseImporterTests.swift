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

}
