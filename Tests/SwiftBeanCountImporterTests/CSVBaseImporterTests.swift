//
//  CSVBaseImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

private class TestCSVBaseImporter: CSVBaseImporter {

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

     override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader["Date"]!)!
        let amount = Decimal(string: "10.00", locale: Locale(identifier: "en_CA"))!
        let description = csvReader["Description"]!
        var price: Amount?
        if description == "price" {
            price = Amount(number: Decimal(string: "10.00", locale: Locale(identifier: "en_CA"))!, commoditySymbol: TestUtils.usd)
        }
        return CSVLine(date: date, description: description, amount: amount, payee: csvReader["Payee"]!, price: price)
    }

}

final class CSVBaseImporterTests: XCTestCase {

    func testLoadFile() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.basicCSVReader, fileName: "")
        importer.useAccount(name: TestUtils.cash)
        importer.loadFile()

        // Can be called multiple times, still only returns each row once
        importer.loadFile()
        let line = importer.parseLineIntoTransaction()
        XCTAssertNotNil(line)

        let noLine = importer.parseLineIntoTransaction()
        XCTAssertNil(noLine)
    }

    func testLoadFileSortDate() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.dateMixedCSVReader, fileName: "")
        importer.useAccount(name: TestUtils.cash)
        importer.loadFile()

        let line1 = importer.parseLineIntoTransaction()
        XCTAssertNotNil(line1)
        let line2 = importer.parseLineIntoTransaction()
        XCTAssertNotNil(line2)

        XCTAssertTrue(line1!.transaction.metaData.date < line2!.transaction.metaData.date)
    }

    func testParseLineIntoTransaction() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.basicCSVReader, fileName: "")
        importer.useAccount(name: TestUtils.cash)

        // nil when loadFile is not called beforehand
        XCTAssertNil(importer.parseLineIntoTransaction())

        importer.loadFile()
        let line = importer.parseLineIntoTransaction()
        XCTAssertNotNil(line)

        let noLine = importer.parseLineIntoTransaction()
        XCTAssertNil(noLine)
    }

    func testPrice() {
        let transaction = transactionHelper(description: "price")
        let posting = transaction.postings.first { $0.accountName != TestUtils.cash }!
        XCTAssertEqual(posting.price!.number, -1)
        XCTAssertEqual(posting.amount.number, 10)
        XCTAssertEqual(posting.amount.commoditySymbol, TestUtils.usd)
    }

    func testAccountName() {
        let transaction = transactionHelper(description: "")
        XCTAssertEqual(transaction.postings.count, 2)
        XCTAssertEqual(transaction.postings.filter { $0.accountName.fullName == Settings.defaultAccountName }.count, 1)
        XCTAssertEqual(transaction.postings.filter { $0.accountName == TestUtils.cash }.count, 1)
    }

    func testSavedPayee() {
        let description = "abcd"
        let payeeMapping = "efg"
        UserDefaults.standard.removeObject(forKey: Settings.payeesUserDefaultKey)

        UserDefaults.standard.set([description: payeeMapping], forKey: Settings.payeesUserDefaultKey)
        XCTAssertEqual(transactionHelper(description: description).metaData.payee, payeeMapping)

        UserDefaults.standard.removeObject(forKey: Settings.payeesUserDefaultKey)
    }

    func testSavedDescription() {
        let description = "abcd"
        let descriptionMapping = "efg"
        UserDefaults.standard.removeObject(forKey: Settings.descriptionUserDefaultsKey)

        UserDefaults.standard.set([description: descriptionMapping], forKey: Settings.descriptionUserDefaultsKey)
        XCTAssertEqual(descriptionHelper(description: description), descriptionMapping)

        UserDefaults.standard.removeObject(forKey: Settings.descriptionUserDefaultsKey)
    }

    func testSavedAccount() {
        let payee = "abcd"
        UserDefaults.standard.removeObject(forKey: Settings.accountsUserDefaultsKey)

        UserDefaults.standard.set([payee: TestUtils.chequing.fullName], forKey: Settings.accountsUserDefaultsKey)
        XCTAssertEqual(transactionHelper(description: "", payee: payee).postings.first { $0.accountName != TestUtils.cash }?.accountName, TestUtils.chequing)

        UserDefaults.standard.removeObject(forKey: Settings.accountsUserDefaultsKey)
    }

    func testSavedPayeeAccount() {
        let description = "abcd"
        let payee = "efg"
        UserDefaults.standard.removeObject(forKey: Settings.payeesUserDefaultKey)
        UserDefaults.standard.removeObject(forKey: Settings.accountsUserDefaultsKey)

        UserDefaults.standard.set([payee: TestUtils.chequing.fullName], forKey: Settings.accountsUserDefaultsKey)
        UserDefaults.standard.set([description: payee], forKey: Settings.payeesUserDefaultKey)
        XCTAssertEqual(transactionHelper(description: description).postings.first { $0.accountName != TestUtils.cash }?.accountName, TestUtils.chequing)

        UserDefaults.standard.removeObject(forKey: Settings.accountsUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Settings.payeesUserDefaultKey)
    }

    func testSanitizeDescription() {
        XCTAssertEqual(descriptionHelper(description: "Shop1 C-IDP PURCHASE - 1234  BC  CA"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 IDP PURCHASE-1234"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 VISA DEBIT PUR-1234"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 VISA DEBIT REF-1234"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 WWWINTERAC PUR 1234"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 INTERAC E-TRF- 1234"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 1234 ~ Internet Withdrawal"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 - SAP"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 SAP"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: " SAP CANADA"), "SAP CANADA")
        XCTAssertEqual(descriptionHelper(description: "Shop1 -MAY 2014"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 - JUNE 2016"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1  BC  CA"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 #12345"), "Shop1")
        XCTAssertEqual(descriptionHelper(description: "Shop1 # 12"), "Shop1")
    }

    private func descriptionHelper(description: String) -> String {
        transactionHelper(description: description).metaData.narration
    }

    private func transactionHelper(description: String, payee: String = "payee") -> Transaction {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.csvReader(description: description, payee: payee), fileName: "")
        importer.useAccount(name: TestUtils.cash)
        importer.loadFile()
        let line = importer.parseLineIntoTransaction()
        XCTAssertNotNil(line)
        return line!.transaction
    }

}
