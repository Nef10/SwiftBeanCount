//
//  RogersDownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-10-03.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//


import Foundation
@testable import SwiftBeanCountImporter
import RogersBankDownloader
import SwiftBeanCountModel
import SwiftBeanCountRogersBankMapper
import Testing

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

   @Test
   func downloadActivities(statementNumber: Int, completion: @escaping (Result<[Activity], DownloadError>) -> Void) {
        completion(activityCallback?(statementNumber) ?? .success([]))
    }

   @Test
   func downloadStatement(statement _: Statement, completion _: @escaping (Result<URL, DownloadError>) -> Void) {
        // Empty
    }

   @Test
   func searchStatements(completion _: @escaping (Result<[Statement], DownloadError>) -> Void) {
        // Empty
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

    private class TestAuthenticator: Authenticator {
        weak var delegate: (any RogersBankDownloader.RogersAuthenticatorDelegate)?

        required init() {
            // Empty
        }

        // swiftlint:disable:next line_length
       @Test
       func login(username: String, password: String, deviceId: String?, completion: @escaping (Result<any RogersBankDownloader.User, RogersBankDownloader.DownloadError>) -> Void) {
            completion(RogersDownloadImporterTests.load?(username, password, deviceId) ?? .success(TestUser()))
        }

    }

    private struct TestUser: User {
        var userName = "Rogers Bank Username"
        var accounts = [RogersBankDownloader.Account]()
        var authenticated = true
    }

    private static var load: ((String, String, String?) -> Result<User, DownloadError>)?

    private var accountName: AccountName!
    private var ledger: Ledger!
    private var user: TestUser!

    private var delegate: CredentialInputDelegate! // swiftlint:disable:this weak_delegate

    override func setUpWithError() throws {
        delegate = CredentialInputDelegate(inputNames: ["Username", "Password"],
                                           inputTypes: [.text([]), .secret],
                                           inputReturnValues: ["name", "password123"],
                                           saveKeys: ["rogers-username", "rogers-password"],
                                           saveValues: ["name", "password123"],
                                           readKeys: ["rogers-username", "rogers-password", "rogers-deviceId"],
                                           readReturnValues: ["", "", ""])
        accountName = try AccountName("Liabilities:CC:Rogers")
        ledger = Ledger()
        user = TestUser()
        Self.load = { _, _, _ in .success(self.user) }
        try ledger.add(SwiftBeanCountModel.Account(name: accountName, metaData: ["last-four": "8520", "importer-type": "rogers"]))
        try super.setUpWithError()
    }

   @Test
   func testImporterName() {
        #expect(RogersDownloadImporter.importerName == "Rogers Bank Download")
    }

   @Test
   func testImporterType() {
        #expect(RogersDownloadImporter.importerType == "rogers")
    }

   @Test
   func testHelpText() {
        #expect(RogersDownloadImporter.helpText.hasPrefix("Downloads transactions and the current balance from the Rogers Bank website."))
    }

   @Test
   func testImportName() {
        #expect(RogersDownloadImporter(ledger: nil).importName == "Rogers Bank Download")
    }

   @Test
   func testNoAccounts() {
        Self.load = {
            #expect($0 == "name")
            #expect($1 == "password123")
            #expect($2 == "")
            return .success(TestUser())
        }
        let importer = loadedImporter()
        #expect(importer.nextTransaction( == nil))
        #expect(importer.balancesToImport().isEmpty)
    }

   @Test
   func testLoadAuthenticationError() {
        Self.load = { _, _, _ in .failure(DownloadError.invalidParameters(parameters: ["a": "bc"])) }
        delegate = ErrorDelegate(inputNames: ["Username", "Password", "The login failed. Do you want to remove the saved credentials"],
                                 inputTypes: [.text([]), .secret, .bool],
                                 inputReturnValues: ["name", "password123", "true"],
                                 saveKeys: ["rogers-username", "rogers-password", "rogers-username", "rogers-password", "rogers-deviceId"],
                                 saveValues: ["name", "password123", "", "", ""],
                                 readKeys: ["rogers-username", "rogers-password", "rogers-deviceId"],
                                 readReturnValues: ["", "", ""],
                                 error: DownloadError.invalidParameters(parameters: ["a": "bc"]))
        loadedImporter()
    }

   @Test
   func testDownloadActivitiesError() throws {
        var receivedStatementNumbers = [false, false, false]
        var account = TestAccount {
            #expect($0 < 3)
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
        #expect(importer.nextTransaction( == nil))
        #expect(balances.count == 1)
        #expect(Calendar.current.compare(balances[0].date == to: Date(), toGranularity: .minute), .orderedSame)
        #expect(balances[0].accountName == accountName)
        #expect(balances[0].amount == Amount(number: Decimal(string: "-10.52")!, commoditySymbol: "CAD", decimalDigits: 2))
        #expect(receivedStatementNumbers == [true, true, true])
    }

   @Test
   func testNoLedgerAccount() {
        user.accounts = [TestAccount()]
        setErrorDelegate(error: RogersBankMappingError.missingAccount(lastFour: "8520"))
        let importer = loadedImporter()
        #expect(importer.nextTransaction( == nil))
        #expect(importer.balancesToImport().isEmpty)
    }

   @Test
   func testNoActivities() throws {
        var receivedStatementNumbers = [false, false, false]
        var account = TestAccount {
            #expect($0 < 3)
            receivedStatementNumbers[$0] = true
            return .success([])
        }
        var amount = TestAmount()
        amount.value = "10.52"
        account.currentBalance = amount
        user.accounts = [account]
        let importer = loadedImporter(ledger: ledger)
        let balances = importer.balancesToImport()
        #expect(importer.nextTransaction( == nil))
        #expect(balances.count == 1)
        #expect(Calendar.current.compare(balances[0].date == to: Date(), toGranularity: .minute), .orderedSame)
        #expect(balances[0].accountName == accountName)
        #expect(balances[0].amount == Amount(number: Decimal(string: "-10.52")!, commoditySymbol: "CAD", decimalDigits: 2))
        #expect(receivedStatementNumbers == [true, true, true])
    }

   @Test
   func testStatementsToLoad() throws {
        ledger.custom.append(Custom(date: Date(), name: "rogers-download-importer", values: ["statementsToLoad", "1"]))
        ledger.custom.append(Custom(date: Date(timeIntervalSinceNow: -999_999), name: "rogers-download-importer", values: ["statementsToLoad", "200"]))
        var validated = false
        let account = TestAccount {
            #expect($0 == 0)
            validated = true
            return .success([])
        }
        user.accounts = [account]
        let importer = loadedImporter(ledger: ledger)
        let balances = importer.balancesToImport()
        #expect(importer.nextTransaction( == nil))
        #expect(balances.count == 1)
        #expect(validated)
    }

   @Test
   func testMultiAccount() throws {
        var receivedStatementNumbers1 = [false, false, false]
        var receivedStatementNumbers2 = [false, false, false]
        let account1 = TestAccount {
            #expect($0 < 3)
            receivedStatementNumbers1[$0] = true
            return .success([])
        }
        let account2 = TestAccount {
            #expect($0 < 3)
            receivedStatementNumbers2[$0] = true
            return .success([])
        }
        user.accounts = [account1, account2]
        let importer = loadedImporter(ledger: ledger)
        let balances = importer.balancesToImport()
        #expect(importer.nextTransaction( == nil))
        #expect(balances.count == 2)
        #expect(Calendar.current.compare(balances[0].date == to: Date(), toGranularity: .minute), .orderedSame)
        #expect(balances[0].accountName == accountName)
        #expect(balances[0].amount == Amount(number: Decimal(string: "0.00")!, commoditySymbol: "CAD", decimalDigits: 2))
        #expect(Calendar.current.compare(balances[1].date == to: Date(), toGranularity: .minute), .orderedSame)
        #expect(balances[1].accountName == accountName)
        #expect(balances[1].amount == Amount(number: Decimal(string: "-0.00")!, commoditySymbol: "CAD", decimalDigits: 2))
        #expect(receivedStatementNumbers1 == [true, true, true])
        #expect(receivedStatementNumbers2 == [true, true, true])
    }

   @Test
   func testActivityMappingError() throws {
        let activity = TestActivity()
        user.accounts = [TestAccount { _ in .success([activity]) }]
        setErrorDelegate(error: RogersBankMappingError.missingActivityData(activity: activity, key: "referenceNumber"))
        let importer = loadedImporter(ledger: ledger)
        #expect(importer.nextTransaction( == nil))
        #expect(importer.balancesToImport().count == 1)
    }

   @Test
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
        #expect(iTransaction == importer.nextTransaction())
        metaData = TransactionMetaData(date: activity2.postedDate!, narration: activity2.merchant.name, metaData: ["rogers-bank-id": activity2.referenceNumber!])
        transaction = Transaction(metaData: metaData, postings: [transaction.postings[0], transaction.postings[1]])
        iTransaction = ImportedTransaction(transaction, originalDescription: activity2.merchant.name, shouldAllowUserToEdit: true, accountName: accountName)
        #expect(iTransaction == importer.nextTransaction())
        #expect(importer.nextTransaction( == nil))
        #expect(importer.balancesToImport().count == 1)
    }

   @Test
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
        #expect(iTransaction == importer.nextTransaction())
        #expect(importer.nextTransaction( == nil))
        #expect(importer.balancesToImport().count == 1)
    }

   @Test
   func testLoadSavedCredentials() {
        Self.load = {
            #expect($0 == "name")
            #expect($1 == "password123")
            #expect($2 == "device-id")
            return .success(TestUser())
        }
        // All saved
        delegate = CredentialInputDelegate(inputNames: [],
                                           inputTypes: [],
                                           inputReturnValues: [],
                                           saveKeys: [],
                                           saveValues: [],
                                           readKeys: ["rogers-username", "rogers-password", "rogers-deviceId"],
                                           readReturnValues: ["name", "password123", "device-id"])
        loadedImporter()

        // All but one saved
        delegate = CredentialInputDelegate(inputNames: ["Password"],
                                           inputTypes: [.secret],
                                           inputReturnValues: ["password123"],
                                           saveKeys: ["rogers-password"],
                                           saveValues: ["password123"],
                                           readKeys: ["rogers-username", "rogers-password", "rogers-deviceId"],
                                           readReturnValues: ["name", "", "device-id"])
        loadedImporter()
    }

   @Test
   func testGetTwoFactorCode() {
        delegate = CredentialInputDelegate(inputNames: ["One Time Password"],
                                           inputTypes: [.otp],
                                           inputReturnValues: ["123456"],
                                           saveKeys: [],
                                           saveValues: [],
                                           readKeys: [],
                                           readReturnValues: [])
        let importer = RogersDownloadImporter(ledger: ledger)
        importer.authenticatorClass = TestAuthenticator.self
        importer.delegate = delegate
        #expect(importer.getTwoFactorCode() == "123456")
        #expect(delegate.verified, delegate.verificationInfo)
    }

   @Test
   func testSelectTwoFactorPreferenceOneOption() throws {
        delegate = CredentialInputDelegate(inputNames: [],
                                           inputTypes: [],
                                           inputReturnValues: [],
                                           saveKeys: [],
                                           saveValues: [],
                                           readKeys: [],
                                           readReturnValues: [])
        let importer = RogersDownloadImporter(ledger: ledger)
        importer.authenticatorClass = TestAuthenticator.self
        importer.delegate = delegate
        let pref = try JSONDecoder().decode(TwoFactorPreference.self, from: Data("{\"type\":\"SMS\",\"value\":\"123456789\"}".utf8))
        #expect(importer.selectTwoFactorPreference([pref]).type == pref.type)
        #expect(delegate.verified, delegate.verificationInfo)
    }

   @Test
   func testSelectTwoFactorPreferenceTwoOptions() throws {
        delegate = CredentialInputDelegate(inputNames: ["prefered One Time Password option"],
                                           inputTypes: [.choice(["123456789", "abc@def.ge"])],
                                           inputReturnValues: ["abc@def.ge"],
                                           saveKeys: [],
                                           saveValues: [],
                                           readKeys: [],
                                           readReturnValues: [])
        let importer = RogersDownloadImporter(ledger: ledger)
        importer.authenticatorClass = TestAuthenticator.self
        importer.delegate = delegate
        let pref1 = try JSONDecoder().decode(TwoFactorPreference.self, from: Data("{\"type\":\"SMS\",\"value\":\"123456789\"}".utf8))
        let pref2 = try JSONDecoder().decode(TwoFactorPreference.self, from: Data("{\"type\":\"Email\",\"value\":\"abc@def.ge\"}".utf8))
        #expect(importer.selectTwoFactorPreference([pref1 == pref2]).type, pref2.type)
        #expect(delegate.verified, delegate.verificationInfo)
    }

   @Test
   func testSaveDeviceId() {
        delegate = CredentialInputDelegate(inputNames: [],
                                           inputTypes: [],
                                           inputReturnValues: [],
                                           saveKeys: ["rogers-deviceId"],
                                           saveValues: ["qwerty1223654"],
                                           readKeys: [],
                                           readReturnValues: [])
        let importer = RogersDownloadImporter(ledger: ledger)
        importer.authenticatorClass = TestAuthenticator.self
        importer.delegate = delegate
        importer.saveDeviceId("qwerty1223654")
        #expect(delegate.verified, delegate.verificationInfo)
    }

    @discardableResult
    private func loadedImporter(ledger: Ledger? = nil) -> Importer {
        let importer = RogersDownloadImporter(ledger: ledger)
        importer.authenticatorClass = TestAuthenticator.self
        importer.delegate = delegate
        importer.load()
        #expect(importer.pricesToImport().isEmpty)
        #expect(delegate.verified, delegate.verificationInfo)
        return importer
    }

    private func setErrorDelegate<T: EquatableError>(error: T) {
        delegate = ErrorDelegate(inputNames: ["Username", "Password"],
                                 inputTypes: [.text([]), .secret],
                                 inputReturnValues: ["name", "password123"],
                                 saveKeys: ["rogers-username", "rogers-password"],
                                 saveValues: ["name", "password123"],
                                 readKeys: ["rogers-username", "rogers-password", "rogers-deviceId"],
                                 readReturnValues: ["", "", ""],
                                 error: error)
    }
}

extension DownloadError: EquatableError {
}

extension RogersBankMappingError: EquatableError {
    public static func == (lhs: RogersBankMappingError, rhs: RogersBankMappingError) -> Bool {
        if case let .missingAccount(lhsString) = lhs, case let .missingAccount(rhsString) = rhs {
            return lhsString == rhsString
        }
        if case let .missingActivityData(lhsActivity, lhsString) = lhs, case let .missingActivityData(rhsActivity, rhsString) = rhs {
            return lhsString == rhsString && lhsActivity is TestActivity && (lhsActivity as? TestActivity) == (rhsActivity as? TestActivity)
        }
        return false
    }
} // swiftlint:disable:this file_length
