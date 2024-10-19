//
//  RogersDownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-10-03.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import RogersBankDownloader
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import SwiftBeanCountRogersBankMapper
import XCTest

private typealias STransaction = SwiftBeanCountModel.Transaction
private typealias RAmount = RogersBankDownloader.Amount

private struct TestAmount: RogersBankDownloader.Amount {
    var value = "0.00"
    var currency = "CAD"
}

private struct TestCustomer: Customer {
    var customerId = "cid123"
    var cardLast4 = "8520"
    var customerType = "primary"
    var firstName = "first"
    var lastName = "last"
}

private struct TestAccount: RogersBankDownloader.Account {
    var customer: Customer = TestCustomer()
    var accountId = "abc123id"
    var accountType = "creditAccount"
    var paymentStatus = "ok"
    var productName = "we"
    var productExternalCode = "we-code"
    var accountCurrency = "CAD"
    var brandId = "r"
    var openedDate = Date()
    var previousStatementDate = Date()
    var paymentDueDate = Date()
    var lastPaymentDate = Date()
    var cycleDates = [Date]()
    var currentBalance: RAmount = TestAmount()
    var statementBalance: RAmount = TestAmount()
    var statementDueAmount: RAmount = TestAmount()
    var creditLimit: RAmount = TestAmount()
    var purchasesSinceLastCycle: RAmount?
    var lastPayment: RAmount = TestAmount()
    var realtimeBalance: RAmount = TestAmount()
    var cashAvailable: RAmount = TestAmount()
    var cashLimit: RAmount = TestAmount()
    var multiCard = false

    private var activityCallback: ((Int) -> Result<[Activity], DownloadError>)?

    init(activityCallback: ((Int) -> Result<[Activity], DownloadError>)? = nil) {
        self.activityCallback = activityCallback
    }

    func downloadActivities(statementNumber: Int, completion: @escaping (Result<[Activity], DownloadError>) -> Void) {
        completion(activityCallback?(statementNumber) ?? .success([]))
    }

    func downloadStatement(statement: Statement, completion: @escaping (Result<URL, DownloadError>) -> Void) {
    }

    func searchStatements(completion: @escaping (Result<[Statement], DownloadError>) -> Void) {
    }

}

private struct TestMerchant: Merchant {
    var name: String = "Test Merchant Name"
    var categoryCode: String?
    var categoryDescription: String?
    var category: String = "MCat"
    var address: Address?
}

private struct TestActivity: Activity, Equatable {
    private let uuid = UUID()

    var referenceNumber: String?
    var activityType = ActivityType.transaction
    var amount: RAmount = TestAmount()
    var activityStatus = ActivityStatus.approved
    var activityCategory = ActivityCategory.purchase
    var activityClassification = "class"
    var cardNumber = "XXXX XXXX XXXX 8520"
    var merchant: Merchant = TestMerchant()
    var foreign: ForeignCurrency?
    var date = Date()
    var activityCategoryCode: String?
    var customerId = "cid1234"
    var postedDate: Date? = Date()
    var activityId: String?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.uuid == rhs.uuid
    }
}

final class RogersDownloadImporterTests: XCTestCase { // swiftlint:disable:this type_body_length

    private struct TestUser: User {
        var userName = "Rogers Bank Username"
        var accounts = [RogersBankDownloader.Account]()
        var authenticated = true

        static func load(username: String, password: String, deviceId: String, deviceInfo: String, completion: @escaping (Result<User, DownloadError>) -> Void) {
            completion(RogersDownloadImporterTests.load?(username, password, deviceId, deviceInfo) ?? .success(Self()))
        }
    }

    private static var load: ((String, String, String, String) -> Result<User, DownloadError>)?

    private var accountName: AccountName!
    private var ledger: Ledger!
    private var user: TestUser!

    private var delegate: CredentialInputDelegate! // swiftlint:disable:this weak_delegate

    override func setUpWithError() throws {
        delegate = CredentialInputDelegate(inputNames: ["Username", "Password", "Device ID", "Device Info"],
                                           inputTypes: [.text([]), .secret, .text([]), .text([])],
                                           inputReturnValues: ["name", "password123", "device-id", "device-info"],
                                           saveKeys: ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"],
                                           saveValues: ["name", "password123", "device-id", "device-info"],
                                           readKeys: ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"],
                                           readReturnValues: ["", "", "", ""])
        accountName = try AccountName("Liabilities:CC:Rogers")
        ledger = Ledger()
        user = TestUser()
        Self.load = { _, _, _, _ in .success(self.user) }
        try ledger.add(SwiftBeanCountModel.Account(name: accountName, metaData: ["last-four": "8520", "importer-type": "rogers"]))
        try super.setUpWithError()
    }

