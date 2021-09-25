//
//  TestUtils.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import CSV
import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

class TestStorage: SettingsStorage {

    var storage = [String: Any]()

    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    func dictionary(forKey defaultName: String) -> [String: Any]? {
        storage[defaultName] as? [String: Any]
    }
}

class BaseTestImporterDelegate: ImporterDelegate {

    func requestInput(name: String, suggestions: [String], isSecret: Bool, completion: (String) -> Bool) {
        XCTFail("requestInput should not be called")
    }

    func saveCredential(_ value: String, for key: String) {
        XCTFail("saveCredential should not be called")
    }

    func readCredential(_ key: String) -> String? {
        XCTFail("readCredential should not be called")
        return nil
    }

    func error(_ error: Error) {
        XCTFail("error should not be called, received \(error)")
    }

}

class AccountNameProvider: BaseTestImporterDelegate {
    let account: AccountName

    init(account: AccountName) {
        self.account = account
    }

    override func requestInput(name: String, suggestions: [String], isSecret: Bool, completion: (String) -> Bool) {
        XCTAssertEqual(name, "Account")
        XCTAssertFalse(isSecret)
        let result = completion(account.fullName)
        XCTAssert(result)
    }
}

class AccountNameSuggestionVerifier: BaseTestImporterDelegate {
    let expectedValues: [String]
    var verified = false

    init (expectedValues: [AccountName]) {
        self.expectedValues = expectedValues.map { $0.fullName }
    }

    override func requestInput(name: String, suggestions: [String], isSecret: Bool, completion: (String) -> Bool) {
        XCTAssertEqual(name, "Account")
        XCTAssertEqual(suggestions.count, expectedValues.count)
        for suggestion in suggestions {
            XCTAssert(expectedValues.contains(suggestion))
        }
        XCTAssertFalse(isSecret)
        verified = true
        _ = completion(TestUtils.cash.fullName)
    }
}

class CredentialDelegate: BaseTestImporterDelegate {
    var verifiedSave = false
    var verifiedRead = false

    override func saveCredential(_ value: String, for key: String) {
        XCTAssertEqual(key, "wealthsimple-testKey2")
        XCTAssertEqual(value, "testValue")
        verifiedSave = true
    }

    override func readCredential(_ key: String) -> String? {
        XCTAssertEqual(key, "wealthsimple-testKey")
        verifiedRead = true
        return nil
    }
}

class AuthenticationDelegate: BaseTestImporterDelegate {
    let names = ["Username", "Password", "OTP"]
    let secrets = [false, true, false]

    var verified = false
    var index = 0

    override func requestInput(name: String, suggestions: [String], isSecret: Bool, completion: (String) -> Bool) {
        XCTAssertEqual(name, names[index])
        XCTAssert(suggestions.isEmpty)
        XCTAssertEqual(isSecret, secrets[index])
        switch index {
        case 0:
            XCTAssert(completion("testUserName"))
        case 1:
            XCTAssert(completion("testPassword"))
        case 2:
            XCTAssert(completion("testOTP"))
            verified = true
        default:
            XCTFail("Caled requestInput too often")
        }
        index += 1
    }
}

protocol EquatableError: Error, Equatable {
}

struct TestError: EquatableError {
    let id = UUID()
}

class ErrorDelegate<T: EquatableError>: BaseTestImporterDelegate {
    let error: T
    var verified = false

    init(error: T) {
        self.error = error
    }

    override func error(_ error: Error) {
        XCTAssertEqual(error as? T, self.error)
        verified = true
    }
}

enum TestUtils {

    static let usd: CommoditySymbol = "USD"
    static let fundName: CommoditySymbol = "5678 ML Easy BB q9"
    static let fundSymbol: String = "EASY"
    static let accountNumberChequing = 123_456_789
    static let accountNumberCash = 987_654_321
    static let parkingAccountDelegate = AccountNameProvider(account: TestUtils.parking)
    static let cashAccountDelegate = AccountNameProvider(account: TestUtils.cash)
    static let noInputDelegate = BaseTestImporterDelegate()

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    static var usdCommodity: Commodity = {
        Commodity(symbol: usd)
    }()

    static var date20170610: Date = {
        Calendar.current.date(from: DateComponents(calendar: Calendar.current, timeZone: nil, era: nil, year: 2_017, month: 6, day: 10, hour: 0, minute: 0, second: 0))!
    }()

    static var date20200605: Date = {
        Calendar.current.date(from: DateComponents(calendar: Calendar.current, timeZone: nil, era: nil, year: 2_020, month: 6, day: 5, hour: 0, minute: 0, second: 0))!
    }()

