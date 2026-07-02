//
//  WealthsimpleDownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-09-20.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import SwiftBeanCountWealthsimpleMapper
import Testing
import WealthsimpleDownloader

private typealias STransaction = SwiftBeanCountModel.Transaction

private var authenticateClosure: (() -> Error?)?
private var getAccountsClosure: (() -> Result<[WealthsimpleDownloader.Account], WealthsimpleDownloader.AccountError>)?
private var getPositionsClosure: ((WealthsimpleDownloader.Account, Date?) -> Result<[WealthsimpleDownloader.Position], WealthsimpleDownloader.PositionError>)?
private var getTransactionsClosure: ((WealthsimpleDownloader.Account, Date?) -> Result<[WealthsimpleDownloader.Transaction], WealthsimpleDownloader.TransactionError>)?
private var authenticationCallbackClosure: WealthsimpleAPI.AuthenticationCallback?
private var credentialStorageClosure: CredentialStorage?

private struct TestAccount: WealthsimpleDownloader.Account {
    var accountType = WealthsimpleDownloader.AccountType.nonRegistered
    var currency = "CAD"
    var id = "id123"
    var number = "A1B2"
}

private struct TestTransaction: WealthsimpleDownloader.Transaction {
    var id = "transID"
    var accountId = "id123"
    var transactionType = WealthsimpleDownloader.TransactionType.buy
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

private struct TestAsset: WealthsimpleDownloader.Asset {
    var symbol = "XGRO"
    var name = "Grow ETF"
    var currency = "CAD"
    var type = AssetType.exchangeTradedFund
}

private struct TestPosition: WealthsimpleDownloader.Position {
    var accountId = "AccountIDPosition"
    var asset: WealthsimpleDownloader.Asset = TestAsset()
    var quantity = "2"
    var priceAmount = "1.11"
    var priceCurrency = "CAD"
    var positionDate = Date()
}

private struct TestDownloader: WealthsimpleDownloaderProvider {

    init(authenticationCallback: @escaping WealthsimpleAPI.AuthenticationCallback, credentialStorage: CredentialStorage) {
        authenticationCallbackClosure = authenticationCallback
        credentialStorageClosure = credentialStorage
    }

    func authenticate(completion: (Error?) -> Void) {
        completion(authenticateClosure?())
    }

    func getAccounts(completion: (Result<[WealthsimpleDownloader.Account], WealthsimpleDownloader.AccountError>) -> Void) {
        completion(getAccountsClosure?() ?? .success([]))
    }

    func getPositions(in account: WealthsimpleDownloader.Account, date: Date?, completion: (Result<[Position], PositionError>) -> Void) {
        completion(getPositionsClosure?(account, date) ?? .success([]))
    }

    func getTransactions(
        in account: WealthsimpleDownloader.Account,
        startDate: Date,
        completion: (Result<[WealthsimpleDownloader.Transaction], WealthsimpleDownloader.TransactionError>) -> Void
    ) {
        completion(getTransactionsClosure?(account, startDate) ?? .success([]))
    }
}

extension TestsUsingStorage {

@Suite
struct WealthsimpleDownloadImporterTests { // swiftlint:disable:this type_body_length

    private let sixtyTwoDays = -60 * 60 * 24 * 62.0
    private let threeDays = -60 * 60 * 24 * 3.0
    private let xgroAccount = try! AccountName("Assets:W:XGRO") // swiftlint:disable:this force_try

    init() {
        authenticateClosure = nil
        getAccountsClosure = nil
        getPositionsClosure = nil
        getTransactionsClosure = nil
        authenticationCallbackClosure = nil
        credentialStorageClosure = nil
    }

    @Test
    func importerName() {
        #expect(WealthsimpleDownloadImporter.importerName == "Wealthsimple Download")
    }

    @Test
    func importerType() {
        #expect(WealthsimpleDownloadImporter.importerType == "wealthsimple")
    }

    @Test
    func helpText() {
        #expect(WealthsimpleDownloadImporter.helpText.hasPrefix("Downloads transactions, prices and balances from Wealthsimple."))
    }

