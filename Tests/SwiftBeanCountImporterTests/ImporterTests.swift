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

final class ImporterTests: XCTestCase {

    func testAllImporters() {
        XCTAssertEqual(ImporterFactory.allImporters.count, (FileImporterFactory.importers + TextImporterFactory.importers + DownloadImporterFactory.importers).count)
    }

    func testNoEqualImporterNames() {
        var names = [String]()
        let importers = ImporterFactory.allImporters
        for importer in importers {
            guard !names.contains(importer.importerName) else {
                XCTFail("Importers cannot use the same name")
                return
            }
            names.append(importer.importerName)
        }
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

    func testDownloadImporter() {
        let importers = DownloadImporterFactory.importers
        for importer in importers {
            XCTAssertTrue(type(of: ImporterFactory.new(ledger: nil, name: importer.importerName)!) == importer)
        }
    }

    func testDownloadImporterNames() {
        XCTAssertEqual(ImporterFactory.downloadImporterNames, DownloadImporterFactory.importers.map { $0.importerName })
    }

    func testImportedTransactionSaveMapped() {
        let originalDescription = "abcd"
        let description = "ab"
        let payee = "ef"
        let accountName = TestUtils.cash
        Settings.storage = TestStorage()

        // Does not save if originalDescription is an empty string
        var importedTransaction = ImportedTransaction(TestUtils.transaction, originalDescription: "", shouldAllowUserToEdit: true)
        importedTransaction.saveMapped(description: description, payee: payee, accountName: accountName)

        XCTAssert(Settings.allDescriptionMappings.isEmpty)
        XCTAssert(Settings.allPayeeMappings.isEmpty)
        XCTAssert(Settings.allAccountMappings.isEmpty)

        // Saves otherwise
        importedTransaction = ImportedTransaction(TestUtils.transaction, originalDescription: originalDescription, shouldAllowUserToEdit: true)
        importedTransaction.saveMapped(description: description, payee: payee, accountName: accountName)

        XCTAssertEqual(Settings.allDescriptionMappings, [originalDescription: description])
        XCTAssertEqual(Settings.allPayeeMappings, [originalDescription: payee])
        XCTAssertEqual(Settings.allAccountMappings, [payee: accountName.fullName])

    }

}
