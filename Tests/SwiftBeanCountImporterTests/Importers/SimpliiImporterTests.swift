//
//  SimpliiImporterTests.swift
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
struct SimpliiImporterTests {

   @Test
   func testHeaders() {
        #expect(SimpliiImporter.headers == [["Date", "Transaction Details", "Funds Out", "Funds In"]])
    }

   @Test
   func testImporterName() {
        #expect(SimpliiImporter.importerName == "Simplii")
    }

   @Test
   func testImporterType() {
        #expect(SimpliiImporter.importerType == "simplii")
    }

   @Test
   func testHelpText() {
        #expect(SimpliiImporter.helpText == "Enables importing of downloaded CSV files from Simplii Accounts.\n\nTo use add importer-type: \"simplii\" to your account.")
    }

   @Test
   func testImportName() throws {
        #expect(SimpliiImporter(ledger: nil == csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName, "Simplii File TestName")
    }

   @Test
   func testParseLine() throws {
        let importer = SimpliiImporter(ledger: nil,
                                       csvReader: try TestUtils.csvReader(content: """
Date, Transaction Details, Funds Out, Funds In
06/10/2017,PAYROLL DEPOSIT COMPANY INC.,,123.45\n
"""
                                            ),
                                       fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "PAYROLL DEPOSIT COMPANY INC.")
        #expect(line.amount == Decimal(string: "123.45", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

   @Test
   func testParseLineAmountOut() throws {
        let importer = SimpliiImporter(ledger: nil,
                                       csvReader: try TestUtils.csvReader(content: """
Date, Transaction Details, Funds Out, Funds In
05/06/2020,BANK TO BANK TSF EXT TSF,1234.56,\n
"""
                                            ),
                                       fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "BANK TO BANK TSF EXT TSF")
        #expect(line.amount == Decimal(string: "-1234.56", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

   @Test
   func testParseLineInterest() throws {
        let importer = SimpliiImporter(ledger: nil,
                                       csvReader: try TestUtils.csvReader(content: """
Date, Transaction Details, Funds Out, Funds In
06/05/2020, INTEREST,,0.69\n
"""
                                            ),
                                       fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "INTEREST")
        #expect(line.amount == Decimal(string: "0.69", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "Simplii")
        #expect(line.price == nil)
    }

}
