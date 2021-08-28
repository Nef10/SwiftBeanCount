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

enum TestUtils {

    static let usd: CommoditySymbol = "USD"
    static let fundName: CommoditySymbol = "5678 ML Easy BB q9"
    static let fundSymbol: String = "EASY"
    static let accountNumberChequing = 123_456_789
    static let accountNumberCash = 987_654_321

    static var usdCommodity: Commodity = {
        Commodity(symbol: usd)
    }()

    static var date20170610: Date = {
        Date(timeIntervalSince1970: 1_497_078_000)
    }()

    static var date20200605: Date = {
        Date(timeIntervalSince1970: 1_591_340_400)
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
        let account1 = Account(name: TestUtils.chequing, commoditySymbol: TestUtils.usd, metaData: ["number": "\(accountNumberChequing)"] )
        let account2 = Account(name: TestUtils.cash, commoditySymbol: TestUtils.usd, metaData: ["number": "\(accountNumberCash)"] )
        try! ledger.add(account1)
        try! ledger.add(account2)
        return ledger
    }()

    static var lederFund: Ledger = {
        let ledger = Ledger()
        try! ledger.add(Commodity(symbol: fundSymbol, metaData: ["name": fundName]))
        let account1 = Account(name: TestUtils.chequing, commoditySymbol: TestUtils.usd)
        let account2 = Account(name: TestUtils.cash, commoditySymbol: TestUtils.usd)
        try! ledger.add(account1)
        try! ledger.add(account2)
        return ledger
    }()

    static var cash: AccountName = {
        try! AccountName("Assets:Cash")
    }()

    static var chequing: AccountName = {
        try! AccountName("Assets:Chequing")
    }()

    static var basicCSVReader: CSVReader {
        try! CSVReader(stream: InputStream(data: "Date, Description, Payee\n2020-01-01, def, ghi\n".data(using: .utf8)!),
                       hasHeaderRow: true,
                       trimFields: true)
    }

    static var dateMixedCSVReader: CSVReader {
        try! CSVReader(stream: InputStream(data: "Date, Description, Payee\n2020-02-01, a, b\n2020-01-01, c, d\n".data(using: .utf8)!),
                       hasHeaderRow: true,
                       trimFields: true)
    }

    static func csvReader(description: String, payee: String) -> CSVReader {
        try! CSVReader(stream: InputStream(data: "Date, Description, Payee\n2020-01-01, \(description), \(payee)\n".data(using: .utf8)!),
                       hasHeaderRow: true,
                       trimFields: true)
    }

    static func csvReader(content: String) -> CSVReader {
        try! CSVReader(stream: InputStream(data: content.data(using: .utf8)!),
                       hasHeaderRow: true,
                       trimFields: true)
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
