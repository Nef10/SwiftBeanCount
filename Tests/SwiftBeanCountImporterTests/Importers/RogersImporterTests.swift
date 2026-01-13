//
//  RogersImporterTests.swift
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
struct RogersImporterTests {

    @Test
    func headers() {
        #expect(RogersImporter.headers == [
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

    @Test
    func importerName() {
        #expect(RogersImporter.importerName == "Rogers Bank")
    }

    @Test
    func importerType() {
        #expect(RogersImporter.importerType == "rogers")
    }

    @Test
    func helpText() {
        #expect(RogersImporter.helpText == "Enables importing of downloaded CSV files from Rogers Bank Credit Cards.\n\nTo use add importer-type: \"rogers\" to your account.")
    }

    @Test
    func importName() throws {
        #expect(RogersImporter(ledger: nil, csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName == "Rogers Bank File TestName")
    }

    @Test
    func parseLine1() throws {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: try TestUtils.csvReader(content: """
            "Transaction Date","Activity Type","Merchant Name","Merchant Category","Amount"
            "2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
            """
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant")
        #expect(line.amount == Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLine2() throws {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: try TestUtils.csvReader(content: """
            "Transaction Date","Activity Type","Merchant Name","Merchant Category Description","Amount"
            "2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
            """
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant")
        #expect(line.amount == Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLine3() throws {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: try TestUtils.csvReader(content: """
            "Date","Activity Type","Merchant Name","Merchant Category","Amount"
            "2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
            """
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant")
        #expect(line.amount == Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLine4() throws {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: try TestUtils.csvReader(content: """
            "Date","Activity Type","Merchant Name","Merchant Category Description","Amount"
            "2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
            """
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant")
        #expect(line.amount == Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLine5() throws {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: try TestUtils.csvReader(content: """
            "Transaction Date","Activity Type","Merchant Name","Merchant Category","Amount","Rewards"
            "2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
            """
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant")
        #expect(line.amount == Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLine6() throws {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: try TestUtils.csvReader(content: """
            "Transaction Date","Activity Type","Merchant Name","Merchant Category Description","Amount","Rewards"
            "2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
            """
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant")
        #expect(line.amount == Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLine7() throws {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: try TestUtils.csvReader(content: """
            "Date","Activity Type","Merchant Name","Merchant Category","Amount","Rewards"
            "2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
            """
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant")
        #expect(line.amount == Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLine8() throws {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: try TestUtils.csvReader(content: """
            "Date","Activity Type","Merchant Name","Merchant Category Description","Amount","Rewards"
            "2017-06-10","TRANS","Merchant","Catalog Merchant","$4,004.44"n
            """
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant")
        #expect(line.amount == Decimal(string: "-4004.44", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLineCashBack() throws {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: try TestUtils.csvReader(content: """
            "Transaction Date","Activity Type","Merchant Name","Merchant Category","Amount"
            "2020-06-05","TRANS","CashBack / Remises","","-43.00",""\n
            """
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "CashBack / Remises")
        #expect(line.amount == Decimal(string: "43.00", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "Rogers")
        #expect(line.price == nil)
    }

}
