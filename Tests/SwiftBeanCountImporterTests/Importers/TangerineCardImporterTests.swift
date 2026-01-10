//
//  TangerineCardImporterTests.swift
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

struct TangerineCardImporterTests {

   @Test
   func testHeaders() {
        #expect(TangerineCardImporter.headers == [["Transaction date", "Transaction", "Name", "Memo", "Amount"]])
    }

   @Test
   func testImporterName() {
        #expect(TangerineCardImporter.importerName == "Tangerine Credit Card")
    }

   @Test
   func testImporterType() {
        #expect(TangerineCardImporter.importerType == "tangerine-card")
    }

   @Test
   func testHelpText() {
        #expect(TangerineCardImporter.helpText == "Enables importing of downloaded CSV files from Tangerine Credit Cards.\n\nTo use add importer-type: \"tangerine-card\" to your account.")
    }

   @Test
   func testImportName() throws {
        XCTAssertEqual(
            TangerineCardImporter(ledger: nil, csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName,
            "Tangerine Credit Card File TestName"
        )
    }

   @Test
   func testParseLine() throws {
        let importer = TangerineCardImporter(ledger: nil,
                                             csvReader: try TestUtils.csvReader(content: """
Transaction date,Transaction,Name,Memo,Amount
6/10/2017,DEBIT,Merchant VANCOUVER BC,Rewards earned: 0.78 ~ Category: Bill Payment,-39.2\n
"""
                                            ),
                                             fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant VANCOUVER BC")
        #expect(line.amount == Decimal(string: "-39.20", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "")
        #expect(line.price == nil)
    }

}