    static var ledger: Ledger = {
        let ledger = Ledger()
        let option = Option(name: "a", value: "b")
        ledger.option.append(option)
        return ledger
    }()

    static var ledgerCashUSD: Ledger = {
        let ledger = Ledger()
        try! ledger.add(TestUtils.usdCommodity)
        let account = Account(name: TestUtils.cash, commoditySymbol: TestUtils.usd)
        try! ledger.add(account)
        return ledger

    }()

    static var lederAccountNumers: Ledger = {
        let ledger = Ledger()
        try! ledger.add(TestUtils.usdCommodity)
        let account1 = Account(name: TestUtils.chequing,
                               commoditySymbol: TestUtils.usd,
                               metaData: ["number": "\(accountNumberChequing)", Settings.importerTypeKey: TangerineAccountImporter.importerType] )
        let account2 = Account(name: TestUtils.cash,
                               commoditySymbol: TestUtils.usd,
                               metaData: ["number": "\(accountNumberCash)", Settings.importerTypeKey: TangerineAccountImporter.importerType] )
        try! ledger.add(account1)
        try! ledger.add(account2)
        return ledger
    }()

    static var lederAccounts: Ledger = {
        let ledger = Ledger()
        let account1 = Account(name: TestUtils.chequing, commoditySymbol: TestUtils.usd)
        let account2 = Account(name: TestUtils.cash, commoditySymbol: TestUtils.usd)
        try! ledger.add(account1)
        try! ledger.add(account2)
        return ledger
    }()

    static var transaction: Transaction = {
        let metaData = TransactionMetaData(date: Date(), payee: "a", narration: "b", flag: .incomplete, tags: [])
        let posting1 = Posting(accountName: TestUtils.cash,
                               amount: Amount(number: Decimal(10), commoditySymbol: TestUtils.usd, decimalDigits: 2),
                               price: nil)
        let posting2 = Posting(accountName: TestUtils.chequing,
                               amount: Amount(number: Decimal(-10), commoditySymbol: TestUtils.usd, decimalDigits: 2),
                               price: nil)
        return Transaction(metaData: metaData, postings: [posting1, posting2])
    }()

    static var cash: AccountName = {
        try! AccountName("Assets:Cash")
    }()

    static var parking: AccountName = {
        try! AccountName("Assets:Cash:Parking")
    }()

    static var chequing: AccountName = {
        try! AccountName("Assets:Chequing")
    }()

    static var basicCSVReader: CSVReader {
        csvReader(content: "Date, Description, Payee\n2020-01-01, def, ghi\n")
    }

    static var dateMixedCSVReader: CSVReader {
        csvReader(content: "Date, Description, Payee\n2020-02-01, a, b\n2020-01-01, c, d\n")
    }

    static func csvReader(description: String, payee: String, date: Date? = nil) -> CSVReader {
        let dateString: String
        if let date = date {
            dateString = dateFormatter.string(from: date)
        } else {
            dateString = "2020-01-01"
        }
        return csvReader(content: "Date, Description, Payee\n\(dateString), \(description), \(payee)\n")
    }

    static func csvReader(content: String) -> CSVReader {
        try! CSVReader(stream: InputStream(data: content.data(using: .utf8)!),
                       hasHeaderRow: true,
                       trimFields: true)
    }

    static func ledgerManuLife(
        employeeBasic: String? = nil,
        employerBasic: String? = nil,
        employerMatch: String? = nil,
        employeeVoluntary: String? = nil
    ) -> Ledger {
        let ledger = Ledger()
        try! ledger.add(Commodity(symbol: fundSymbol, metaData: ["name": fundName]))
        var metaData = [String: String]()
        if let employeeBasic = employeeBasic {
            metaData["employee-basic-fraction"] = employeeBasic
        }
        if let employerBasic = employerBasic {
            metaData["employer-basic-fraction"] = employerBasic
        }
        if let employerMatch = employerMatch {
            metaData["employer-match-fraction"] = employerMatch
        }
        if let employeeVoluntary = employeeVoluntary {
            metaData["employee-voluntary-fraction"] = employeeVoluntary
        }
        let account = Account(name: TestUtils.parking, commoditySymbol: TestUtils.usd, metaData: metaData)
        try! ledger.add(account)
        return ledger
    }

}

extension XCTestCase {

    func temporaryFileURL() -> URL {
        let directory = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: directory).appendingPathComponent(UUID().uuidString)

        addTeardownBlock {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    XCTFail("Error deleting temporary file: \(error)")
                }
            }
            XCTAssertFalse(fileManager.fileExists(atPath: url.path))
        }

        return url
    }

    func createFile(at url: URL, content: String) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Error writing temporary file: \(error)")
        }
    }

}
