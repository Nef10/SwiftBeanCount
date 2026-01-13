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
import Testing

@Suite(.serialized)
struct TestsUsingStorage {
    // All tests using Settings.storage should be inside this suite to avoid interference between tests
    // For each test file, wrap the @Suite struct in an extension of TestsUsingStorage
    // See https://github.com/swiftlang/swift-testing/issues/683
}

class TestStorage: SettingsStorage {

    var storage = [String: Any]()

    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    func dictionary(forKey defaultName: String) -> [String: Any]? { // swiftlint:disable:this discouraged_optional_collection
        storage[defaultName] as? [String: Any]
    }
}

protocol EquatableError: Error, Equatable {
}

struct TestError: EquatableError {
    let id = UUID()
}

enum TestUtils {

    static let usd: CommoditySymbol = "USD"
    static let fundName: CommoditySymbol = "5678 ML Easy BB q9"
    static let fundSymbol: String = "EASY"
    static let accountNumberChequing = 123_456_789
    static let accountNumberCash = 987_654_321
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

    static var date20240101: Date = {
        Calendar.current.date(from: DateComponents(calendar: Calendar.current, timeZone: nil, era: nil, year: 2_024, month: 1, day: 1, hour: 0, minute: 0, second: 0))!
    }()

    static var date20231202: Date = {
        Calendar.current.date(from: DateComponents(calendar: Calendar.current, timeZone: nil, era: nil, year: 2_023, month: 12, day: 2, hour: 0, minute: 0, second: 0))!
    }()

    static var date20231231: Date = {
        Calendar.current.date(from: DateComponents(calendar: Calendar.current, timeZone: nil, era: nil, year: 2_023, month: 12, day: 31, hour: 0, minute: 0, second: 0))!
    }()

    static var ledger: Ledger = {
        let ledger = Ledger()
        let option = Option(name: "a", value: "b")
        ledger.option.append(option)
        return ledger
    }()

    // swiftlint:disable force_try
    static var ledgerCashUSD: Ledger = {
        let ledger = Ledger()
        try! ledger.add(Self.usdCommodity)
        let account = Account(name: Self.cash, commoditySymbol: Self.usd)
        try! ledger.add(account)
        return ledger

    }()

    static var lederAccountNumers: Ledger = {
        let ledger = Ledger()
        try! ledger.add(Self.usdCommodity)
        let account1 = Account(name: Self.chequing,
                               commoditySymbol: Self.usd,
                               metaData: ["number": "\(accountNumberChequing)", Settings.importerTypeKey: TangerineAccountImporter.importerType] )
        let account2 = Account(name: Self.cash,
                               commoditySymbol: Self.usd,
                               metaData: ["number": "\(accountNumberCash)", Settings.importerTypeKey: TangerineAccountImporter.importerType] )
        try! ledger.add(account1)
        try! ledger.add(account2)
        return ledger
    }()

    static var lederAccounts: Ledger = {
        let ledger = Ledger()
        let account1 = Account(name: Self.chequing, commoditySymbol: Self.usd)
        let account2 = Account(name: Self.cash, commoditySymbol: Self.usd)
        try! ledger.add(account1)
        try! ledger.add(account2)
        return ledger
    }()

    static var transaction: Transaction = {
        let metaData = TransactionMetaData(date: Date(), payee: "a", narration: "b", flag: .incomplete, tags: [])
        let posting1 = Posting(accountName: Self.cash,
                               amount: Amount(number: Decimal(10), commoditySymbol: Self.usd, decimalDigits: 2),
                               price: nil)
        let posting2 = Posting(accountName: Self.chequing,
                               amount: Amount(number: Decimal(-10), commoditySymbol: Self.usd, decimalDigits: 2),
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
        try! csvReader(content: "Date, Description, Payee\n2020-01-01, def, ghi\n")
    }

    static var dateMixedCSVReader: CSVReader {
        try! csvReader(content: "Date, Description, Payee\n2020-02-01, a, b\n2020-01-01, c, d\n")
    }
    // swiftlint:enable force_try

    static func csvReader(description: String, payee: String, date: Date? = nil) throws -> CSVReader {
        let dateString: String
        if let date {
            dateString = dateFormatter.string(from: date)
        } else {
            dateString = "2020-01-01"
        }
        return try csvReader(content: "Date, Description, Payee\n\(dateString), \(description), \(payee)\n")
    }

    static func csvReader(content: String) throws -> CSVReader {
        try CSVReader(stream: InputStream(data: content.data(using: .utf8)!),
                      hasHeaderRow: true,
                      trimFields: true)
    }

    static func ledgerManuLife(
        employeeBasic: String? = nil,
        employerBasic: String? = nil,
        employerMatch: String? = nil,
        employeeVoluntary: String? = nil
    ) throws -> Ledger {
        let ledger = Ledger()
        try ledger.add(Commodity(symbol: fundSymbol, metaData: ["name": fundName]))
        var metaData = [String: String]()
        if let employeeBasic {
            metaData["employee-basic-fraction"] = employeeBasic
        }
        if let employerBasic {
            metaData["employer-basic-fraction"] = employerBasic
        }
        if let employerMatch {
            metaData["employer-match-fraction"] = employerMatch
        }
        if let employeeVoluntary {
            metaData["employee-voluntary-fraction"] = employeeVoluntary
        }
        let account = Account(name: Self.parking, commoditySymbol: Self.usd, metaData: metaData)
        try ledger.add(account)
        return ledger
    }

    static func temporaryFileURL() -> (URL, () -> Void) {
        let directory = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: directory).appendingPathComponent(UUID().uuidString)

        let cleanup: () -> Void = {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    Issue.record("Error deleting temporary file: \(error)")
                }
            }
            #expect(!(fileManager.fileExists(atPath: url.path)))
        }

        return (url, cleanup)
    }

    static func createFile(at url: URL, content: String) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Issue.record("Error writing temporary file: \(error)")
        }
    }

}
