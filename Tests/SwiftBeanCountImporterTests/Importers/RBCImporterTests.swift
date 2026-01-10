//
//  RBCImporterTests.swift
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
struct RBCImporterTests {

    @Test
    func headers() {
        #expect(RBCImporter.headers == [["Account Type", "Account Number", "Transaction Date", "Cheque Number", "Description 1", "Description 2", "CAD$", "USD$"]])
    }

    @Test
    func importerName() {
        #expect(RBCImporter.importerName == "RBC")
    }

    @Test
    func importerType() {
        #expect(RBCImporter.importerType == "rbc")
    }

    @Test
    func helpText() {
        #expect(RBCImporter.helpText == "Enables importing of downloaded CSV files from RBC Accounts and Credit Cards.\n\nTo use add importer-type: \"rbc\" to your accounts.")
    }

    @Test
    func importName() throws {
        #expect(RBCImporter(ledger: nil, csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName == "RBC File TestName")
    }

    @Test
    func parseLineAccount() throws {
        let importer = RBCImporter(ledger: nil,
                                   csvReader: try TestUtils.csvReader(content: """
            "Account Type","Account Number","Transaction Date","Cheque Number","Description 1","Description 2","CAD$","USD$"
            Chequing,01234-1234567,6/10/2017,,"Merchant",,-4.00,,\n
            """
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Merchant")
        #expect(line.amount == Decimal(string: "-4.00", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLineCard() throws {
        let importer = RBCImporter(ledger: nil,
                                   csvReader: try TestUtils.csvReader(content: """
            "Account Type","Account Number","Transaction Date","Cheque Number","Description 1","Description 2","CAD$","USD$"
            MasterCard,1234123412341234,6/5/2020,,"Test Store",,-4.47,,\n
            """
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Test Store")
        #expect(line.amount == Decimal(string: "-4.47", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLineBothDescriptions() throws {
        let importer = RBCImporter(ledger: nil,
                                   csvReader: try TestUtils.csvReader(content: """
            "Account Type","Account Number","Transaction Date","Cheque Number","Description 1","Description 2","CAD$","USD$"
            Chequing,01234-1234567,4/1/2020,,"INTER-FI FUND TR DR","Sender",-400.00,,\n
            """
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "INTER-FI FUND TR DR Sender")
        #expect(line.amount == Decimal(string: "-400.00", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLineMonthlyFee() throws {
        let importer = RBCImporter(ledger: nil,
                                   csvReader: try TestUtils.csvReader(content: """
            "Account Type","Account Number","Transaction Date","Cheque Number","Description 1","Description 2","CAD$","USD$"
            Chequing,01234-1234567,3/13/2020,,"MONTHLY FEE",,-4.00,,\n
            """
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "MONTHLY FEE")
        #expect(line.amount == Decimal(string: "-4.00", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "RBC")
        #expect(line.price == nil)
    }

}