    @Test
    func importName() {
        #expect(WealthsimpleDownloadImporter(ledger: nil).importName == "Wealthsimple Download")
    }

    @Test
    func noData() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(importer.nextTransaction() == nil)
        #expect(importer.balancesToImport().isEmpty)
        #expect(importer.pricesToImport().isEmpty)
    }

    @Test
    func loadAuthenticationError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let error = TestError()
        let delegate = ErrorDelegate(error: error)
        authenticateClosure = { error }
        getAccountsClosure = {
            Issue.record("Accounts should not be requested if authentication fail")
            return .success([])
        }
        getPositionsClosure = { _, _ in
            Issue.record("Positions should not be requested if authentication fail")
            return .success([])
        }
        getTransactionsClosure = { _, _ in
            Issue.record("Transactions should not be requested if authentication fail")
            return .success([])
        }
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(delegate.verified)
    }

    @Test
    func loadAccountError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let error = AccountError.httpError(error: "TESTErrorString")
        let delegate = ErrorDelegate(error: error)
        getAccountsClosure = { .failure(error) }
        getPositionsClosure = { _, _ in
            Issue.record("Positions should not be requested if accounts fail")
            return .success([])
        }
        getTransactionsClosure = { _, _ in
            Issue.record("Transactions should not be requested if accounts fail")
            return .success([])
        }
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(delegate.verified)
    }

    @Test
    func load() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        var verifiedPositions = false
        var verifiedTransactions = false
        let account = TestAccount()
        let sixtyTwoDays = sixtyTwoDays
        getAccountsClosure = { .success([account]) }
        getPositionsClosure = { requestedAccount, date in
            #expect(date == nil)
            #expect(requestedAccount.id == account.id)
            #expect(requestedAccount.number == account.number)
            #expect(!verifiedPositions)
            verifiedPositions = true
            return .success([])
        }
        getTransactionsClosure = { requestedAccount, date in
            #expect(Calendar.current.compare(date!, to: Date(timeIntervalSinceNow: sixtyTwoDays), toGranularity: .minute) == .orderedSame)
            #expect(requestedAccount.id == account.id)
            #expect(requestedAccount.number == account.number)
            #expect(!verifiedTransactions)
            verifiedTransactions = true
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(verifiedPositions)
        #expect(verifiedTransactions)
        #expect(importer.nextTransaction() == nil)
        #expect(importer.balancesToImport().isEmpty)
        #expect(importer.pricesToImport().isEmpty)
    }

    @Test
    func pastDaysToLoad() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: "wealthsimple-importer", values: ["pastDaysToLoad", "3"]))
        ledger.custom.append(Custom(date: Date(timeIntervalSinceNow: sixtyTwoDays), name: "wealthsimple-importer", values: ["pastDaysToLoad", "200"]))
        let importer = WealthsimpleDownloadImporter(ledger: ledger)
        var verifiedTransactions = false
        let account = TestAccount()
        let threeDays = threeDays
        getAccountsClosure = { .success([account]) }
        getPositionsClosure = { _, _ in .success([]) }
        getTransactionsClosure = { _, date in
            #expect(Calendar.current.compare(date!, to: Date(timeIntervalSinceNow: threeDays), toGranularity: .minute) == .orderedSame)
            verifiedTransactions = true
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(verifiedTransactions)
    }

    @Test
    func loadTransactions() throws {
        let ledger = Ledger()
        try ledger.add(SwiftBeanCountModel.Account(name: try AccountName("Assets:W:Cash"), metaData: ["importer-type": "wealthsimple", "number": "A1B2"]))
        try ledger.add(Commodity(symbol: "ETF"))
        try ledger.add(Commodity(symbol: "CAD"))
        let importer = WealthsimpleDownloadImporter(ledger: ledger), account = TestAccount(), transaction1 = TestTransaction()
        var transaction2 = TestTransaction()
        transaction2.transactionType = .paymentSpend
        transaction2.quantity = "-5.25"
        getAccountsClosure = { .success([account]) }
        getPositionsClosure = { _, _ in .success([]) }
        getTransactionsClosure = { _, _ in .success([transaction1, transaction2]) }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        let postings = [
            Posting(accountName: try AccountName("Assets:W:Cash"), amount: Amount(number: Decimal(string: "-11.76")!, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: try AccountName("Assets:W:ETF"),
                    amount: Amount(number: Decimal(string: transaction1.quantity)!, commoditySymbol: "ETF", decimalDigits: 2),
                    cost: try Cost(amount: Amount(number: Decimal(string: "2.24")!, commoditySymbol: "CAD", decimalDigits: 2), date: nil, label: nil))
        ]
        let metaData = TransactionMetaData(date: transaction1.processDate, metaData: ["wealthsimple-id": "transID"])
        #expect(importer.nextTransaction() == ImportedTransaction(STransaction(metaData: metaData, postings: postings)))
        let price = Amount(number: Decimal(string: "11.76")!, commoditySymbol: "CAD", decimalDigits: 2)
        let transaction = STransaction(metaData: metaData, postings: [
            postings[0],
            try Posting(accountName: try AccountName("Expenses:TODO"), amount: postings[1].amount, price: price, priceType: .total)
        ])
        #expect(importer.nextTransaction() == ImportedTransaction(transaction, shouldAllowUserToEdit: true, accountName: postings[0].accountName))
        #expect(importer.nextTransaction() == nil)
        #expect(importer.pricesToImport() == [try Price(date: transaction1.processDate, commoditySymbol: "ETF", amount: postings[1].cost!.amount!)])
        #expect(importer.balancesToImport().isEmpty)
    }

    @Test
    func loadPositions() throws {
        let ledger = Ledger()
        try ledger.add(SwiftBeanCountModel.Account(name: try AccountName("Assets:W:Cash"), metaData: ["importer-type": "wealthsimple", "number": "A1B2"]))
        try ledger.add(Commodity(symbol: "XGRO"))
        try ledger.add(Commodity(symbol: "CAD"))
        let delegate = BaseTestImporterDelegate()
        let importer = WealthsimpleDownloadImporter(ledger: ledger)
        importer.delegate = delegate
        var account = TestAccount()
        let position = TestPosition()
        account.id = position.accountId
        getAccountsClosure = { .success([account]) }
        getPositionsClosure = { _, _ in .success([position]) }
        getTransactionsClosure = { _, _ in .success([]) }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(importer.nextTransaction() == nil)
        let expectedPrice = try Price(date: position.positionDate,
                                      commoditySymbol: "XGRO",
                                      amount: Amount(number: Decimal(string: "1.11")!, commoditySymbol: "CAD", decimalDigits: 2))
        #expect(importer.pricesToImport() == [expectedPrice])
        #expect(importer.balancesToImport()
            == [Balance(date: position.positionDate, accountName: xgroAccount, amount: Amount(number: Decimal(2), commoditySymbol: "XGRO", decimalDigits: 2))])
    }

    @Test
    func loadTransactionMappingError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let transaction = TestTransaction()
        let error = WealthsimpleConversionError.missingWealthsimpleAccount("A1B2")
        let delegate = ErrorDelegate(error: error)
        importer.delegate = delegate
        getAccountsClosure = { .success([TestAccount()]) }
        getPositionsClosure = { _, _ in .success([]) }
        getTransactionsClosure = { _, _ in .success([transaction]) }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(delegate.verified)
        #expect(importer.nextTransaction() == nil)
        #expect(importer.pricesToImport().isEmpty)
        #expect(importer.balancesToImport().isEmpty)
    }

    @Test
    func loadPositionMappingError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let position = TestPosition()
        let error = WealthsimpleConversionError.accountNotFound("AccountIDPosition")
        let delegate = ErrorDelegate(error: error)
        importer.delegate = delegate
        getAccountsClosure = { .success([TestAccount()]) }
        getPositionsClosure = { _, _ in .success([position]) }
        getTransactionsClosure = { _, _ in
            Issue.record("Transactions should not be requested if accounts fail")
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(delegate.verified)
        #expect(importer.nextTransaction() == nil)
        #expect(importer.pricesToImport().isEmpty)
        #expect(importer.balancesToImport().isEmpty)
    }

    @Test
    func loadAccounts() { // swiftlint:disable:this function_body_length
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        var verifiedPositionsOne = false, verifiedPositionsTwo = false, verifiedTransactionsOne = false, verifiedTransactionsTwo = false
        let account1 = TestAccount(), account2 = TestAccount(id: "id222", number: "C2c2")
        getAccountsClosure = { .success([account1, account2]) }
        getPositionsClosure = { requestedAccount, _ in
            if requestedAccount.id == account1.id && requestedAccount.number == account1.number {
                #expect(!verifiedPositionsOne)
                verifiedPositionsOne = true
            } else if requestedAccount.id == account2.id && requestedAccount.number == account2.number {
                #expect(!verifiedPositionsTwo)
                verifiedPositionsTwo = true
            } else {
                Issue.record("Called with wrong account")
            }
            return .success([])
        }
        getTransactionsClosure = { requestedAccount, _ in
            if requestedAccount.id == account1.id && requestedAccount.number == account1.number {
                #expect(!verifiedTransactionsOne)
                verifiedTransactionsOne = true
            } else if requestedAccount.id == account2.id && requestedAccount.number == account2.number {
                #expect(!verifiedTransactionsTwo)
                verifiedTransactionsTwo = true
            } else {
                Issue.record("Called with wrong account")
            }
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(verifiedPositionsOne)
        #expect(verifiedPositionsTwo)
        #expect(verifiedTransactionsOne)
        #expect(verifiedTransactionsTwo)
    }

    @Test
    func positionError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let error = PositionError.httpError(error: "TESTErrorString")
        let delegate = ErrorDelegate(error: error)
        importer.delegate = delegate
        getAccountsClosure = { .success([TestAccount()]) }
        getPositionsClosure = { _, _ in .failure(error) }
        getTransactionsClosure = { _, _ in
            Issue.record("Transactions should not be requested if positions fail")
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(delegate.verified)
    }

    @Test
    func transactionError() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let error = TransactionError.httpError(error: "TESTErrorString")
        let delegate = ErrorDelegate(error: error)
        importer.delegate = delegate
        getAccountsClosure = { .success([TestAccount()]) }
        getPositionsClosure = { _, _ in .success([]) }
        getTransactionsClosure = { _, _ in .failure(error) }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(delegate.verified)
    }

    @Test
    func credentialStorage() {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let delegate = CredentialInputDelegate(saveKeys: ["wealthsimple-testKey2"], saveValues: ["testValue"], readKeys: ["wealthsimple-testKey"], readReturnValues: [nil])
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        #expect(credentialStorageClosure?.read("testKey") == nil)
        credentialStorageClosure?.save("testValue", for: "testKey2")
        #expect(delegate.verified)
    }

    @Test
    func authenticationCallback() async {
        let importer = WealthsimpleDownloadImporter(ledger: nil)
        let delegate = InputProviderDelegate()
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        await confirmation { confirm in
            authenticationCallbackClosure? {
                #expect($0 == "testUserName")
                #expect($1 == "testPassword")
                #expect($2 == "testOTP")
                confirm()
            }
        }
        #expect(delegate.verified)
    }

}
}

extension WealthsimpleDownloader.AccountError: EquatableError {
    public static func == (lhs: WealthsimpleDownloader.AccountError, rhs: WealthsimpleDownloader.AccountError) -> Bool {
        if case let .httpError(lhsString) = lhs, case let .httpError(rhsString) = rhs {
            return lhsString == rhsString
        }
        return false
    }
}

extension WealthsimpleDownloader.PositionError: EquatableError {
    public static func == (lhs: WealthsimpleDownloader.PositionError, rhs: WealthsimpleDownloader.PositionError) -> Bool {
        if case let .httpError(lhsString) = lhs, case let .httpError(rhsString) = rhs {
            return lhsString == rhsString
        }
        return false
    }
}

extension WealthsimpleDownloader.TransactionError: EquatableError {
    public static func == (lhs: WealthsimpleDownloader.TransactionError, rhs: WealthsimpleDownloader.TransactionError) -> Bool {
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
