//
//  WealthsimpleDownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-09-20.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import SwiftBeanCountWealthsimpleMapper
import Wealthsimple
import XCTest

private struct TestAccount: Wealthsimple.Account {
    var accountType = Wealthsimple.AccountType.nonRegistered
    var currency = "CAD"
    var id = "id123"
    var number = "A1B2"
}

private struct TestTransaction: Wealthsimple.Transaction {
    var id = "transID"
    var accountId = "id123"
    var transactionType = Wealthsimple.TransactionType.buy
    var description = ""
    var symbol = "ETF"
    var quantity = "5.25"
    var marketPriceAmount = "2.24"
    var marketPriceCurrency = "CAD"
    var marketValueAmount = "11.76"
    var marketValueCurrency = "CAD"
    var netCashAmount = "-11.76"
    var netCashCurrency = "CAD"
    var fxRate = "1"
    var effectiveDate = Date()
    var processDate = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
}

private struct TestAsset: Wealthsimple.Asset {
    var symbol = "XGRO"
    var name = "Grow ETF"
    var currency = "CAD"
    var type = AssetType.exchangeTradedFund
}

private struct TestPosition: Wealthsimple.Position {
    var accountId = "AccountIDPosition"
    var asset: Wealthsimple.Asset = TestAsset()
    var quantity = "2"
    var priceAmount = "1.11"
    var priceCurrency = "CAD"
    var positionDate = Date()
}

final class WealthsimpleDownloadImporterTests: XCTestCase { // swiftlint:disable:this type_body_length

    private typealias STransaction = SwiftBeanCountModel.Transaction

    private struct TestDownloader: WealthsimpleDownloaderProvider {

        init(authenticationCallback: @escaping WealthsimpleDownloader.AuthenticationCallback, credentialStorage: CredentialStorage) {
            WealthsimpleDownloadImporterTests.authenticationCallback = authenticationCallback
            WealthsimpleDownloadImporterTests.credentialStorage = credentialStorage
            downloader = self
        }

        func authenticate(completion: @escaping (Error?) -> Void) {
            completion(WealthsimpleDownloadImporterTests.authenticate?())
        }

        func getAccounts(completion: @escaping (Result<[Wealthsimple.Account], Wealthsimple.AccountError>) -> Void) {
            completion(WealthsimpleDownloadImporterTests.getAccounts?() ?? .success([]))
        }

        func getPositions(in account: Wealthsimple.Account, date: Date?, completion: @escaping (Result<[Position], PositionError>) -> Void) {
            completion(WealthsimpleDownloadImporterTests.getPositions?(account, date) ?? .success([]))
        }

        func getTransactions(
            in account: Wealthsimple.Account,
            startDate: Date?,
            completion: @escaping (Result<[Wealthsimple.Transaction], Wealthsimple.TransactionError>) -> Void
        ) {
            completion(WealthsimpleDownloadImporterTests.getTransactions?(account, startDate) ?? .success([]))
        }
    }

    private static var downloader: TestDownloader!
    private static var authenticate: (() -> Error?)?
    private static var getAccounts: (() -> Result<[Wealthsimple.Account], Wealthsimple.AccountError>)?
    private static var getPositions: ((Wealthsimple.Account, Date?) -> Result<[Position], PositionError>)?
    private static var getTransactions: ((Wealthsimple.Account, Date?) -> Result<[Wealthsimple.Transaction], TransactionError>)?
    private static var authenticationCallback: WealthsimpleDownloader.AuthenticationCallback!
    private static var credentialStorage: CredentialStorage!

    private let sixtyTwoDays = -60 * 60 * 24 * 62.0
    private let threeDays = -60 * 60 * 24 * 3.0
    private let xgroAccount = try! AccountName("Assets:W:XGRO")

    override func setUpWithError() throws {
        Self.downloader = nil
        Self.authenticate = nil
        Self.getAccounts = nil
        Self.getPositions = nil
        Self.getTransactions = nil
        Self.authenticationCallback = nil
        Self.credentialStorage = nil
        try super.setUpWithError()
    }

    func testImporterName() {
        XCTAssertEqual(WealthsimpleDownloadImporter.importerName, "Wealthsimple Download")
    }

    func testImporterType() {
        XCTAssertEqual(WealthsimpleDownloadImporter.importerType, "wealthsimple")
    }

