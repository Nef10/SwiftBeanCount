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

    func testImportName() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.basicCSVReader, fileName: "ABCDTEST")
        XCTAssertEqual(importer.importName, "ABCDTEST")
    }

    func testLoad() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.basicCSVReader, fileName: "")
        importer.delegate = TestUtils.cashAccountDelegate

        importer.load()
        // Can be called multiple times, still only returns each row once
        importer.load()

        let importedTransaction = importer.nextTransaction()
        XCTAssertNotNil(importedTransaction)

        let noTransaction = importer.nextTransaction()
        XCTAssertNil(noTransaction)
    }

    func testLoadSortDate() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.dateMixedCSVReader, fileName: "")
        importer.delegate = TestUtils.cashAccountDelegate
        importer.load()

        let importedTransaction1 = importer.nextTransaction()
        XCTAssertNotNil(importedTransaction1)
        let importedTransaction2 = importer.nextTransaction()
        XCTAssertNotNil(importedTransaction2)

        XCTAssertTrue(importedTransaction1!.transaction.metaData.date < importedTransaction2!.transaction.metaData.date)
    }

    func testNextTransaction() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.basicCSVReader, fileName: "")
        importer.delegate = TestUtils.cashAccountDelegate
        importer.load()

        let importedTransaction = importer.nextTransaction()
        XCTAssertNotNil(importedTransaction)
        XCTAssertTrue(importedTransaction!.shouldAllowUserToEdit)
        XCTAssertEqual(importedTransaction!.accountName, TestUtils.cash)

        let noTransaction = importer.nextTransaction()
        XCTAssertNil(noTransaction)
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
        Settings.storage = TestStorage()

        Settings.setPayeeMapping(key: description, payee: payeeMapping)
        XCTAssertEqual(transactionHelper(description: description).metaData.payee, payeeMapping)
    }

    func testSavedDescription() {
        let description = "abcd"
        let descriptionMapping = "efg"
        Settings.storage = TestStorage()

        Settings.setDescriptionMapping(key: description, description: descriptionMapping)
        XCTAssertEqual(descriptionHelper(description: description), descriptionMapping)
    }

    func testSavedAccount() {
        let payee = "abcd"
        Settings.storage = TestStorage()

        Settings.setAccountMapping(key: payee, account: TestUtils.chequing.fullName)
        XCTAssertEqual(transactionHelper(description: "", payee: payee).postings.first { $0.accountName != TestUtils.cash }?.accountName, TestUtils.chequing)
    }

    func testSavedPayeeAccount() {
        let description = "abcd"
        let payee = "efg"
        Settings.storage = TestStorage()

        Settings.setAccountMapping(key: payee, account: TestUtils.chequing.fullName)
        Settings.setPayeeMapping(key: description, payee: payee)
        XCTAssertEqual(transactionHelper(description: description).postings.first { $0.accountName != TestUtils.cash }?.accountName, TestUtils.chequing)
    }

    func testGetPossibleDuplicateFor() {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = TestCSVBaseImporter(ledger: ledger, csvReader: TestUtils.csvReader(description: "a", payee: "b", date: transaction.metaData.date), fileName: "")
        importer.delegate = TestUtils.cashAccountDelegate
        importer.load()
        let importedTransaction = importer.nextTransaction()
        XCTAssertNotNil(importedTransaction)
        XCTAssertEqual(importedTransaction!.possibleDuplicate, transaction)
    }

    func testGetPossibleDuplicateForNone() {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = TestCSVBaseImporter(ledger: ledger, csvReader: TestUtils.csvReader(description: "a", payee: "b", date: transaction.metaData.date), fileName: "")
        let delegate = AccountNameProvider(account: TestUtils.chequing)
        importer.delegate = TestUtils.cashAccountDelegate
        importer.delegate = delegate
        importer.load()
        let importedTransaction = importer.nextTransaction()
        XCTAssertNotNil(importedTransaction)
        XCTAssertNil(importedTransaction!.possibleDuplicate)
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
        importer.delegate = TestUtils.cashAccountDelegate
        importer.load()
        let importedTransaction = importer.nextTransaction()
        XCTAssertNotNil(importedTransaction)
        return importedTransaction!.transaction
    }

}
