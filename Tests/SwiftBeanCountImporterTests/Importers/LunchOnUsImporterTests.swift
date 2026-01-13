//
//  LunchOnUsImporterTests.swift
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
struct LunchOnUsImporterTests {

    @Test
    func headers() {
        #expect(LunchOnUsImporter.headers == [["date", "type", "amount", "invoice", "remaining", "location"]])
    }

    @Test
    func importerName() {
        #expect(LunchOnUsImporter.importerName == "Lunch On Us")
    }

    @Test
    func importerType() {
        #expect(LunchOnUsImporter.importerType == "lunch-on-us")
    }

    @Test
    func helpText() { // swiftlint:disable:next line_length
        #expect(LunchOnUsImporter.helpText == "Enables importing of CSV files downloaded from https://lunchmapper.appspot.com/csv. Does not support importing balances.\n\nTo use add importer-type: \"lunch-on-us\" to your account.")
    }

    @Test
    func importName() throws {
        #expect(LunchOnUsImporter(ledger: nil, csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName == "LunchOnUs File TestName")
    }

    @Test
    func parseLineNormalPurchase() throws {
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: try TestUtils.csvReader(content: """
            date,type,amount,invoice,remaining,location
            "June 10, 2017 | 23:45:19","Purchase","6.83","00012345IUYTrBTE","003737","Bubble Tea"\n
            """
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description == "Bubble Tea")
        #expect(line.amount == Decimal(string: "-6.83", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLineRedeemUnlock() throws {
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: try TestUtils.csvReader(content: """
            date,type,amount,invoice,remaining,location
            "June 05, 2020 | 01:02:59","Redeem Unlock","75.00","00000478IUYTaBVR","499147","Test Restaurant"\n
            """
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        #expect(line.description == "Test Restaurant")
        #expect(line.amount == Decimal(string: "-75.00", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLineBalanceInquiryWithPartLock() throws { // #7
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: try TestUtils.csvReader(content: """
            date,type,amount,invoice,remaining,location
            "Feb 21, 2020 | 20:25:43","Balance Inquiry with part lock","65.21","00000750LJHGwHTE","923212","Shop SAP"\n
            """
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description == "Shop SAP")
        #expect(line.amount == Decimal(string: "-65.21", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

    @Test
    func parseLineActivateCard() throws {
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: try TestUtils.csvReader(content: """
            date,type,amount,invoice,remaining,location
            "Jan 01, 2020 | 04:07:12","Activate Card","528.00","UNKNOWN","123456","SAP CANADA INC. - HEAD OFFICE"\n
            """
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description.isEmpty)
        #expect(line.amount == Decimal(string: "528.00", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "SAP Canada Inc.")
        #expect(line.price == nil)
    }

    @Test
    func parseLineCashOut() throws {
        let importer = LunchOnUsImporter(ledger: nil,
                                         csvReader: try TestUtils.csvReader(content: """
            date,type,amount,invoice,remaining,location
            "Jan 01, 2020 | 03:07:19","Cash Out","0.60","UNKNOWN","654321","SAP CANADA INC. - HEAD OFFICE"\n
            """
                                            ),
                                         fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description == "Cash Out")
        #expect(line.amount == Decimal(string: "-0.60", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee.isEmpty)
        #expect(line.price == nil)
    }

}
