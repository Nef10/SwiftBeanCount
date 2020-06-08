//
//  N26ImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class N26ImporterTests: XCTestCase {

    func testHeader() {
        XCTAssertEqual(N26Importer.header, [
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
        ])
    }

    func testSettingsName() {
        XCTAssertEqual(N26Importer.settingsName, "N26")
    }

    func testParseLineNormalPurchase() {
        let importer = N26Importer(ledger: nil,
                                   csvReader: TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2017-06-10","Online Shop","","MasterCard Zahlung","","Sonstiges","-79.33","","",""\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Online Shop")
        XCTAssertEqual(line.amount, Decimal(string: "-79.33", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineSameCurrencyPurchase() {
        let importer = N26Importer(ledger: nil,
                                   csvReader: TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2020-04-29","Online Shop","","MasterCard Zahlung","","Shopping","-79.33","-79.33","\(Settings.fallbackCommodity)","1.0"\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Online Shop")
        XCTAssertEqual(line.amount, Decimal(string: "-79.33", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineOutgoingTransfer() {
        let importer = N26Importer(ledger: nil,
                                   csvReader: TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2020-06-05","Recipient","DE12345678987654123600","Überweisung","Comment","Haushalt & Nebenkosten","-32.2","","",""\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Recipient Comment")
        XCTAssertEqual(line.amount, Decimal(string: "-32.20", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineIncomingTransfer() {
        let importer = N26Importer(ledger: nil,
                                   csvReader: TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2019-12-18","Sender","IE81CITI12547812345678","Gutschrift","Comment","Gutschriften","499.9","","",""\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Sender Comment")
        XCTAssertEqual(line.amount, Decimal(string: "499.90", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineForeignCurrency() {
        let importer = N26Importer(ledger: nil,
                                   csvReader: TestUtils.csvReader(content: """
"Datum", "Empfänger", "Kontonummer", "Transaktionstyp", "Verwendungszweck", "Kategorie", "Betrag (EUR)", "Betrag (Fremdwährung)", "Fremdwährung", "Wechselkurs"
"2019-11-19","Company","","MasterCard Zahlung","","Transport & Auto","-20.24","-22.39","USD","0.904"\n
"""
                                            ),
                                   fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Company")
        XCTAssertEqual(line.amount, Decimal(string: "-20.24", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertEqual(line.price, Amount(number: Decimal(string: "22.39", locale: Locale(identifier: "en_CA"))!, commoditySymbol: TestUtils.usd, decimalDigits: 2))
    }

}
