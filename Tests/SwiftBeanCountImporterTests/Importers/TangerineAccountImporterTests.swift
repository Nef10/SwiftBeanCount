//
//  TangerineAccountImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class TangerineAccountImporterTests: XCTestCase {

    func testHeader() {
        XCTAssertEqual(TangerineAccountImporter.header,
                       ["Date", "Transaction", "Name", "Memo", "Amount"])
    }

    func testSettingsName() {
        XCTAssertEqual(TangerineAccountImporter.settingsName, "Tangerine Accounts")
    }

    func testPossibleAccountNames() {
        let key = TangerineAccountImporter.getUserDefaultsKey(for: TangerineAccountImporter.accountsSetting)
        UserDefaults.standard.set("\(TestUtils.cash.fullName), \(TestUtils.chequing.fullName)", forKey: key)

        var importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers,
                                                csvReader: TestUtils.basicCSVReader,
                                                fileName: "Export \(TestUtils.accountNumberChequing).csv")
        var possibleAccountNames = importer.possibleAccountNames(for: TestUtils.lederAccountNumers)
        XCTAssertEqual(possibleAccountNames.count, 1)
        XCTAssertEqual(possibleAccountNames[0], TestUtils.chequing)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export \(TestUtils.accountNumberCash).csv")
        possibleAccountNames = importer.possibleAccountNames(for: TestUtils.lederAccountNumers)
        XCTAssertEqual(possibleAccountNames.count, 1)
        XCTAssertEqual(possibleAccountNames[0], TestUtils.cash)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export 000000.csv")
        possibleAccountNames = importer.possibleAccountNames(for: TestUtils.lederAccountNumers)
        XCTAssertEqual(possibleAccountNames.count, 2)
        XCTAssertTrue(possibleAccountNames.contains(TestUtils.cash))
        XCTAssertTrue(possibleAccountNames.contains(TestUtils.chequing))

        importer.useAccount(name: TestUtils.cash)
        possibleAccountNames = importer.possibleAccountNames(for: TestUtils.lederAccountNumers)
        XCTAssertEqual(possibleAccountNames.count, 1)
        XCTAssertEqual(possibleAccountNames[0], TestUtils.cash)

        UserDefaults.standard.removeObject(forKey: key)
    }

    func testParseLine() {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
6/5/2020,OTHER,EFT Withdrawal to BANK,To BANK,-765.43\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "To BANK")
        XCTAssertEqual(line.amount, Decimal(string: "-765.43", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineEmptyMemo() {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
6/10/2017,DEBIT,Cheque Withdrawal - 002,,-95\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Cheque Withdrawal - 002")
        XCTAssertEqual(line.amount, Decimal(string: "-95.00", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineInterest() {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
5/31/2020,OTHER,Interest Paid,,0.5\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Interest Paid")
        XCTAssertEqual(line.amount, Decimal(string: "0.50", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "Tangerine")
        XCTAssertNil(line.price)
    }

    func testParseLineInterac() {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
5/23/2020,OTHER,INTERAC e-Transfer From: NAME,Transferred,40.25\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "NAME - Transferred")
        XCTAssertEqual(line.amount, Decimal(string: "40.25", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

}
