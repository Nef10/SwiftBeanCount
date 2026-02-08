//
//  CompassCardDownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2023-03-17.
//  Copyright © 2023 Steffen Kötte. All rights reserved.
//

#if canImport(UIKit) || canImport(AppKit)

import CompassCardDownloader
import SwiftBeanCountCompassCardMapper
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import Testing

private class MockDownloader: CompassCardDownloaderProvider {
    weak var delegate: CompassCardDownloaderDelegate?

    var authAndBalanceLoading: ((String, String) -> Result<(String, String), Error>)?
    var transactionsLoading: ((String, Date) -> Result<String, Error>)?

    func authorizeAndGetBalance(email: String, password: String, _ completion: (Result<(String, String), Error>) -> Void) {
        _ = delegate?.view()
        completion(authAndBalanceLoading?(email, password) ?? .success(("123456789", "0.00")))
    }

    func downloadCardTransactions(cardNumber: String, dateToLoadFrom: Date, _ completion: (Result<String, Error>) -> Void) {
        completion(transactionsLoading?(cardNumber, dateToLoadFrom) ?? .success(",\n"))
    }
}

@Suite
struct CompassCardDownloadImporterTests {

    private let sixtyTwoDays = -60 * 60 * 24 * 62.0
    private let threeDays = -60 * 60 * 24 * 3.0

    @Test
    func importerName() {
        #expect(CompassCardDownloadImporter.importerName == "Compass Card Download")
    }

    @Test
    func importerType() {
        #expect(CompassCardDownloadImporter.importerType == "compass-card-download")
    }

    @Test
    func helpText() {
        #expect(CompassCardDownloadImporter.helpText.starts(with: "Downloads transactions and the current balance from the Compass Card website."))
    }

    @Test
    func importName() {
        #expect(CompassCardDownloadImporter(ledger: nil).importName == "Compass Card Download")
    }

