//
//  RogersImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class RogersImporterTests: XCTestCase {

    func testHeaders() {
        XCTAssertEqual(RogersImporter.headers, [
            ["Transaction Date", "Activity Type", "Merchant Name", "Merchant Category", "Amount"],
            ["Transaction Date", "Activity Type", "Merchant Name", "Merchant Category Description", "Amount"],
            ["Date", "Activity Type", "Merchant Name", "Merchant Category", "Amount"],
            ["Date", "Activity Type", "Merchant Name", "Merchant Category Description", "Amount"],
            ["Transaction Date", "Activity Type", "Merchant Name", "Merchant Category", "Amount", "Rewards"],
            ["Transaction Date", "Activity Type", "Merchant Name", "Merchant Category Description", "Amount", "Rewards"],
            ["Date", "Activity Type", "Merchant Name", "Merchant Category", "Amount", "Rewards"],
            ["Date", "Activity Type", "Merchant Name", "Merchant Category Description", "Amount", "Rewards"],
        ])
    }

    func testImporterType() {
        XCTAssertEqual(RogersImporter.importerType, "rogers")
    }

    func testImportName() {
        XCTAssertEqual(RogersImporter(ledger: nil, csvReader: TestUtils.csvReader(content: "A"), fileName: "TestName").importName, "Rogers Bank File TestName")
    }

    func testParseLine1() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Transaction Date","Activity Type","Merchant Name","Merchant Category","Amount"
"2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLine2() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Transaction Date","Activity Type","Merchant Name","Merchant Category Description","Amount"
"2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLine3() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Date","Activity Type","Merchant Name","Merchant Category","Amount"
"2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLine4() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Date","Activity Type","Merchant Name","Merchant Category Description","Amount"
"2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

func testParseLine5() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Transaction Date","Activity Type","Merchant Name","Merchant Category","Amount","Rewards"
"2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLine6() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Transaction Date","Activity Type","Merchant Name","Merchant Category Description","Amount","Rewards"
"2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLine7() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Date","Activity Type","Merchant Name","Merchant Category","Amount","Rewards"
"2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLine8() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Date","Activity Type","Merchant Name","Merchant Category Description","Amount","Rewards"
"2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineCashBack() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Transaction Date","Activity Type","Merchant Name","Merchant Category","Amount"
"2020-06-05","TRANS","CashBack / Remises","","-43.00",""\n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "CashBack / Remises")
        XCTAssertEqual(line.amount, Decimal(string: "43.00", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "Rogers")
        XCTAssertNil(line.price)
    }

}
