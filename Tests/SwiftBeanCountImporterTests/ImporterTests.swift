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
import Testing

@Suite
struct ImporterTests {

   @Test
   func testAllImporters() {
        #expect(ImporterFactory.allImporters.count == (FileImporterFactory.importers + TextImporterFactory.importers + DownloadImporterFactory.importers).count)
    }

   @Test
   func testNoEqualImporterNames() {
        var names = [String]()
        let importers = ImporterFactory.allImporters
        for importer in importers {
            guard !names.contains(importer.importerName) else {
                Issue.record("Importers cannot use the same name")
                return
            }
            names.append(importer.importerName)
        }
    }

   @Test
   func testFileImporter() {
        // no url
        #expect(ImporterFactory.new(ledger: nil, url: nil) == nil)

        // invalid URL
        #expect(ImporterFactory.new(ledger: nil, url: URL(fileURLWithPath: "DOES_NOT_EXIST" == nil)))

        // valid URL without matching headers
        let url = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "Header, no, matching, anything\n")
        #expect(ImporterFactory.new(ledger: nil, url: url == nil))

        // matching header
        let importers = CSVImporterFactory.importers
        for importer in importers {
            for header in importer.headers {
                let url = TestUtils.temporaryFileURL()
                TestUtils.createFile(at: url, content: "\(header.joined(separator: ", "))\n")
                #expect(type(of: ImporterFactory.new(ledger: nil, url: url)!) == importer)
            }
        }
    }

   @Test
   func testTextImporter() {
        let result = ImporterFactory.new(ledger: nil, transaction: "", balance: "")
        #expect(result != nil)
        #expect(result is ManuLifeImporter)
    }

   @Test
   func testDownloadImporter() {
        let importers = DownloadImporterFactory.importers
        for importer in importers {
            #expect(type(of: ImporterFactory.new(ledger: nil, name: importer.importerName)!) == importer)
        }
    }

   @Test
   func testDownloadImporterNames() {
        // see https://github.com/realm/SwiftLint/issues/5831
        // swiftlint:disable:next prefer_key_path
        #expect(ImporterFactory.downloadImporterNames == DownloadImporterFactory.importers.map { $0.importerName })
    }

   @Test
   func testImportedTransactionSaveMapped() {
        let originalDescription = "abcd"
        let description = "ab"
        let payee = "ef"
        let accountName = TestUtils.cash
        Settings.storage = TestStorage()

        // Does not save if originalDescription is an empty string
        var importedTransaction = ImportedTransaction(TestUtils.transaction, originalDescription: "", shouldAllowUserToEdit: true)
        importedTransaction.saveMapped(description: description, payee: payee, accountName: accountName)

        #expect(Settings.allDescriptionMappings.isEmpty)
        #expect(Settings.allPayeeMappings.isEmpty)
        #expect(Settings.allAccountMappings.isEmpty)

        // Saves otherwise
        importedTransaction = ImportedTransaction(TestUtils.transaction, originalDescription: originalDescription, shouldAllowUserToEdit: true)
        importedTransaction.saveMapped(description: description, payee: payee, accountName: accountName)

        #expect(Settings.allDescriptionMappings == [originalDescription: description])
        #expect(Settings.allPayeeMappings == [originalDescription: payee])
        #expect(Settings.allAccountMappings == [payee: accountName.fullName])

    }

}