    @Test
    func savedCredentials() throws {
        let downloader = MockDownloader()
        downloader.authAndBalanceLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success(("123456789", "0.00"))
        }
        try runImport(downloader: downloader)
    }

    @Test
    func removeSavedCredentials() throws {
        let error = TestError()
        let downloader = MockDownloader()
        downloader.authAndBalanceLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .failure(error)
        }
        let delegate = CredentialInputAndViewDelegate(inputNames: ["The login failed. Do you want to remove the saved credentials"],
                                                      inputTypes: [.bool],
                                                      inputReturnValues: ["true"],
                                                      saveKeys: [
                                                        "compass-card-download-username",
                                                        "compass-card-download-password",
                                                        "compass-card-download-username",
                                                        "compass-card-download-password"
                                                      ],
                                                      saveValues: ["name", "password123", "", ""],
                                                      readKeys: ["compass-card-download-username", "compass-card-download-password"],
                                                      readReturnValues: ["name", "password123"],
                                                      error: error)
        try runImport(downloader: downloader, success: false, delegate: delegate)
    }

    @Test
    func transactionsDownloadFailed() throws {
        let error = TestError()
        let downloader = MockDownloader()
        downloader.authAndBalanceLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success(("123456789", "0.00"))
        }
        let sixtyTwoDays = sixtyTwoDays
        downloader.transactionsLoading = { _, date in
            #expect(Calendar.current.compare(date, to: Date(timeIntervalSinceNow: sixtyTwoDays), toGranularity: .minute) == .orderedSame)
            return .failure(error)
        }
        try runImport(downloader: downloader, delegate: defaultDelegate(error: error))
    }

    @Test
    func pastDaysToLoad() throws {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: "compass-card-download-importer", values: ["pastDaysToLoad", "3"]))
        ledger.custom.append(Custom(date: Date(timeIntervalSinceNow: sixtyTwoDays), name: "compass-card-download-importer", values: ["pastDaysToLoad", "200"]))
        let downloader = MockDownloader()
        downloader.authAndBalanceLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success(("123456789", "0.00"))
        }
        let threeDays = threeDays
        downloader.transactionsLoading = { _, date in
            #expect(Calendar.current.compare(date, to: Date(timeIntervalSinceNow: threeDays), toGranularity: .minute) == .orderedSame)
            return .success(",\n")
        }
        try runImport(downloader: downloader, ledger: ledger)
    }

    @Test
    func download() throws {
        let balance = Balance(date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                              accountName: try AccountName("Assets:CompassCard"),
                              amount: Amount(number: Decimal(20.50), commoditySymbol: "CAD", decimalDigits: 2))
        // swiftlint:disable:next line_length
        let transactions = "DateTime,Transaction,Product,LineItem,Amount,BalanceDetails,JourneyId,LocationDisplay,TransactonTime,OrderDate,Payment,OrderNumber,AuthCode,Total\nNov-17-2022 08:39 PM,Tap in at Bus Stop 60572,Stored Value,,-$2.50,$7.45,2022-11-18T04:39:00.0000000Z,\"Tap in at Bus Stop 60572 Stored Value\",08:39 PM,,,,,\n"

        let posting1 = Posting(accountName: try AccountName("Assets:CompassCard"), amount: Amount(number: -Decimal(2.50), commoditySymbol: "CAD", decimalDigits: 2))
        let posting2 = Posting(accountName: SwiftBeanCountCompassCardMapper(ledger: Ledger()).defaultExpenseAccountName,
                               amount: Amount(number: Decimal(2.50), commoditySymbol: "CAD", decimalDigits: 2))
        let date = Date(timeIntervalSince1970: 1_668_746_340)
        let metaData = TransactionMetaData(date: date, payee: "TransLink", narration: "Bus Stop 60572", metaData: ["journey-id": "2022-11-18T04:39:00.0000000Z"])
        let transaction = Transaction(metaData: metaData, postings: [posting1, posting2])
        let downloader = MockDownloader()
        downloader.authAndBalanceLoading = {
            #expect($0 == "name")
            #expect($1 == "password123")
            return .success(("123456789", "20.50"))
        }
        downloader.transactionsLoading = { cardNumber, _ in
            #expect(cardNumber == "123456789")
            return .success(transactions)
        }
        try runImport(downloader: downloader) { importer in
            let result = importer.nextTransaction()
            #expect(result?.transaction == transaction)
            #expect(result?.accountName?.fullName == "Assets:CompassCard")
            #expect(result?.shouldAllowUserToEdit ?? false)
            #expect(importer.nextTransaction() == nil)
            #expect(importer.balancesToImport().count == 1)
            #expect(importer.balancesToImport().first!.description == balance.description)
        }
    }

    private func runImport(
        downloader: MockDownloader,
        success: Bool = true,
        ledger: Ledger = Ledger(),
        delegate: CredentialInputAndViewDelegate? = nil,
        verify: ((CompassCardDownloadImporter) -> Void)? = nil
    ) throws {
        let delegate = delegate ?? defaultDelegate()
        let accountName = try AccountName("Assets:CompassCard")
        try ledger.add(Account(name: accountName, metaData: ["card-number": "123456789", "importer-type": "compass-card"]))
        let importer = CompassCardDownloadImporter(ledger: ledger, downloader: downloader)
        importer.delegate = delegate
        importer.load()
        #expect(importer.pricesToImport().isEmpty)
        #expect(delegate.verified)
        if let verify {
            verify(importer)
        } else {
            #expect(importer.nextTransaction() == nil)
            if success {
                #expect(importer.balancesToImport().count == 1)
                #expect(importer.balancesToImport()[0].accountName == accountName)
                #expect(importer.balancesToImport()[0].amount.description == "0.00 CAD")
            } else {
                #expect(importer.balancesToImport().isEmpty)
            }
        }
    }

    private func defaultDelegate(error: TestError? = nil) -> CredentialInputAndViewDelegate {
        CredentialInputAndViewDelegate(inputNames: ["Email", "Password"],
                                       inputTypes: [.text([]), .secret],
                                       inputReturnValues: ["name", "password123"],
                                       saveKeys: ["compass-card-download-username", "compass-card-download-password"],
                                       saveValues: ["name", "password123"],
                                       readKeys: ["compass-card-download-username", "compass-card-download-password"],
                                       readReturnValues: ["", ""],
                                       error: error)
    }

}

#endif