    func testImporterName() {
        XCTAssertEqual(RogersDownloadImporter.importerName, "Rogers Bank Download")
    }

    func testImporterType() {
        XCTAssertEqual(RogersDownloadImporter.importerType, "rogers")
    }

    func testHelpText() {
        XCTAssert(RogersDownloadImporter.helpText.hasPrefix("Downloads transactions and the current balance from the Rogers Bank website."))
    }

    func testImportName() {
        XCTAssertEqual(RogersDownloadImporter(ledger: nil).importName, "Rogers Bank Download")
    }

    func testNoAccounts() {
        Self.load = {
            XCTAssertEqual($0, "name")
            XCTAssertEqual($1, "password123")
            XCTAssertEqual($2, "device-id")
            XCTAssertEqual($3, "device-info")
            return .success(TestUser())
        }
        let importer = loadedImporter()
        XCTAssertNil(importer.nextTransaction())
        XCTAssert(importer.balancesToImport().isEmpty)
    }

    func testLoadAuthenticationError() {
        let keys = ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo", "rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"]
        Self.load = { _, _, _, _ in .failure(DownloadError.invalidParameters(parameters: ["a": "bc"])) }
        delegate = ErrorDelegate(inputNames: ["Username", "Password", "Device ID", "Device Info"],
                                 inputTypes: [.text([]), .secret, .text([]), .text([])],
                                 inputReturnValues: ["name", "password123", "device-id", "device-info"],
                                 saveKeys: keys,
                                 saveValues: ["name", "password123", "device-id", "device-info", "", "", "", ""],
                                 readKeys: ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"],
                                 readReturnValues: ["", "", "", ""],
                                 error: DownloadError.invalidParameters(parameters: ["a": "bc"]))
        loadedImporter()
    }

    func testDownloadActivitiesError() throws {
        var receivedStatementNumbers = [false, false, false]
        var account = TestAccount {
            XCTAssert($0 < 3)
            receivedStatementNumbers[$0] = true
            return .failure(DownloadError.invalidParameters(parameters: ["b": "cd"]))
        }
        var amount = TestAmount()
        amount.value = "10.52"
        account.currentBalance = amount
        user.accounts = [account]
        setErrorDelegate(error: DownloadError.invalidParameters(parameters: ["b": "cd"]))
        let importer = loadedImporter(ledger: ledger)
        let balances = importer.balancesToImport()
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(balances.count, 1)
        XCTAssertEqual(Calendar.current.compare(balances[0].date, to: Date(), toGranularity: .minute), .orderedSame)
        XCTAssertEqual(balances[0].accountName, accountName)
        XCTAssertEqual(balances[0].amount, Amount(number: Decimal(string: "-10.52")!, commoditySymbol: "CAD", decimalDigits: 2))
        XCTAssertEqual(receivedStatementNumbers, [true, true, true])
    }

    func testNoLedgerAccount() {
        user.accounts = [TestAccount()]
        setErrorDelegate(error: RogersBankMappingError.missingAccount(lastFour: "8520"))
        let importer = loadedImporter()
        XCTAssertNil(importer.nextTransaction())
        XCTAssert(importer.balancesToImport().isEmpty)
    }

    func testNoActivities() throws {
        var receivedStatementNumbers = [false, false, false]
        var account = TestAccount {
            XCTAssert($0 < 3)
            receivedStatementNumbers[$0] = true
            return .success([])
        }
        var amount = TestAmount()
        amount.value = "10.52"
        account.currentBalance = amount
        user.accounts = [account]
        let importer = loadedImporter(ledger: ledger)
        let balances = importer.balancesToImport()
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(balances.count, 1)
        XCTAssertEqual(Calendar.current.compare(balances[0].date, to: Date(), toGranularity: .minute), .orderedSame)
        XCTAssertEqual(balances[0].accountName, accountName)
        XCTAssertEqual(balances[0].amount, Amount(number: Decimal(string: "-10.52")!, commoditySymbol: "CAD", decimalDigits: 2))
        XCTAssertEqual(receivedStatementNumbers, [true, true, true])
    }

