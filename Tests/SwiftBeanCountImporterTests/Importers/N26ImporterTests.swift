//
//  N26ImporterTests.swift
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

struct N26ImporterTests {

   @Test


   func testHeaders() {
        XCTAssertEqual(N26Importer.headers, [
            [
                "Datum",
                "Empfänger",
                "Kontonummer",
                "Transaktionstyp",
                "Verwendungszweck",
                "Kategorie",
                "Betrag (EUR)",
                "Betrag (Fremdwährung)",
                "Fremdwährung",
                "Wechselkurs"
            ],
            [
                "Datum",
                "Empfänger",
                "Kontonummer",
                "Transaktionstyp",
                "Verwendungszweck",
                "Betrag (EUR)",
                "Betrag (Fremdwährung)",
                "Fremdwährung",
                "Wechselkurs"
            ]
        ])
    }

   @Test


   func testImporterName() {
        #expect(N26Importer.importerName == "N26")
    }

   @Test


   func testImporterType() {
        #expect(N26Importer.importerType == "n26")
    }

   @Test


   func testHelpText() {
        #expect(N26Importer.helpText == "Enables importing of downloaded CSV files from N26 Accounts.\n\nTo use add importer-type: \"n26\" to your account.")
    }

   @Test


   func testImportName() throws {
        #expect(N26Importer(ledger: nil == csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName, "N26 File TestName")
    }

   @Test


   func testParseLineNormalPurchase() throws {
        let importer = N26Importer(ledger: nil,
                                   csvReader: try TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2017-06-10","Online Shop","","MasterCard Zahlung","","Sonstiges","-79.33","","",""\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Online Shop")
        #expect(line.amount == Decimal(string: "-79.33", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "")
        #expect(line.price == nil)
    }

   @Test


   func testParseLineSameCurrencyPurchase() throws {
        let importer = N26Importer(ledger: nil,
                                   csvReader: try TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2020-04-29","Online Shop","","MasterCard Zahlung","","Shopping","-79.33","-79.33","\(Settings.fallbackCommodity)","1.0"\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Online Shop")
        #expect(line.amount == Decimal(string: "-79.33", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "")
        #expect(line.price == nil)
    }

   @Test


   func testParseLineOutgoingTransfer() throws {
        let importer = N26Importer(ledger: nil,
                                   csvReader: try TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2020-06-05","Recipient","DE12345678987654123600","Überweisung","Comment","Haushalt & Nebenkosten","-32.2","","",""\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Recipient Comment")
        #expect(line.amount == Decimal(string: "-32.20", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "")
        #expect(line.price == nil)
    }

   @Test


   func testParseLineIncomingTransfer() throws {
        let importer = N26Importer(ledger: nil,
                                   csvReader: try TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2019-12-18","Sender","IE81CITI12547812345678","Gutschrift","Comment","Gutschriften","499.9","","",""\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Sender Comment")
        #expect(line.amount == Decimal(string: "499.90", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "")
        #expect(line.price == nil)
    }

   @Test


   func testParseLineForeignCurrency() throws {
        let importer = N26Importer(ledger: nil,
                                   csvReader: try TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2019-11-19","Company","","MasterCard Zahlung","","Transport & Auto","-20.24","-22.39","USD","0.904"\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        #expect(line.description.trimmingCharacters(in: .whitespaces) == "Company")
        #expect(line.amount == Decimal(string: "-20.24", locale: Locale(identifier: "en_CA"))!)
        #expect(line.payee == "")
        #expect(line.price == Amount(number: Decimal(string: "22.39", locale: Locale(identifier: "en_CA"))!, commoditySymbol: TestUtils.usd, decimalDigits: 2))
    }

}
