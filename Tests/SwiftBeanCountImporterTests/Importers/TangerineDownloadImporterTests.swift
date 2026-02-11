//
//  TangerineDownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2022-08-20.
//  Copyright © 2022 Steffen Kötte. All rights reserved.
//

#if canImport(UIKit) || canImport(AppKit)

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import SwiftBeanCountTangerineMapper
import TangerineDownloader
import Testing

private let defaultAccount = try! AccountName("Expenses:Todo") // swiftlint:disable:this force_try

private class MockDownloader: TangerineDownloaderProvider {

    weak var delegate: TangerineDownloaderDelegate?

    var accountsLoading: ((String, String) -> Result<[[String: Any]], Error>)?
    var transactionsLoading: (([String: [String: Any]], Date) -> Result<[String: [[String: Any]]], Error>)?

    func authorizeAndGetAccounts(username: String, password: String, _ completion: (Result<[[String: Any]], Error>) -> Void) {
        _ = delegate?.view()
        #expect(delegate?.getOTPCode() == "123456")
        completion(accountsLoading?(username, password) ?? .success([]))
    }

    func downloadAccountTransactions(accounts: [String: [String: Any]], dateToLoadFrom: Date) -> Result<[String: [[String: Any]]], Error> {
        transactionsLoading?(accounts, dateToLoadFrom) ?? .success([:])
    }

}

private class MockMapper: SwiftBeanCountTangerineMapperProvider {

    let defaultAccountName = defaultAccount

    var transactionsMapping: (([String: [[String: Any]]]) throws -> [Transaction])?
    var ledgerAccountNameMapping: (([String: Any]) throws -> AccountName)?
    var balancesMapping: (([[String: Any]], Date) throws -> [Balance])?

    func createTransactions(_ rawTransactions: [String: [[String: Any]]]) throws -> [Transaction] {
        try transactionsMapping?(rawTransactions) ?? []
    }

    func ledgerAccountName(account: [String: Any]) throws -> AccountName {
        if let ledgerAccountNameMapping {
            return try ledgerAccountNameMapping(account)
        }
        throw SwiftBeanCountTangerineMapperError.missingAccount(account: String(describing: account))
    }

    func createBalances(accounts: [[String: Any]], date: Date) throws -> [Balance] {
        try balancesMapping?(accounts, date) ?? []
    }

}

@Suite
struct TangerineDownloadImporterTests {

    private let sixtyTwoDays = -60 * 60 * 24 * 62.0
    private let threeDays = -60 * 60 * 24 * 3.0

    @Test
    func importerName() {
        #expect(TangerineDownloadImporter.importerName == "Tangerine Download")
    }

    @Test
    func importerType() {
        #expect(TangerineDownloadImporter.importerType == "tangerine-download")
    }

    @Test
    func helpText() {
        #expect(TangerineDownloadImporter.helpText.starts(with: "Downloads transactions and the current balance from the Tangerine website."))
    }

    @Test
    func importName() {
        #expect(TangerineDownloadImporter(ledger: nil).importName == "Tangerine Download")
    }

