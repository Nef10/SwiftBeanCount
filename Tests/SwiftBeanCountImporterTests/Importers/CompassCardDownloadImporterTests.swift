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
import XCTest

@available(iOS 14.5, macOS 11.3, *)
final class CompassCardDownloadImporterTests: XCTestCase {

    private class MockDownloader: CompassCardDownloaderProvider {
        weak var delegate: CompassCardDownloaderDelegate?

        func authorizeAndGetBalance(email: String, password: String, _ completion: @escaping (Result<(String, String), Error>) -> Void) {
            _ = delegate?.view()
            completion(authAndBalanceLoading?(email, password) ?? .success(("123456789", "0.00")))
        }

        func downloadCardTransactions(cardNumber: String, dateToLoadFrom: Date, _ completion: @escaping (Result<String, Error>) -> Void) {
            completion(transactionsLoading?(cardNumber, dateToLoadFrom) ?? .success(",\n"))
        }
    }

    private static var authAndBalanceLoading: ((String, String) -> Result<(String, String), Error>)?
    private static var transactionsLoading: ((String, Date) -> Result<String, Error>)?

    private var delegate: CredentialInputAndViewDelegate? // swiftlint:disable:this weak_delegate

    private let sixtyTwoDays = -60 * 60 * 24 * 62.0
    private let threeDays = -60 * 60 * 24 * 3.0

    override func setUp() {
        Self.authAndBalanceLoading = nil
        Self.transactionsLoading = nil
        setDefaultDelegate()
        super.setUp()
    }

    func testImporterName() {
        XCTAssertEqual(CompassCardDownloadImporter.importerName, "Compass Card Download")
    }

    func testImporterType() {
        XCTAssertEqual(CompassCardDownloadImporter.importerType, "compass-card-download")
    }

    func testHelpText() {
        XCTAssert(CompassCardDownloadImporter.helpText.hasPrefix("Downloads transactions and the current balance from the Compass Card website."))
    }

    func testImportName() {
        XCTAssertEqual(CompassCardDownloadImporter(ledger: nil).importName, "Compass Card Download")
    }

    func testSavedCredentials() throws {
        Self.authAndBalanceLoading = {
            XCTAssertEqual($0, "name")
            XCTAssertEqual($1, "password123")
            return .success(("123456789", "0.00"))
        }
        try runImport()
    }

    func testRemoveSavedCredentials() throws {
        let error = TestError()

        Self.authAndBalanceLoading = {
            XCTAssertEqual($0, "name")
            XCTAssertEqual($1, "password123")
            return .failure(error)
        }
        delegate = CredentialInputAndViewDelegate(inputNames: [],
                                                  inputSecrets: [],
                                                  inputReturnValues: [],
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
        try runImport(success: false)
    }

    func testTransactionsDownloadFailed() throws {
        let error = TestError()

        Self.authAndBalanceLoading = {
            XCTAssertEqual($0, "name")
            XCTAssertEqual($1, "password123")
            return .success(("123456789", "0.00"))
        }
        Self.transactionsLoading = { _, date in
            XCTAssertEqual(Calendar.current.compare(date, to: Date(timeIntervalSinceNow: self.sixtyTwoDays), toGranularity: .minute), .orderedSame)
            return .failure(error)
        }
        setDefaultDelegate(error: error)
        try runImport()
    }

    func testPastDaysToLoad() throws {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: "compass-card-download-importer", values: ["pastDaysToLoad", "3"]))
        ledger.custom.append(Custom(date: Date(timeIntervalSinceNow: sixtyTwoDays), name: "compass-card-download-importer", values: ["pastDaysToLoad", "200"]))

        Self.authAndBalanceLoading = {
            XCTAssertEqual($0, "name")
            XCTAssertEqual($1, "password123")
            return .success(("123456789", "0.00"))
        }
        Self.transactionsLoading = { _, date in
            XCTAssertEqual(Calendar.current.compare(date, to: Date(timeIntervalSinceNow: self.threeDays), toGranularity: .minute), .orderedSame)
            return .success(",\n")
        }
        try runImport(ledger: ledger)
    }

    func testDownload() throws {
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

        Self.authAndBalanceLoading = {
            XCTAssertEqual($0, "name")
            XCTAssertEqual($1, "password123")
            return .success(("123456789", "20.50"))
        }
        Self.transactionsLoading = { cardNumber, _ in
            XCTAssertEqual(cardNumber, "123456789")
            return .success(transactions)
        }
        try runImport { importer in
            let result = importer.nextTransaction()
            XCTAssertEqual(result?.transaction, transaction)
            XCTAssertEqual(result?.accountName?.fullName, "Assets:CompassCard")
            XCTAssert(result?.shouldAllowUserToEdit ?? false)
            XCTAssertNil(importer.nextTransaction())
            XCTAssertEqual(importer.balancesToImport().count, 1)
            XCTAssertEqual(importer.balancesToImport().first!.description, balance.description)
        }
    }

    private func runImport(success: Bool = true, ledger: Ledger = Ledger(), verify: ((CompassCardDownloadImporter) -> Void)? = nil) throws {
        let accountName = try AccountName("Assets:CompassCard")
        try ledger.add(Account(name: accountName, metaData: ["card-number": "123456789", "importer-type": "compass-card"]))
        let expectation = expectation(description: #function)
        let importer = CompassCardDownloadImporter(ledger: ledger, downloader: MockDownloader())
        importer.delegate = delegate
        DispatchQueue.global(qos: .userInitiated).async {
            importer.load()
            XCTAssert(importer.pricesToImport().isEmpty)
            XCTAssert(self.delegate!.verified)
            if let verify {
                verify(importer)
            } else {
                XCTAssertNil(importer.nextTransaction())
                if success {
                    XCTAssertEqual(importer.balancesToImport().count, 1)
                    XCTAssertEqual(importer.balancesToImport()[0].accountName, accountName)
                    XCTAssertEqual(importer.balancesToImport()[0].amount.description, "0.00 CAD")
                } else {
                    XCTAssert(importer.balancesToImport().isEmpty)
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    private func setDefaultDelegate(error: TestError? = nil) {
        delegate = CredentialInputAndViewDelegate(inputNames: ["Email", "Password"],
                                                  inputSecrets: [false, true],
                                                  inputReturnValues: ["name", "password123"],
                                                  saveKeys: ["compass-card-download-username", "compass-card-download-password"],
                                                  saveValues: ["name", "password123"],
                                                  readKeys: ["compass-card-download-username", "compass-card-download-password"],
                                                  readReturnValues: ["", ""],
                                                  error: error)
    }

}

#endif