    func testHelpText() {
        XCTAssert(WealthsimpleDownloadImporter.helpText.hasPrefix("Downloads transactions, prices and balances from Wealthsimple."))
    }

    func testImportName() {
        XCTAssertEqual(WealthsimpleDownloadImporter(ledger: nil).importName, "Wealthsimple Download")
    }

    func testNoData() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssertNil(importer.nextTransaction())
        XCTAssert(importer.balancesToImport().isEmpty)
        XCTAssert(importer.pricesToImport().isEmpty)
    }

    func testLoadAuthenticationError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let error = TestError()
        let delegate = ErrorDelegate(error: error)
        Self.authenticate = { error }
        Self.getAccounts = {
            XCTFail("Accounts should not be requested if authentication fail")
            return .success([])
        }
        Self.getPositions = { _, _ in
            XCTFail("Positions should not be requested if authentication fail")
            return .success([])
        }
        Self.getTransactions = { _, _ in
            XCTFail("Transactions should not be requested if authentication fail")
            return .success([])
        }
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testLoadAccountError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let error = AccountError.httpError(error: "TESTErrorString")
        let delegate = ErrorDelegate(error: error)
        Self.getAccounts = { .failure(error) }
        Self.getPositions = { _, _ in
            XCTFail("Positions should not be requested if accounts fail")
            return .success([])
        }
        Self.getTransactions = { _, _ in
            XCTFail("Transactions should not be requested if accounts fail")
            return .success([])
        }
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testLoad() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        var verifiedPositions = false
        var verifiedTransactions = false
        let account = TestAccount()
        Self.getAccounts = { .success([account]) }
        Self.getPositions = { requestedAccount, date in
            XCTAssertNil(date)
            XCTAssertEqual(requestedAccount.id, account.id)
            XCTAssertEqual(requestedAccount.number, account.number)
            XCTAssertFalse(verifiedPositions)
            verifiedPositions = true
            return .success([])
        }
        Self.getTransactions = { requestedAccount, date in
            XCTAssertEqual(Calendar.current.compare(date!, to: Date(timeIntervalSinceNow: self.sixtyTwoDays), toGranularity: .minute), .orderedSame)
            XCTAssertEqual(requestedAccount.id, account.id)
            XCTAssertEqual(requestedAccount.number, account.number)
            XCTAssertFalse(verifiedTransactions)
            verifiedTransactions = true
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(verifiedPositions)
        XCTAssert(verifiedTransactions)
        XCTAssertNil(importer.nextTransaction())
        XCTAssert(importer.balancesToImport().isEmpty)
        XCTAssert(importer.pricesToImport().isEmpty)
    }

    func testPastDaysToLoad() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: "wealthsimple-importer", values: ["pastDaysToLoad", "3"]))
        ledger.custom.append(Custom(date: Date(timeIntervalSinceNow: sixtyTwoDays), name: "wealthsimple-importer", values: ["pastDaysToLoad", "200"]))
        let importer = WealthsimpleDownloadImporter(ledger: ledger)
        var verifiedTransactions = false
        let account = TestAccount()
        Self.getAccounts = { .success([account]) }
        Self.getPositions = { _, _ in .success([]) }
        Self.getTransactions = { _, date in
            XCTAssertEqual(Calendar.current.compare(date!, to: Date(timeIntervalSinceNow: self.threeDays), toGranularity: .minute), .orderedSame)
            verifiedTransactions = true
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(verifiedTransactions)
    }

    func testLoadTransactions() {
        let ledger = Ledger()
        try! ledger.add(SwiftBeanCountModel.Account(name: try! AccountName("Assets:W:Cash"), metaData: ["importer-type": "wealthsimple", "number": "A1B2"]))
        try! ledger.add(Commodity(symbol: "ETF"))
        try! ledger.add(Commodity(symbol: "CAD"))
        let importer = WealthsimpleDownloadImporter(ledger: ledger)
        let account = TestAccount()
        let transaction1 = TestTransaction()
        var transaction2 = TestTransaction()
        transaction2.transactionType = .paymentSpend
        Self.getAccounts = { .success([account]) }
        Self.getPositions = { _, _ in .success([]) }
        Self.getTransactions = { _, _ in .success([transaction1, transaction2]) }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        var postings = [
            Posting(accountName: try! AccountName("Assets:W:Cash"), amount: Amount(number: Decimal(string: "-11.76")!, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: try! AccountName("Assets:W:ETF"),
                    amount: Amount(number: Decimal(string: transaction1.quantity)!, commoditySymbol: "ETF", decimalDigits: 2),
                    cost: try! Cost(amount: Amount(number: Decimal(string: "2.24")!, commoditySymbol: "CAD", decimalDigits: 2), date: nil, label: nil))
        ]
        var transaction = STransaction(metaData: TransactionMetaData(date: transaction1.processDate, metaData: ["wealthsimple-id": "transID"]), postings: postings)
        XCTAssertEqual(importer.nextTransaction(), ImportedTransaction(transaction))
        postings[1] = Posting(accountName: try! AccountName("Expenses:TODO"), amount: Amount(number: Decimal(string: "11.76")!, commoditySymbol: "CAD", decimalDigits: 2))
        transaction = STransaction(metaData: TransactionMetaData(date: transaction1.processDate, metaData: ["wealthsimple-id": "transID"]), postings: postings)
        XCTAssertEqual(importer.nextTransaction(),
                       ImportedTransaction(transaction, shouldAllowUserToEdit: true, accountName: try! AccountName("Assets:W:Cash")))
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(
            importer.pricesToImport(),
            [try! Price(date: transaction1.processDate, commoditySymbol: "ETF", amount: Amount(number: Decimal(string: "2.24")!, commoditySymbol: "CAD", decimalDigits: 2))]
        )
        XCTAssert(importer.balancesToImport().isEmpty)
    }

    func testLoadPositions() {
        let ledger = Ledger()
        try! ledger.add(SwiftBeanCountModel.Account(name: try! AccountName("Assets:W:Cash"), metaData: ["importer-type": "wealthsimple", "number": "A1B2"]))
        try! ledger.add(Commodity(symbol: "XGRO"))
        try! ledger.add(Commodity(symbol: "CAD"))
        let delegate = BaseTestImporterDelegate()
        let importer = WealthsimpleDownloadImporter(ledger: ledger)
        importer.delegate = delegate
        var account = TestAccount()
        let position = TestPosition()
        account.id = position.accountId
        Self.getAccounts = { .success([account]) }
        Self.getPositions = { _, _ in .success([position]) }
        Self.getTransactions = { _, _ in .success([]) }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(
            importer.pricesToImport(),
            [try! Price(date: position.positionDate, commoditySymbol: "XGRO", amount: Amount(number: Decimal(string: "1.11")!, commoditySymbol: "CAD", decimalDigits: 2))]
        )
        XCTAssertEqual(importer.balancesToImport(),
                       [Balance(date: position.positionDate, accountName: xgroAccount, amount: Amount(number: Decimal(2), commoditySymbol: "XGRO", decimalDigits: 2))])
    }

    func testLoadTransactionMappingError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let account = TestAccount()
        let transaction = TestTransaction()
        let error = WealthsimpleConversionError.missingWealthsimpleAccount("A1B2")
        let delegate = ErrorDelegate(error: error)
        importer.delegate = delegate
        Self.getAccounts = { .success([account]) }
        Self.getPositions = { _, _ in .success([]) }
        Self.getTransactions = { _, _ in .success([transaction]) }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(delegate.verified)
        XCTAssertNil(importer.nextTransaction())
        XCTAssert(importer.pricesToImport().isEmpty)
        XCTAssert(importer.balancesToImport().isEmpty)
    }

    func testLoadPositionMappingError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let account = TestAccount()
        let position = TestPosition()
        let error = WealthsimpleConversionError.accountNotFound("AccountIDPosition")
        let delegate = ErrorDelegate(error: error)
        importer.delegate = delegate
        Self.getAccounts = { .success([account]) }
        Self.getPositions = { _, _ in .success([position]) }
        Self.getTransactions = { _, _ in
            XCTFail("Transactions should not be requested if accounts fail")
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(delegate.verified)
        XCTAssertNil(importer.nextTransaction())
        XCTAssert(importer.pricesToImport().isEmpty)
        XCTAssert(importer.balancesToImport().isEmpty)
    }

    func testLoadAccounts() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        var verifiedPositionsOne = false, verifiedPositionsTwo = false, verifiedTransactionsOne = false, verifiedTransactionsTwo = false
        let account1 = TestAccount(), account2 = TestAccount(id: "id222", number: "C2c2")
        Self.getAccounts = { .success([account1, account2]) }
        Self.getPositions = { requestedAccount, _ in
            if requestedAccount.id == account1.id && requestedAccount.number == account1.number {
                XCTAssertFalse(verifiedPositionsOne)
                verifiedPositionsOne = true
            } else if requestedAccount.id == account2.id && requestedAccount.number == account2.number {
                XCTAssertFalse(verifiedPositionsTwo)
                verifiedPositionsTwo = true
            } else {
                XCTFail("Called with wrong account")
            }
            return .success([])
        }
        Self.getTransactions = { requestedAccount, _ in
            if requestedAccount.id == account1.id && requestedAccount.number == account1.number {
                XCTAssertFalse(verifiedTransactionsOne)
                verifiedTransactionsOne = true
            } else if requestedAccount.id == account2.id && requestedAccount.number == account2.number {
                XCTAssertFalse(verifiedTransactionsTwo)
                verifiedTransactionsTwo = true
            } else {
                XCTFail("Called with wrong account")
            }
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(verifiedPositionsOne)
        XCTAssert(verifiedPositionsTwo)
        XCTAssert(verifiedTransactionsOne)
        XCTAssert(verifiedTransactionsTwo)
    }

    func testPositionError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let account = TestAccount()
        let error = PositionError.httpError(error: "TESTErrorString")
        let delegate = ErrorDelegate(error: error)
        importer.delegate = delegate
        Self.getAccounts = { .success([account]) }
        Self.getPositions = { _, _ in .failure(error) }
        Self.getTransactions = { _, _ in
            XCTFail("Transactions should not be requested if positions fail")
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testTransactionError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let account = TestAccount()
        let error = TransactionError.httpError(error: "TESTErrorString")
        let delegate = ErrorDelegate(error: error)
        importer.delegate = delegate
        Self.getAccounts = { .success([account]) }
        Self.getPositions = { _, _ in .success([]) }
        Self.getTransactions = { _, _ in .failure(error) }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testCredentialStorage() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let delegate = CredentialInputDelegate(saveKeys: ["wealthsimple-testKey2"], saveValues: ["testValue"], readKeys: ["wealthsimple-testKey"], readReturnValues: [nil])
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssertNil(Self.credentialStorage.read("testKey"))
        Self.credentialStorage.save("testValue", for: "testKey2")
        XCTAssert(delegate.verified)
    }

    func testAuthenticationCallback() {
        let expectation = XCTestExpectation(description: "authenticationCallback called")
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let delegate = InputProviderDelegate()
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        Self.authenticationCallback {
            XCTAssertEqual($0, "testUserName")
            XCTAssertEqual($1, "testPassword")
            XCTAssertEqual($2, "testOTP")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
        XCTAssert(delegate.verified)
    }

}

