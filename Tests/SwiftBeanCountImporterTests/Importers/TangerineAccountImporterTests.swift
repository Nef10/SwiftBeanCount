//
//  TangerineAccountImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import Testing

@Suite
struct TangerineAccountImporterTests {

   @Test
   func testHeaders() {
        #expect(TangerineAccountImporter.headers == [["Date", "Transaction", "Name", "Memo", "Amount"]])
    }

   @Test
   func testImporterName() {
        #expect(TangerineAccountImporter.importerName == "Tangerine Accounts")
    }

   @Test
   func testImporterType() {
        #expect(TangerineAccountImporter.importerType == "tangerine-account")
    }

   @Test
   func testHelpText() {
        #expect(TangerineAccountImporter.helpText
            == "Enables importing of downloaded CSV files from Tangerine Accounts.\n\nTo use add importer-type: \"tangerine-account\" to your account.")
    }

   @Test
   func testImportName() throws {
        #expect(TangerineAccountImporter(ledger: nil, csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName ===
                       "Tangerine Account File TestName")
    }

   @Test
   func testAccountsFromLedger() {
        var importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers,
                                                csvReader: TestUtils.basicCSVReader,
                                                fileName: "Export \(TestUtils.accountNumberChequing).csv")
        var possibleAccountNames = importer.accountsFromLedger()
        #expect(possibleAccountNames.count == 1)
        #expect(possibleAccountNames[0] == TestUtils.chequing)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export \(TestUtils.accountNumberCash).csv")
        possibleAccountNames = importer.accountsFromLedger()
        #expect(possibleAccountNames.count == 1)
        #expect(possibleAccountNames[0] == TestUtils.cash)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export 000000.csv")
        possibleAccountNames = importer.accountsFromLedger()
        #expect(possibleAccountNames.count == 2)
        #expect(possibleAccountNames.contains(TestUtils.cash))
        #expect(possibleAccountNames.contains(TestUtils.chequing))
    }

   @Test
   func testAccountSuggestions() {
        var importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers,
                                                csvReader: TestUtils.basicCSVReader,
                                                fileName: "Export \(TestUtils.accountNumberChequing).csv")
        importer.delegate = TestUtils.noInputDelegate
        #expect(importer.configuredAccountName == TestUtils.chequing)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export \(TestUtils.accountNumberCash).csv")
        importer.delegate = TestUtils.noInputDelegate
        #expect(importer.configuredAccountName == TestUtils.cash)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export 000000.csv")
        let delegate = AccountNameSuggestionVerifier(expectedValues: [TestUtils.cash, TestUtils.chequing])
        importer.delegate = delegate
        _ = importer.configuredAccountName
        #expect(delegate.verified)
    }

   @Test
   func testParseLine() throws {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: try TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
6/5/2020,OTHER,EFT Withdrawal to BANK,To BANK,-765.43\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "To BANK")
        #expect(line.amount == Decimal(string: "-765.43", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

   @Test
   func testParseLineEmptyMemo() throws {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: try TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
6/10/2017,DEBIT,Cheque Withdrawal - 002,,-95\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Cheque Withdrawal - 002")
        #expect(line.amount == Decimal(string: "-95.00", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

   @Test
   func testParseLineInterest() throws {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: try TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
5/31/2020,OTHER,Interest Paid,,0.5\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Interest Paid")
        #expect(line.amount == Decimal(string: "0.50", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "Tangerine")
        #expect(line.price == nil)
    }

   @Test
   func testParseLineInterac() throws {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: try TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
5/23/2020,OTHER,INTERAC e-Transfer From: NAME,Transferred,40.25\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "NAME - Transferred")
        #expect(line.amount == Decimal(string: "40.25", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

}