    func testStatementsToLoad() throws {
        ledger.custom.append(Custom(date: Date(), name: "rogers-download-importer", values: ["statementsToLoad", "1"]))
        ledger.custom.append(Custom(date: Date(timeIntervalSinceNow: -999_999), name: "rogers-download-importer", values: ["statementsToLoad", "200"]))
        var validated = false
        let account = TestAccount {
            XCTAssertEqual($0, 0)
            validated = true
            return .success([])
        }
        user.accounts = [account]
        let importer = loadedImporter(ledger: ledger)
        let balances = importer.balancesToImport()
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(balances.count, 1)
        XCTAssert(validated)
    }

    func testMultiAccount() throws {
        var receivedStatementNumbers1 = [false, false, false]
        var receivedStatementNumbers2 = [false, false, false]
        let account1 = TestAccount {
            XCTAssert($0 < 3)
            receivedStatementNumbers1[$0] = true
            return .success([])
        }
        let account2 = TestAccount {
            XCTAssert($0 < 3)
            receivedStatementNumbers2[$0] = true
            return .success([])
        }
        user.accounts = [account1, account2]
        let importer = loadedImporter(ledger: ledger)
        let balances = importer.balancesToImport()
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(balances.count, 2)
        XCTAssertEqual(Calendar.current.compare(balances[0].date, to: Date(), toGranularity: .minute), .orderedSame)
        XCTAssertEqual(balances[0].accountName, accountName)
        XCTAssertEqual(balances[0].amount, Amount(number: Decimal(string: "0.00")!, commoditySymbol: "CAD", decimalDigits: 2))
        XCTAssertEqual(Calendar.current.compare(balances[1].date, to: Date(), toGranularity: .minute), .orderedSame)
        XCTAssertEqual(balances[1].accountName, accountName)
        XCTAssertEqual(balances[1].amount, Amount(number: Decimal(string: "-0.00")!, commoditySymbol: "CAD", decimalDigits: 2))
        XCTAssertEqual(receivedStatementNumbers1, [true, true, true])
        XCTAssertEqual(receivedStatementNumbers2, [true, true, true])
    }

    func testActivityMappingError() throws {
        let activity = TestActivity()
        user.accounts = [TestAccount { _ in .success([activity]) }]
        setErrorDelegate(error: RogersBankMappingError.missingActivityData(activity: activity, key: "referenceNumber"))
        let importer = loadedImporter(ledger: ledger)
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(importer.balancesToImport().count, 1)
    }