extension Wealthsimple.AccountError: EquatableError {
    public static func == (lhs: Wealthsimple.AccountError, rhs: Wealthsimple.AccountError) -> Bool {
        if case let .httpError(lhsString) = lhs, case let .httpError(rhsString) = rhs {
            return lhsString == rhsString
        }
        return false
    }
}

extension Wealthsimple.PositionError: EquatableError {
    public static func == (lhs: Wealthsimple.PositionError, rhs: Wealthsimple.PositionError) -> Bool {
        if case let .httpError(lhsString) = lhs, case let .httpError(rhsString) = rhs {
            return lhsString == rhsString
        }
        return false
    }
}

extension Wealthsimple.TransactionError: EquatableError {
    public static func == (lhs: Wealthsimple.TransactionError, rhs: Wealthsimple.TransactionError) -> Bool {
        if case let .httpError(lhsString) = lhs, case let .httpError(rhsString) = rhs {
            return lhsString == rhsString
        }
        return false
    }
}

extension WealthsimpleConversionError: EquatableError {
    public static func == (lhs: WealthsimpleConversionError, rhs: WealthsimpleConversionError) -> Bool {
        switch (lhs, rhs) {
        case let (.accountNotFound(lhsString), .accountNotFound(rhsString)):
            return lhsString == rhsString
        case let (.missingWealthsimpleAccount(lhsString), .missingWealthsimpleAccount(rhsString)):
            return lhsString == rhsString
        default:
            return false
        }
    }
} // swiftlint:disable:this file_length
