//
//  ImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//
import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

private class TestImporter: Importer {

    static let setting = ImporterSetting(identifier: "accounts", name: "Account(s)")

    class var settingsName: String { "" }
    class var settings: [ImporterSetting] { [] }

    func possibleAccountNames(for ledger: Ledger?) -> [AccountName] {
        []
    }

    func useAccount(name: AccountName) {
    }

}

final class ImporterTests: XCTestCase {

    func testImporters() {
        XCTAssertEqual(ImporterManager.importers.count, (FileImporterManager.importers + TextImporterManager.importers).count)
    }

    func testSettings() {
        let value = "GFDSGFD"
        TestImporter.set(setting: TestImporter.setting, to: value)
        XCTAssertEqual(TestImporter.get(setting: TestImporter.setting), value)
        let key = TestImporter.getUserDefaultsKey(for: TestImporter.setting)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), value)
    }

}
