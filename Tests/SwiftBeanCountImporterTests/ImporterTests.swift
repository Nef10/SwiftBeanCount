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

    func testAllImporters() {
        XCTAssertEqual(ImporterFactory.allImporters.count, (FileImporterFactory.importers + TextImporterFactory.importers).count)
    }

    func testFileImporter() {
        // no url
        XCTAssertNil(ImporterFactory.new(ledger: nil, url: nil))

        // invalid URL
        XCTAssertNil(ImporterFactory.new(ledger: nil, url: URL(fileURLWithPath: "DOES_NOT_EXIST")))

        // valid URL without matching headers
        let url = temporaryFileURL()
        createFile(at: url, content: "Header, no, matching, anything\n")
        XCTAssertNil(ImporterFactory.new(ledger: nil, url: url))

        // matching header
        let importers = CSVImporterFactory.importers
        for importer in importers {
            for header in importer.headers {
                let url = temporaryFileURL()
                createFile(at: url, content: "\(header.joined(separator: ", "))\n")
                XCTAssertTrue(type(of: ImporterFactory.new(ledger: nil, url: url)!) == importer)
            }
        }
    }

     func testTextImporter() {
        let result = ImporterFactory.new(ledger: nil, transaction: "", balance: "")
        XCTAssertNotNil(result)
        XCTAssertTrue(result is ManuLifeImporter)
    }

    func testSettings() {
        let value = "GFDSGFD"
        TestImporter.set(setting: TestImporter.setting, to: value)
        XCTAssertEqual(TestImporter.get(setting: TestImporter.setting), value)
        let key = TestImporter.getUserDefaultsKey(for: TestImporter.setting)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), value)
    }

}
