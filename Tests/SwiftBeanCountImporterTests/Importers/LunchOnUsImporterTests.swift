//
//  LunchOnUsImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class LunchOnUsImporterTests: XCTestCase {

    func testHeaders() {
        XCTAssertEqual(LunchOnUsImporter.headers, [["date", "type", "amount", "invoice", "remaining", "location"]])
    }

    func testSettingsName() {
        XCTAssertEqual(LunchOnUsImporter.settingsName, "LunchOnUs Card")
    }

    func testImportName() {
        XCTAssertEqual(LunchOnUsImporter(ledger: nil, csvReader: TestUtils.csvReader(content: "A"), fileName: "TestName").importName, "LunchOnUs File TestName")
    }

    func testParseLineNormalPurchase() {
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: TestUtils.csvReader(content: """
date,type,amount,invoice,remaining,location
"June 10, 2017 | 23:45:19","Purchase","6.83","00012345IUYTrBTE","003737","Bubble Tea"\n
"""
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description, "Bubble Tea")
        XCTAssertEqual(line.amount, Decimal(string: "-6.83", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineRedeemUnlock() {
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: TestUtils.csvReader(content: """
date,type,amount,invoice,remaining,location
"June 05, 2020 | 01:02:59","Redeem Unlock","75.00","00000478IUYTaBVR","499147","Test Restaurant"\n
"""
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        XCTAssertEqual(line.description, "Test Restaurant")
        XCTAssertEqual(line.amount, Decimal(string: "-75.00", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineBalanceInquiryWithPartLock() { // #7
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: TestUtils.csvReader(content: """
date,type,amount,invoice,remaining,location
"Feb 21, 2020 | 20:25:43","Balance Inquiry with part lock","65.21","00000750LJHGwHTE","923212","Shop SAP"\n
"""
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description, "Shop SAP")
        XCTAssertEqual(line.amount, Decimal(string: "-65.21", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineActivateCard() {
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: TestUtils.csvReader(content: """
date,type,amount,invoice,remaining,location
"Jan 01, 2020 | 04:07:12","Activate Card","528.00","UNKNOWN","123456","SAP CANADA INC. - HEAD OFFICE"\n
"""
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description, "")
        XCTAssertEqual(line.amount, Decimal(string: "528.00", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "SAP Canada Inc.")
        XCTAssertNil(line.price)
    }

    func testParseLineCashOut() {
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: TestUtils.csvReader(content: """
date,type,amount,invoice,remaining,location
"Jan 01, 2020 | 03:07:19","Cash Out","0.60","UNKNOWN","654321","SAP CANADA INC. - HEAD OFFICE"\n
"""
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description, "Cash Out")
        XCTAssertEqual(line.amount, Decimal(string: "-0.60", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

}
