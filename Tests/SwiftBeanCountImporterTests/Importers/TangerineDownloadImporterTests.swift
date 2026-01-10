//
//  TangerineDownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2022-08-20.
//  Copyright © 2022 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import SwiftBeanCountTangerineMapper
import TangerineDownloader
import Testing

#if canImport(UIKit) || canImport(AppKit)

@Suite
struct TangerineDownloadImporterTests {

    private class MockDownloader: TangerineDownloaderProvider {

        weak var delegate: TangerineDownloaderDelegate?

       @Test
       func authorizeAndGetAccounts(username: String, password: String, _ completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
            _ = delegate?.view()
            #expect(delegate?.getOTPCode() == "123456")
            completion(accountsLoading?(username, password) ?? .success([]))
        }

       @Test
       func downloadAccountTransactions(accounts: [String: [String: Any]], dateToLoadFrom: Date) -> Result<[String: [[String: Any]]], Error> {
            transactionsLoading?(accounts, dateToLoadFrom) ?? .success([:])
        }

    }

    private class MockMapper: SwiftBeanCountTangerineMapperProvider {

        let defaultAccountName = defaultAccount

       @Test
       func createTransactions(_ rawTransactions: [String: [[String: Any]]]) throws -> [Transaction] {
            try transactionsMapping?(rawTransactions) ?? []
        }

       @Test
       func ledgerAccountName(account: [String: Any]) throws -> AccountName {
            if let ledgerAccountNameMapping {
                return try ledgerAccountNameMapping(account)
            }
            throw SwiftBeanCountTangerineMapperError.missingAccount(account: String(describing: account))
        }

       @Test
       func createBalances(accounts: [[String: Any]], date: Date) throws -> [Balance] {
            try balancesMapping?(accounts, date) ?? []
        }

    }

    private static var accountsLoading: ((String, String) -> Result<[[String: Any]], Error>)?
    private static var transactionsLoading: (([String: [String: Any]], Date) -> Result<[String: [[String: Any]]], Error>)?
    private static var transactionsMapping: (([String: [[String: Any]]]) throws -> [Transaction])?
    private static var ledgerAccountNameMapping: (([String: Any]) throws -> AccountName)?
    private static var balancesMapping: (([[String: Any]], Date) throws -> [Balance])?
    private static let defaultAccount = try! AccountName("Expenses:Todo") // swiftlint:disable:this force_try

    private let sixtyTwoDays = -60 * 60 * 24 * 62.0
    private let threeDays = -60 * 60 * 24 * 3.0

    private var delegate: CredentialInputAndViewDelegate?

    override func setUp() {
        Self.accountsLoading = nil
        Self.transactionsLoading = nil
        Self.transactionsMapping = nil
        Self.ledgerAccountNameMapping = nil
        Self.balancesMapping = nil
        setDefaultDelegate()
        super.setUp()
    }

   @Test
   func testImporterName() {
        #expect(TangerineDownloadImporter.importerName == "Tangerine Download")
    }

   @Test
   func testImporterType() {
        #expect(TangerineDownloadImporter.importerType == "tangerine-download")
    }

   @Test
   func testHelpText() {
        #expect(TangerineDownloadImporter.helpText.hasPrefix("Downloads transactions and the current balance from the Tangerine website."))
    }

   @Test
   func testImportName() {
        #expect(TangerineDownloadImporter(ledger: nil).importName == "Tangerine Download")
    }