    func testActivities() throws {
        var activity1 = TestActivity()
        var activity3 = TestActivity()
        var activity2 = TestActivity()
        var amount = TestAmount()
        amount.value = "2.99"
        activity1.amount = amount
        activity1.referenceNumber = "vgs5bt3ghbf"
        activity2.amount = amount
        activity2.referenceNumber = "bmhouw45BH%^$W"
        activity3.activityStatus = .pending
        user.accounts = [TestAccount { $0 == 0 ? .success([activity1, activity2, activity3]) : .success([]) }]
        let importer = loadedImporter(ledger: ledger)
        var metaData = TransactionMetaData(date: activity1.postedDate!, narration: activity1.merchant.name, metaData: ["rogers-bank-id": activity1.referenceNumber!])
        var transaction = Transaction(metaData: metaData, postings: [
            Posting(accountName: accountName, amount: Amount(number: Decimal(string: "-\(amount.value)")!, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: try AccountName("Expenses:TODO"), amount: Amount(number: Decimal(string: amount.value)!, commoditySymbol: "CAD", decimalDigits: 2))
        ])
        var iTransaction = ImportedTransaction(transaction, originalDescription: activity1.merchant.name, shouldAllowUserToEdit: true, accountName: accountName)
        XCTAssertEqual(iTransaction, importer.nextTransaction())
        metaData = TransactionMetaData(date: activity2.postedDate!, narration: activity2.merchant.name, metaData: ["rogers-bank-id": activity2.referenceNumber!])
        transaction = Transaction(metaData: metaData, postings: [transaction.postings[0], transaction.postings[1]])
        iTransaction = ImportedTransaction(transaction, originalDescription: activity2.merchant.name, shouldAllowUserToEdit: true, accountName: accountName)
        XCTAssertEqual(iTransaction, importer.nextTransaction())
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(importer.balancesToImport().count, 1)
    }

    func testActivitySavedMapping() {
        Settings.storage = TestStorage()
        var activity = TestActivity()
        var amount = TestAmount()
        amount.value = "2.99"
        activity.amount = amount
        activity.referenceNumber = "ht4w5gvdt"

        let description = "New description"
        let payee = "New payee"
        Settings.setDescriptionMapping(key: activity.merchant.name, description: description)
        Settings.setPayeeMapping(key: activity.merchant.name, payee: payee)
        Settings.setAccountMapping(key: payee, account: TestUtils.chequing.fullName)

        user.accounts = [TestAccount { $0 == 0 ? .success([activity]) : .success([]) }]
        let importer = loadedImporter(ledger: ledger)
        let metaData = TransactionMetaData(date: activity.postedDate!, payee: payee, narration: description, metaData: ["rogers-bank-id": activity.referenceNumber!])
        let transaction = Transaction(metaData: metaData, postings: [
            Posting(accountName: accountName, amount: Amount(number: Decimal(string: "-\(amount.value)")!, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: TestUtils.chequing, amount: Amount(number: Decimal(string: amount.value)!, commoditySymbol: "CAD", decimalDigits: 2))
        ])
        let iTransaction = ImportedTransaction(transaction, originalDescription: activity.merchant.name, shouldAllowUserToEdit: true, accountName: accountName)
        XCTAssertEqual(iTransaction, importer.nextTransaction())
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(importer.balancesToImport().count, 1)
    }

    func testLoadSavedCredentails() {
        Self.load = {
            XCTAssertEqual($0, "name")
            XCTAssertEqual($1, "password123")
            XCTAssertEqual($2, "device-id")
            XCTAssertEqual($3, "device-info")
            return .success(TestUser())
        }
        // All saved
        delegate = CredentialInputDelegate(inputNames: [],
                                           inputTypes: [],
                                           inputReturnValues: [],
                                           saveKeys: ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"],
                                           saveValues: ["name", "password123", "device-id", "device-info"],
                                           readKeys: ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"],
                                           readReturnValues: ["name", "password123", "device-id", "device-info"])
        loadedImporter()

        // All but one saved
        delegate = CredentialInputDelegate(inputNames: ["Password"],
                                           inputTypes: [.secret],
                                           inputReturnValues: ["password123"],
                                           saveKeys: ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"],
                                           saveValues: ["name", "password123", "device-id", "device-info"],
                                           readKeys: ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"],
                                           readReturnValues: ["name", "", "device-id", "device-info"])
        loadedImporter()
    }

    @discardableResult
    private func loadedImporter(ledger: Ledger? = nil) -> Importer {
        let importer = RogersDownloadImporter(ledger: ledger)
        importer.userClass = TestUser.self
        importer.delegate = delegate
        importer.load()
        XCTAssert(importer.pricesToImport().isEmpty)
        XCTAssert(delegate.verified)
        return importer
    }

    private func setErrorDelegate<T: EquatableError>(error: T) {
        delegate = ErrorDelegate(inputNames: ["Username", "Password", "Device ID", "Device Info"],
                                 inputTypes: [.text([]), .secret, .text([]), .text([])],
                                 inputReturnValues: ["name", "password123", "device-id", "device-info"],
                                 saveKeys: ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"],
                                 saveValues: ["name", "password123", "device-id", "device-info"],
                                 readKeys: ["rogers-username", "rogers-password", "rogers-deviceId", "rogers-deviceInfo"],
                                 readReturnValues: ["", "", "", ""],
                                 error: error)
    }
}

#if hasFeature(RetroactiveAttribute)
extension DownloadError: @retroactive Equatable {}
#endif

extension DownloadError: EquatableError {
    public static func == (lhs: DownloadError, rhs: DownloadError) -> Bool {
        if case let .invalidParameters(lhsDict) = lhs, case let .invalidParameters(rhsDict) = rhs {
            return lhsDict == rhsDict
        }
        return false
    }
}

#if hasFeature(RetroactiveAttribute)
extension RogersBankMappingError: @retroactive Equatable {}
#endif

extension RogersBankMappingError: EquatableError {
    public static func == (lhs: RogersBankMappingError, rhs: RogersBankMappingError) -> Bool {
        if case let .missingAccount(lhsString) = lhs, case let .missingAccount(rhsString) = rhs {
            return lhsString == rhsString
        }
        if case let .missingActivityData(lhsActivity, lhsString) = lhs, case let .missingActivityData(rhsActivity, rhsString) = rhs {
            return lhsString == rhsString && lhsActivity as? TestActivity != nil && (lhsActivity as? TestActivity) == (rhsActivity as? TestActivity)
        }
        return false
    }
} // swiftlint:disable:this file_length
