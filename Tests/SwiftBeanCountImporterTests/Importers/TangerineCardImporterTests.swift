//
//  TangerineCardImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class TangerineCardImporterTests: XCTestCase {

    func testHeaders() {
        XCTAssertEqual(TangerineCardImporter.headers,
                       [["Transaction date", "Transaction", "Name", "Memo", "Amount"]])
    }

    func testImporterName() {
        XCTAssertEqual(TangerineCardImporter.importerName, "Tangerine Credit Card")
    }

    func testImporterType() {
        XCTAssertEqual(TangerineCardImporter.importerType, "tangerine-card")
    }

    func testHelpText() {
        XCTAssertEqual(TangerineCardImporter.helpText,
                       "Enables importing of downloaded CSV files from Tangerine Credit Cards.\n\nTo use add importer-type: \"tangerine-card\" to your account.")
    }

    func testImportName() throws {
        XCTAssertEqual(
            TangerineCardImporter(ledger: nil, csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName,
            "Tangerine Credit Card File TestName"
        )
    }

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
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant VANCOUVER BC")
        XCTAssertEqual(line.amount, Decimal(string: "-39.20", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

}