   @Test
   func testSavedCredentials() {
        Self.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success([])
        }
        runImport()
    }

   @Test
   func testNoAccounts() {
        Self.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success([])
        }
        delegate = CredentialInputAndViewDelegate(inputNames: ["Username", "PIN", "SMS Security Code"],
                                                  inputTypes: [.text([]), .secret, .otp],
                                                  inputReturnValues: ["name", "password123", "123456"],
                                                  saveKeys: ["tangerine-download-username", "tangerine-download-password"],
                                                  saveValues: ["name", "password123"],
                                                  readKeys: ["tangerine-download-username", "tangerine-download-password"],
                                                  readReturnValues: ["", ""])
        runImport()
    }

   @Test
   func testRemoveSavedCredentials() {
        let error = TestError()

        Self.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .failure(error)
        }
        delegate = CredentialInputAndViewDelegate(inputNames: ["SMS Security Code", "The login failed. Do you want to remove the saved credentials"],
                                                  inputTypes: [.otp, .bool],
                                                  inputReturnValues: ["123456", "true"],
                                                  saveKeys: [
                                                    "tangerine-download-username",
                                                    "tangerine-download-password",
                                                    "tangerine-download-username",
                                                    "tangerine-download-password",
                                                    "tangerine-download-otp"
                                                  ],
                                                  saveValues: ["name", "password123", "", "", ""],
                                                  readKeys: ["tangerine-download-username", "tangerine-download-password"],
                                                  readReturnValues: ["name", "password123"],
                                                  error: error)
        runImport()
    }

   @Test
   func testTransactionDownloadFailed() {
        let error = TestError()

        Self.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success([])
        }
        Self.transactionsLoading = { _, date in
            #expect(Calendar.current.compare(date, to: Date(timeIntervalSinceNow: sixtyTwoDays), toGranularity: .minute) == .orderedSame)
            return .failure(error)
        }
        setDefaultDelegate(error: error)
        runImport()
    }

   @Test
   func testPastDaysToLoad() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: "tangerine-download-importer", values: ["pastDaysToLoad", "3"]))
        ledger.custom.append(Custom(date: Date(timeIntervalSinceNow: sixtyTwoDays), name: "tangerine-download-importer", values: ["pastDaysToLoad", "200"]))

        Self.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success([])
        }
        Self.transactionsLoading = { _, date in
            #expect(Calendar.current.compare(date, to: Date(timeIntervalSinceNow: threeDays), toGranularity: .minute) == .orderedSame)
            return .success([:])
        }
        runImport(ledger: ledger)
    }

   @Test
   func testTransactionMappingException() throws {
        let error = TestError()

        Self.accountsLoading = { _, _ in
            .success([["account_balance": 10.25, "type": "CHEQUING", "currency_type": "USD", "display_name": "1564894"]])
        }
        Self.transactionsLoading = { _, _ in
            .success(["A": [["TEST": 10]]])
        }
        Self.ledgerAccountNameMapping = { account in
            #expect(account["display_name"] as? String == "1564894")
            return try AccountName("Assets:Checking")
        }
        Self.transactionsMapping = { _ in
            throw error
        }
        setDefaultDelegate(error: error)
        runImport()
    }

   @Test
   func testBalanceMappingException() throws {
        let error = TestError()

        Self.accountsLoading = { _, _ in
            .success([["account_balance": 10.25, "type": "CHEQUING", "currency_type": "USD", "display_name": "1564894"]])
        }
        Self.balancesMapping = { _, _ in
            throw error
        }
        setDefaultDelegate(error: error)
        runImport()
    }

   @Test
   func testDownload() throws { // swiftlint:disable:this function_body_length
        let balance = Balance(date: Date(), accountName: try AccountName("Assets:Testing"), amount: Amount(number: Decimal(20.25), commoditySymbol: "CAD"))
        let transactions = ["A": [["TEST": 10]]]

        let posting1 = Posting(accountName: try AccountName("Assets:Testing"), amount: Amount(number: Decimal(10.25), commoditySymbol: "CAD", decimalDigits: 2))
        let posting2 = Posting(accountName: Self.defaultAccount, amount: Amount(number: -Decimal(10.25), commoditySymbol: "CAD", decimalDigits: 2))
        let transaction = Transaction(metaData: TransactionMetaData(date: Date(), payee: "", narration: "Shop1"), postings: [posting1, posting2])

        Self.accountsLoading = { _, _ in
            .success([["account_balance": 10.25, "type": "CHEQUING", "currency_type": "USD", "display_name": "1564894"]])
        }
        Self.transactionsLoading = { receivedAccounts, _ in
            #expect(receivedAccounts.count == 1)
            #expect(receivedAccounts["Assets:Checking"]?["display_name"] as? String == "1564894")
            return .success(transactions)
        }
        Self.balancesMapping = { receivedAccounts, date in
            #expect(receivedAccounts.count == 1)
            #expect(receivedAccounts[0]["display_name"] as? String == "1564894")
            #expect(Calendar.current.compare(date, to: Date(), toGranularity: .minute) == .orderedSame)
            return [balance]
        }
        Self.ledgerAccountNameMapping = { account in
            #expect(account["display_name"] as? String == "1564894")
            return try AccountName("Assets:Checking")
        }
        Self.transactionsMapping = {
            #expect($0 as? [String: [[String: Int]]] == transactions)
            return [transaction]
        }
        runImport { importer in
            let result = importer.nextTransaction()
            #expect(result?.transaction == transaction)
            #expect(result?.accountName?.fullName == "Assets:Testing")
            #expect(result?.shouldAllowUserToEdit ?? false)
            #expect(importer.nextTransaction() == nil)
            #expect(importer.balancesToImport() == [balance])
        }
        savedMappingTest()
    }

    private func savedMappingTest() {
        Settings.storage = TestStorage()
        Settings.setPayeeMapping(key: "Shop1", payee: "newPayee")
        Settings.setDescriptionMapping(key: "Shop1", description: "new desc")
        Settings.setAccountMapping(key: "newPayee", account: TestUtils.chequing.fullName)
        setDefaultDelegate()
        runImport { importer in
            let result = importer.nextTransaction()
            #expect(result?.accountName?.fullName == "Assets:Testing")
            #expect(result?.shouldAllowUserToEdit ?? false)
            #expect(importer.nextTransaction() == nil)
        }
    }

    private func runImport(ledger: Ledger = Ledger(), verify: ((TangerineDownloadImporter) -> Void)? = nil) {
        let expectation = expectation(description: #function)
        let importer = TangerineDownloadImporter(ledger: ledger, downloader: MockDownloader(), mapper: MockMapper())
        importer.delegate = delegate
        DispatchQueue.global(qos: .userInitiated).async {
            importer.load()
            #expect(importer.pricesToImport().isEmpty)
            #expect(delegate!.verified)
            if let verify {
                verify(importer)
            } else {
                #expect(importer.nextTransaction() == nil)
                #expect(importer.balancesToImport().isEmpty)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    private func setDefaultDelegate(error: TestError? = nil) {
        delegate = CredentialInputAndViewDelegate(inputNames: ["SMS Security Code"],
                                                  inputTypes: [.otp],
                                                  inputReturnValues: ["123456"],
                                                  saveKeys: ["tangerine-download-username", "tangerine-download-password"],
                                                  saveValues: ["name", "password123"],
                                                  readKeys: ["tangerine-download-username", "tangerine-download-password"],
                                                  readReturnValues: ["name", "password123"],
                                                  error: error)
    }

}

#endif
