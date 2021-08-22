//
//  RBCImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class RBCImporterTests: XCTestCase {

    func testHeaders() {
        XCTAssertEqual(RBCImporter.headers,
                       [["Account Type", "Account Number", "Transaction Date", "Cheque Number", "Description 1", "Description 2", "CAD$", "USD$"]])
    }

    func testSettingsName() {
        XCTAssertEqual(RBCImporter.settingsName, "RBC Accounts + CC")
    }

    func testParseLineAccount() {
        let importer = RBCImporter(ledger: nil,
                                   csvReader: TestUtils.csvReader(content: """
"Account Type","Account Number","Transaction Date","Cheque Number","Description 1","Description 2","CAD$","USD$"
Chequing,01234-1234567,6/10/2017,,"Merchant",,-4.00,,\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4.00", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineCard() {
        let importer = RBCImporter(ledger: nil,
                                   csvReader: TestUtils.csvReader(content: """
"Account Type","Account Number","Transaction Date","Cheque Number","Description 1","Description 2","CAD$","USD$"
MasterCard,1234123412341234,6/5/2020,,"Test Store",,-4.47,,\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Test Store")
        XCTAssertEqual(line.amount, Decimal(string: "-4.47", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineBothDescriptions() {
        let importer = RBCImporter(ledger: nil,
                                   csvReader: TestUtils.csvReader(content: """
"Account Type","Account Number","Transaction Date","Cheque Number","Description 1","Description 2","CAD$","USD$"
Chequing,01234-1234567,4/1/2020,,"INTER-FI FUND TR DR","Sender",-400.00,,\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "INTER-FI FUND TR DR Sender")
        XCTAssertEqual(line.amount, Decimal(string: "-400.00", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineMonthlyFee() {
        let importer = RBCImporter(ledger: nil,
                                   csvReader: TestUtils.csvReader(content: """
"Account Type","Account Number","Transaction Date","Cheque Number","Description 1","Description 2","CAD$","USD$"
Chequing,01234-1234567,3/13/2020,,"MONTHLY FEE",,-4.00,,\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "MONTHLY FEE")
        XCTAssertEqual(line.amount, Decimal(string: "-4.00", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "RBC")
        XCTAssertNil(line.price)
    }

}