    @Test
    func savedCredentials() {
        let downloader = MockDownloader()
        downloader.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success([])
        }
        runImport(downloader: downloader)
    }

    @Test
    func noAccounts() {
        let downloader = MockDownloader()
        downloader.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success([])
        }
        let delegate = CredentialInputAndViewDelegate(inputNames: ["Username", "PIN", "SMS Security Code"],
                                                      inputTypes: [.text([]), .secret, .otp],
                                                      inputReturnValues: ["name", "password123", "123456"],
                                                      saveKeys: ["tangerine-download-username", "tangerine-download-password"],
                                                      saveValues: ["name", "password123"],
                                                      readKeys: ["tangerine-download-username", "tangerine-download-password"],
                                                      readReturnValues: ["", ""])
        runImport(downloader: downloader, delegate: delegate)
    }

    @Test
    func removeSavedCredentials() {
        let error = TestError()
        let downloader = MockDownloader()
        downloader.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .failure(error)
        }
        let delegate = CredentialInputAndViewDelegate(inputNames: ["SMS Security Code", "The login failed. Do you want to remove the saved credentials"],
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
        runImport(downloader: downloader, delegate: delegate)
    }

    @Test
    func transactionDownloadFailed() {
        let error = TestError()
        let downloader = MockDownloader()
        downloader.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success([])
        }
        let sixtyTwoDays = sixtyTwoDays
        downloader.transactionsLoading = { _, date in
            #expect(Calendar.current.compare(date, to: Date(timeIntervalSinceNow: sixtyTwoDays), toGranularity: .minute) == .orderedSame)
            return .failure(error)
        }
        runImport(downloader: downloader, delegate: defaultDelegate(error: error))
    }

    @Test
    func pastDaysToLoad() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: "tangerine-download-importer", values: ["pastDaysToLoad", "3"]))
        ledger.custom.append(Custom(date: Date(timeIntervalSinceNow: sixtyTwoDays), name: "tangerine-download-importer", values: ["pastDaysToLoad", "200"]))
        let downloader = MockDownloader()
        downloader.accountsLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success([])
        }
        let threeDays = threeDays
        downloader.transactionsLoading = { _, date in
            #expect(Calendar.current.compare(date, to: Date(timeIntervalSinceNow: threeDays), toGranularity: .minute) == .orderedSame)
            return .success([:])
        }
        runImport(downloader: downloader, ledger: ledger)
    }

    @Test
    func transactionMappingException() throws {
        let error = TestError()
        let downloader = MockDownloader()
        let mapper = MockMapper()
        downloader.accountsLoading = { _, _ in
            .success([["account_balance": 10.25, "type": "CHEQUING", "currency_type": "USD", "display_name": "1564894"]])
        }
        downloader.transactionsLoading = { _, _ in
            .success(["A": [["TEST": 10]]])
        }
        mapper.ledgerAccountNameMapping = { account in
            #expect(account["display_name"] as? String == "1564894")
            return try AccountName("Assets:Checking")
        }
        mapper.transactionsMapping = { _ in
            throw error
        }
        runImport(downloader: downloader, mapper: mapper, delegate: defaultDelegate(error: error))
    }

    @Test
    func balanceMappingException() throws {
        let error = TestError()
        let downloader = MockDownloader()
        let mapper = MockMapper()
        downloader.accountsLoading = { _, _ in
            .success([["account_balance": 10.25, "type": "CHEQUING", "currency_type": "USD", "display_name": "1564894"]])
        }
        mapper.balancesMapping = { _, _ in
            throw error
        }
        runImport(downloader: downloader, mapper: mapper, delegate: defaultDelegate(error: error))
    }

    @Test
    func download() throws { // swiftlint:disable:this function_body_length
        let balance = Balance(date: Date(), accountName: try AccountName("Assets:Testing"), amount: Amount(number: Decimal(20.25), commoditySymbol: "CAD"))
        let transactions = ["A": [["TEST": 10]]]

        let posting1 = Posting(accountName: try AccountName("Assets:Testing"), amount: Amount(number: Decimal(10.25), commoditySymbol: "CAD", decimalDigits: 2))
        let posting2 = Posting(accountName: defaultAccount, amount: Amount(number: -Decimal(10.25), commoditySymbol: "CAD", decimalDigits: 2))
        let transaction = Transaction(metaData: TransactionMetaData(date: Date(), payee: "", narration: "Shop1"), postings: [posting1, posting2])

        let downloader = MockDownloader()
        let mapper = MockMapper()
        downloader.accountsLoading = { _, _ in
            .success([["account_balance": 10.25, "type": "CHEQUING", "currency_type": "USD", "display_name": "1564894"]])
        }
        downloader.transactionsLoading = { receivedAccounts, _ in
            #expect(receivedAccounts.count == 1)
            #expect(receivedAccounts["Assets:Checking"]?["display_name"] as? String == "1564894")
            return .success(transactions)
        }
        mapper.balancesMapping = { receivedAccounts, date in
            #expect(receivedAccounts.count == 1)
            #expect(receivedAccounts[0]["display_name"] as? String == "1564894")
            #expect(Calendar.current.compare(date, to: Date(), toGranularity: .minute) == .orderedSame)
            return [balance]
        }
        mapper.ledgerAccountNameMapping = { account in
            #expect(account["display_name"] as? String == "1564894")
            return try AccountName("Assets:Checking")
        }
        mapper.transactionsMapping = {
            #expect($0 as? [String: [[String: Int]]] == transactions)
            return [transaction]
        }
        runImport(downloader: downloader, mapper: mapper) { importer in
            let result = importer.nextTransaction()
            #expect(result?.transaction == transaction)
            #expect(result?.accountName?.fullName == "Assets:Testing")
            #expect(result?.shouldAllowUserToEdit ?? false)
            #expect(importer.nextTransaction() == nil)
            #expect(importer.balancesToImport() == [balance])
        }
        savedMappingTest(downloader: downloader, mapper: mapper)
    }

    private func savedMappingTest(downloader: MockDownloader, mapper: MockMapper) {
        Settings.storage = TestStorage()
        Settings.setPayeeMapping(key: "Shop1", payee: "newPayee")
        Settings.setDescriptionMapping(key: "Shop1", description: "new desc")
        Settings.setAccountMapping(key: "newPayee", account: TestUtils.chequing.fullName)
        runImport(downloader: downloader, mapper: mapper) { importer in
            let result = importer.nextTransaction()
            #expect(result?.accountName?.fullName == "Assets:Testing")
            #expect(result?.shouldAllowUserToEdit ?? false)
            #expect(importer.nextTransaction() == nil)
        }
    }

    private func runImport(
        downloader: MockDownloader,
        mapper: MockMapper? = nil,
        ledger: Ledger = Ledger(),
        delegate: CredentialInputAndViewDelegate? = nil,
        verify: ((TangerineDownloadImporter) -> Void)? = nil
    ) {
        let delegate = delegate ?? defaultDelegate()
        let importer = TangerineDownloadImporter(ledger: ledger, downloader: downloader, mapper: mapper ?? MockMapper())
        importer.delegate = delegate
        importer.load()
        #expect(importer.pricesToImport().isEmpty)
        #expect(delegate.verified)
        if let verify {
            verify(importer)
        } else {
            #expect(importer.nextTransaction() == nil)
            #expect(importer.balancesToImport().isEmpty)
        }
    }

    private func defaultDelegate(error: TestError? = nil) -> CredentialInputAndViewDelegate {
        CredentialInputAndViewDelegate(inputNames: ["SMS Security Code"],
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
