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
import Testing

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

@Suite

struct CSVBaseImporterTests {

    private var cashAccountDelegate: InputProviderDelegate! // swiftlint:disable:this weak_delegate

    override func setUpWithError() throws {
        cashAccountDelegate = InputProviderDelegate(names: ["Account"], types: [.text([])], returnValues: [TestUtils.cash.fullName])
        try super.setUpWithError()
    }

   @Test
   func testImportName() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.basicCSVReader, fileName: "ABCDTEST")
        #expect(importer.importName == "ABCDTEST")
    }

   @Test
   func testLoad() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.basicCSVReader, fileName: "")
        importer.delegate = cashAccountDelegate

        importer.load()
        // Can be called multiple times, still only returns each row once
        importer.load()

        let importedTransaction = importer.nextTransaction()
        #expect(importedTransaction != nil)

        let noTransaction = importer.nextTransaction()
        #expect(noTransaction == nil)
    }

   @Test
   func testLoadSortDate() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.dateMixedCSVReader, fileName: "")
        importer.delegate = cashAccountDelegate
        importer.load()

        let importedTransaction1 = importer.nextTransaction()
        #expect(importedTransaction1 != nil)
        let importedTransaction2 = importer.nextTransaction()
        #expect(importedTransaction2 != nil)

        #expect(importedTransaction1!.transaction.metaData.date < importedTransaction2!.transaction.metaData.date)
    }

   @Test
   func testNextTransaction() {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: TestUtils.basicCSVReader, fileName: "")
        importer.delegate = cashAccountDelegate
        importer.load()

        let importedTransaction = importer.nextTransaction()
        #expect(importedTransaction != nil)
        #expect(importedTransaction!.shouldAllowUserToEdit)
        #expect(importedTransaction!.accountName == TestUtils.cash)

        let noTransaction = importer.nextTransaction()
        #expect(noTransaction == nil)
        #expect(cashAccountDelegate.verified)
    }

   @Test
   func testPrice() throws {
        let transaction = try transactionHelper(description: "price")
        let posting = transaction.postings.first { $0.accountName != TestUtils.cash }!
        #expect(posting.price!.number == -1)
        #expect(posting.amount.number == 10)
        #expect(posting.amount.commoditySymbol == TestUtils.usd)
    }

   @Test
   func testAccountName() throws {
        let transaction = try transactionHelper(description: "")
        #expect(transaction.postings.count == 2)
        #expect(transaction.postings.filter { $0.accountName.fullName == Settings.defaultAccountName }.count == 1)
        #expect(transaction.postings.filter { $0.accountName == TestUtils.cash }.count == 1)
    }

   @Test
   func testSavedPayee() throws {
        let description = "abcd"
        let payeeMapping = "efg"
        Settings.storage = TestStorage()

        Settings.setPayeeMapping(key: description, payee: payeeMapping)
        #expect(try transactionHelper(description: description).metaData.payee == payeeMapping)
    }

   @Test
   func testSavedDescription() throws {
        let description = "abcd"
        let descriptionMapping = "efg"
        Settings.storage = TestStorage()

        Settings.setDescriptionMapping(key: description, description: descriptionMapping)
        #expect(try descriptionHelper(description: description) == descriptionMapping)
    }

   @Test
   func testSavedAccount() throws {
        let payee = "abcd"
        Settings.storage = TestStorage()

        Settings.setAccountMapping(key: payee, account: TestUtils.chequing.fullName)
        #expect(try transactionHelper(description: "" == payee: payee).postings.first { $0.accountName != TestUtils.cash }?.accountName, TestUtils.chequing)
    }

   @Test
   func testSavedPayeeAccount() throws {
        let description = "abcd"
        let payee = "efg"
        Settings.storage = TestStorage()

        Settings.setAccountMapping(key: payee, account: TestUtils.chequing.fullName)
        Settings.setPayeeMapping(key: description, payee: payee)
        #expect(try transactionHelper(description: description).postings.first { $0.accountName != TestUtils.cash }?.accountName == TestUtils.chequing)
    }

   @Test
   func testGetPossibleDuplicateFor() throws {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = TestCSVBaseImporter(ledger: ledger, csvReader: try TestUtils.csvReader(description: "a", payee: "b", date: transaction.metaData.date), fileName: "")
        importer.delegate = cashAccountDelegate
        importer.load()
        let importedTransaction = importer.nextTransaction()
        #expect(importedTransaction != nil)
        #expect(importedTransaction!.possibleDuplicate == transaction)
    }

   @Test
   func testGetPossibleDuplicateForNone() throws {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = TestCSVBaseImporter(ledger: ledger, csvReader: try TestUtils.csvReader(description: "a", payee: "b", date: transaction.metaData.date), fileName: "")
        let delegate = InputProviderDelegate(names: ["Account"], types: [.text([])], returnValues: [TestUtils.chequing.fullName])
        importer.delegate = delegate
        importer.load()
        let importedTransaction = importer.nextTransaction()
        #expect(importedTransaction != nil)
        #expect(importedTransaction!.possibleDuplicate == nil)
        #expect(delegate.verified)
    }

   @Test
   func testSanitizeDescription() throws {
        #expect(try descriptionHelper(description: "Shop1 C-IDP PURCHASE - 1234  BC  CA") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 IDP PURCHASE-1234") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 VISA DEBIT PUR-1234") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 VISA DEBIT REF-1234") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 WWWINTERAC PUR 1234") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 INTERAC E-TRF- 1234") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 1234 ~ Internet Withdrawal") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 - SAP") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 SAP") == "Shop1")
        #expect(try descriptionHelper(description: " SAP CANADA") == "SAP CANADA")
        #expect(try descriptionHelper(description: "Shop1 -MAY 2014") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 - JUNE 2016") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1  BC  CA") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 #12345") == "Shop1")
        #expect(try descriptionHelper(description: "Shop1 # 12") == "Shop1")
    }

    private func descriptionHelper(description: String) throws -> String {
        try transactionHelper(description: description).metaData.narration
    }

    private func transactionHelper(description: String, payee: String = "payee") throws -> Transaction {
        let importer = TestCSVBaseImporter(ledger: nil, csvReader: try TestUtils.csvReader(description: description, payee: payee), fileName: "")
        cashAccountDelegate = InputProviderDelegate(names: ["Account"], types: [.text([])], returnValues: [TestUtils.cash.fullName])
        importer.delegate = cashAccountDelegate
        importer.load()
        let importedTransaction = importer.nextTransaction()
        #expect(importedTransaction != nil)
        #expect(cashAccountDelegate.verified)
        return importedTransaction!.transaction
    }

}
