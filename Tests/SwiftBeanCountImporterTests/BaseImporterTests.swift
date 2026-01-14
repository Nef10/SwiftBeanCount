//
//  BaseImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import Testing

class InvalidAccountNameProvider {
}

extension TestsUsingStorage {

@Suite
struct BaseImporterTests {

    @Test
    func initFunction() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        #expect(importer.ledger == TestUtils.ledger)
    }

    @Test
    func importerName() {
        #expect(BaseImporter.importerName.isEmpty)
    }

    @Test
    func importerType() {
        #expect(BaseImporter.importerType.isEmpty)
    }

    @Test
    func helpText() {
        #expect(BaseImporter.helpText.isEmpty)
    }

    @Test
    func load() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        importer.load()
    }

    @Test
    func importName() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        #expect(importer.importName.isEmpty)
    }

    @Test
    func nextTransaction() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        #expect(importer.nextTransaction() == nil)
    }

    @Test
    func balancesToImport() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        #expect(importer.balancesToImport().isEmpty)
    }

    @Test
    func pricesToImport() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        #expect(importer.pricesToImport().isEmpty)
    }

    @Test
    func commoditySymbol() {
        var importer = BaseImporter(ledger: TestUtils.ledger)
        #expect(importer.commoditySymbol == Settings.fallbackCommodity)

        let cashAccountDelegate = InputProviderDelegate(names: ["Account"], types: [.text([])], returnValues: [TestUtils.cash.fullName])
        importer = BaseImporter(ledger: TestUtils.ledgerCashUSD)
        importer.delegate = cashAccountDelegate
        #expect(importer.commoditySymbol == TestUtils.usd)
        #expect(cashAccountDelegate.verified)
    }

    @Test
    func configuredAccountName() throws {
        let ledger = TestUtils.ledger
        var importer = BaseImporter(ledger: ledger)
        var delegate = AccountNameSuggestionVerifier(expectedValues: [])
        importer.delegate = delegate
        _ = importer.configuredAccountName
        #expect(delegate.verified)

        var account = Account(name: TestUtils.cash, commoditySymbol: TestUtils.usd, metaData: [Settings.importerTypeKey: ""])
        try ledger.add(account)
        importer = BaseImporter(ledger: ledger)
        importer.delegate = TestUtils.noInputDelegate
        #expect(importer.configuredAccountName == TestUtils.cash)

        account = Account(name: TestUtils.chequing, commoditySymbol: TestUtils.usd, metaData: [Settings.importerTypeKey: ""])
        try ledger.add(account)
        importer = BaseImporter(ledger: ledger)
        delegate = AccountNameSuggestionVerifier(expectedValues: [TestUtils.cash, TestUtils.chequing])
        importer.delegate = delegate
        _ = importer.configuredAccountName
        #expect(delegate.verified)

        // When account is set it does not ask again
        importer.delegate = TestUtils.noInputDelegate
        _ = importer.configuredAccountName

        importer = BaseImporter(ledger: ledger)
        let delegate2 = InvalidAccountNameProvider()
        importer.delegate = delegate2
        _ = importer.configuredAccountName
    }

    @Test
    func savedPayee() {
        let description = "abcd"
        let payeeMapping = "efg"
        Settings.storage = TestStorage()

        Settings.setPayeeMapping(key: description, payee: payeeMapping)
        let importer = BaseImporter(ledger: TestUtils.ledger)
        let (_, savedPayee) = importer.savedDescriptionAndPayeeFor(description: description)
        #expect(savedPayee == payeeMapping)
    }

    @Test
    func savedDescription() {
        let description = "abcd"
        let descriptionMapping = "efg"
        Settings.storage = TestStorage()

        Settings.setDescriptionMapping(key: description, description: descriptionMapping)
        let importer = BaseImporter(ledger: TestUtils.ledger)
        let (savedDescription, _) = importer.savedDescriptionAndPayeeFor(description: description)
        #expect(savedDescription == descriptionMapping)
    }

    @Test
    func savedAccount() {
        let payee = "abcd"
        Settings.storage = TestStorage()

        Settings.setAccountMapping(key: payee, account: TestUtils.chequing.fullName)
        let importer = BaseImporter(ledger: TestUtils.ledger)
        #expect(importer.savedAccountNameFor(payee: payee) == TestUtils.chequing)
    }

    @Test
    func getPossibleDuplicateFor() {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = BaseImporter(ledger: ledger)
        #expect(importer.getPossibleDuplicateFor(transaction) == transaction)
    }

    @Test
    func getPossibleDuplicateForDateToleranceInside() {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = BaseImporter(ledger: ledger)

        var importedTransactionMetaData = TransactionMetaData(date: transaction.metaData.date - Settings.dateTolerance,
                                                              payee: "",
                                                              narration: "",
                                                              flag: transaction.metaData.flag,
                                                              tags: [])
        var importedTransaction = Transaction(metaData: importedTransactionMetaData, postings: transaction.postings)

        #expect(importer.getPossibleDuplicateFor(importedTransaction) == transaction)

        importedTransactionMetaData = TransactionMetaData(date: transaction.metaData.date + Settings.dateTolerance,
                                                          payee: transaction.metaData.payee,
                                                          narration: transaction.metaData.narration,
                                                          flag: transaction.metaData.flag,
                                                          tags: transaction.metaData.tags)
        importedTransaction = Transaction(metaData: importedTransactionMetaData, postings: transaction.postings)

        #expect(importer.getPossibleDuplicateFor(importedTransaction) == transaction)
    }

    @Test
    func getPossibleDuplicateForDateToleranceOutside() {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = TestUtils.lederAccounts
        let transaction = TestUtils.transaction
        ledger.add(transaction)

        let importer = BaseImporter(ledger: ledger)

        var importedTransactionMetaData = TransactionMetaData(date: transaction.metaData.date - (Settings.dateTolerance + 1),
                                                              payee: "",
                                                              narration: "",
                                                              flag: transaction.metaData.flag,
                                                              tags: [])
        var importedTransaction = Transaction(metaData: importedTransactionMetaData, postings: transaction.postings)

        #expect(importer.getPossibleDuplicateFor(importedTransaction) == nil)

        importedTransactionMetaData = TransactionMetaData(date: transaction.metaData.date + (Settings.dateTolerance + 1),
                                                          payee: transaction.metaData.payee,
                                                          narration: transaction.metaData.narration,
                                                          flag: transaction.metaData.flag,
                                                          tags: transaction.metaData.tags)
        importedTransaction = Transaction(metaData: importedTransactionMetaData, postings: transaction.postings)

        #expect(importer.getPossibleDuplicateFor(importedTransaction) == nil)
    }

    @Test
    func anitizeDescription() {
        let importer = BaseImporter(ledger: TestUtils.ledger)
        #expect(importer.sanitize(description: "Shop1 C-IDP PURCHASE - 1234  BC  CA") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 IDP PURCHASE-1234") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 VISA DEBIT REF-1234") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 VISA DEBIT PUR-1234") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 INTERAC E-TRF- 1234") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 WWWINTERAC PUR 1234") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 1234 ~ Internet Withdrawal") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 - SAP") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 SAP") == "Shop1")
        #expect(importer.sanitize(description: " SAP CANADA") == "SAP CANADA")
        #expect(importer.sanitize(description: "Shop1 -MAY 2014") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 - JUNE 2016") == "Shop1")
        #expect(importer.sanitize(description: "Shop1  BC  CA") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 #12345") == "Shop1")
        #expect(importer.sanitize(description: "Shop1 # 12") == "Shop1")
    }
}

}

extension InvalidAccountNameProvider: ImporterDelegate {

   func requestInput(name _: String, type _: ImporterInputRequestType, completion: (String) -> Bool) {
        var result = completion("Not an valid account name")
        #expect(!(result))
        result = completion(TestUtils.cash.fullName)
        #expect(result)
    }

   func saveCredential(_: String, for _: String) {
        Issue.record("saveCredential should not be called")
    }

   func readCredential(_: String) -> String? {
        Issue.record("readCredential should not be called")
        return nil
    }

    // swiftlint:disable:next unused_parameter
   func error(_: Error, completion: () -> Void) {
        Issue.record("error should not be called")
    }

#if canImport(UIKit)

   func view() -> UIView? {
        Issue.record("view should not be called")
        return nil
    }

#elseif canImport(AppKit)

   func view() -> NSView? {
        Issue.record("view should not be called")
        return nil
    }

#endif

#if canImport(UIKit) || canImport(AppKit)

   func removeView() {
        Issue.record("removeView should not be called")
    }

#endif

}
