//
//  ManuLifeImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import XCTest

final class ManuLifeImporterTests: XCTestCase {

    private static let printDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private lazy var dateString: String = {
        Self.printDateFormatter.string(from: Date())
    }()

    private let balance = """

        Investment details

        Current value:    $1,234.56

        Breakdown by investments

        1234 - ML Category Fund 9876 y8
        Contribution category	Number	Unit
        value	Current
        value ($)

        Employee Basic	8.0000	31.25	250.00
        Employee voluntary	5.6000	31.25	175.00
        Employer Basic	10.4000	31.25	325.00
        Employer Match	8.0000	31.25	250.00

        TOTAL	$1,000.00

        5678 - ML Easy BB q9
        Contribution category	Number	Unit
        value	Current
        value ($)

        Employee Basic	11.7280	5.000	58.64
        Employee voluntary	8.20960	5.000	41.05
        Employer Basic	15.24640	5.000	76.23
        Employer Match	11.72800	5.000	58.64

        TOTAL	$234.56

        """

    private let transaction = """

        Transaction details
        May 29, 2020 Contribution (Ref.# 12345678)

        To:			Amount($)
        ../Images/colour7.gif	 1234 ML Category Fund 9876 y8
        Contribution 0.44112 units @ $21.221/unit	9.36
        Total		9.36
        ../Images/colour10.gif	 \(TestUtils.fundName)
        Contribution 15.29544 units @ $9.148/unit	139.92
        Total		139.92

        """

    private let transactionInvalidDate = """
        Transaction details
        May -0, 2020 Contribution (Ref.# 12345678)

        To:			Amount($)
        ../Images/colour7.gif	 1234 ML Category Fund 9876 y8
        Contribution 0.44112 units @ $21.221/unit	9.36
        Total		9.36
        """

    private lazy var balanceResult: String = { """
        \(dateString) balance Assets:Cash:Employee:Basic:1234 ML Category Fund 9876 y8                 8.0000 1234 ML Category Fund 9876 y8
        \(dateString) balance Assets:Cash:Employer:Basic:1234 ML Category Fund 9876 y8                10.4000 1234 ML Category Fund 9876 y8
        \(dateString) balance Assets:Cash:Employer:Match:1234 ML Category Fund 9876 y8                 8.0000 1234 ML Category Fund 9876 y8
        \(dateString) balance Assets:Cash:Employee:Voluntary:1234 ML Category Fund 9876 y8             5.6000 1234 ML Category Fund 9876 y8
        \(dateString) balance Assets:Cash:Employee:Basic:\(TestUtils.fundSymbol)                                         11.7280 \(TestUtils.fundSymbol)
        \(dateString) balance Assets:Cash:Employer:Basic:\(TestUtils.fundSymbol)                                        15.24640 \(TestUtils.fundSymbol)
        \(dateString) balance Assets:Cash:Employer:Match:\(TestUtils.fundSymbol)                                        11.72800 \(TestUtils.fundSymbol)
        \(dateString) balance Assets:Cash:Employee:Voluntary:\(TestUtils.fundSymbol)                                     8.20960 \(TestUtils.fundSymbol)

        \(dateString) price 1234 ML Category Fun 31.25 USD
        \(dateString) price \(TestUtils.fundSymbol)                 5.000 USD
        """
    }()

    private let transactionResult = """
        2020-05-29 * "" ""
          Assets:Cash:Parking                                                 149.28    USD
          Assets:Cash:Employee:Basic:1234 ML Category Fund 9876 y8              0.11028 1234 ML Category Fun {21.221 USD}
          Assets:Cash:Employer:Basic:1234 ML Category Fund 9876 y8              0.11028 1234 ML Category Fun {21.221 USD}
          Assets:Cash:Employer:Match:1234 ML Category Fund 9876 y8              0.11028 1234 ML Category Fun {21.221 USD}
          Assets:Cash:Employee:Voluntary:1234 ML Category Fund 9876 y8          0.11028 1234 ML Category Fun {21.221 USD}
          Assets:Cash:Employee:Basic:\(TestUtils.fundSymbol)                                       3.82386 \(TestUtils.fundSymbol)                 {9.148 USD}
          Assets:Cash:Employer:Basic:\(TestUtils.fundSymbol)                                       3.82386 \(TestUtils.fundSymbol)                 {9.148 USD}
          Assets:Cash:Employer:Match:\(TestUtils.fundSymbol)                                       3.82386 \(TestUtils.fundSymbol)                 {9.148 USD}
          Assets:Cash:Employee:Voluntary:\(TestUtils.fundSymbol)                                   3.82386 \(TestUtils.fundSymbol)                 {9.148 USD}

        2020-05-29 price 1234 ML Category Fun 21.221 USD
        2020-05-29 price \(TestUtils.fundSymbol)                 9.148 USD
        """

    func testSettingsName() {
        XCTAssertEqual(ManuLifeImporter.settingsName, "ManuLife")
    }

    func testSettings() {
        XCTAssertEqual(ManuLifeImporter.settings.count, 6)
    }

    func testParseEmpty() {
        let importer = ManuLifeImporter(ledger: nil, transaction: "", balance: "")
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result, "")
    }

    func testParseBalance() {
        let importer = ManuLifeImporter(ledger: TestUtils.lederFund, transaction: "", balance: balance)
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result, balanceResult)
    }

    func testTransaction() {
        clearSettings()

        let importer = ManuLifeImporter(ledger: TestUtils.lederFund, transaction: transaction, balance: "")
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result, transactionResult) // Note: End of long symbol in transaction cut off (#4)
    }

    func testTransactionSettings() {
        ManuLifeImporter.set(setting: ManuLifeImporter.employeeBasicSetting, to: "2.5")
        ManuLifeImporter.set(setting: ManuLifeImporter.employerBasicSetting, to: "3.25")
        ManuLifeImporter.set(setting: ManuLifeImporter.employerMatchSetting, to: "2.5")
        ManuLifeImporter.set(setting: ManuLifeImporter.employeeVoluntarySetting, to: "1.75")
        ManuLifeImporter.set(setting: ManuLifeImporter.cashAccountSetting, to: "Setting")

        let importer = ManuLifeImporter(ledger: TestUtils.lederFund, transaction: transaction, balance: "")
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result, """
            2020-05-29 * "" ""
              Assets:Cash:Setting                                                 149.28    USD
              Assets:Cash:Employee:Basic:1234 ML Category Fund 9876 y8              0.11028 1234 ML Category Fun {21.221 USD}
              Assets:Cash:Employer:Basic:1234 ML Category Fund 9876 y8              0.14336 1234 ML Category Fun {21.221 USD}
              Assets:Cash:Employer:Match:1234 ML Category Fund 9876 y8              0.11028 1234 ML Category Fun {21.221 USD}
              Assets:Cash:Employee:Voluntary:1234 ML Category Fund 9876 y8          0.07720 1234 ML Category Fun {21.221 USD}
              Assets:Cash:Employee:Basic:\(TestUtils.fundSymbol)                                       3.82386 \(TestUtils.fundSymbol)                 {9.148 USD}
              Assets:Cash:Employer:Basic:\(TestUtils.fundSymbol)                                       4.97102 \(TestUtils.fundSymbol)                 {9.148 USD}
              Assets:Cash:Employer:Match:\(TestUtils.fundSymbol)                                       3.82386 \(TestUtils.fundSymbol)                 {9.148 USD}
              Assets:Cash:Employee:Voluntary:\(TestUtils.fundSymbol)                                   2.67670 \(TestUtils.fundSymbol)                 {9.148 USD}

            2020-05-29 price 1234 ML Category Fun 21.221 USD
            2020-05-29 price \(TestUtils.fundSymbol)                 9.148 USD
            """) // Note: End of long symbol in transaction cut off (#4)

        clearSettings()
    }

    func testTransactionSettingsZero1() {
        ManuLifeImporter.set(setting: ManuLifeImporter.employeeBasicSetting, to: "2.5")
        ManuLifeImporter.set(setting: ManuLifeImporter.employerBasicSetting, to: "5")
        ManuLifeImporter.set(setting: ManuLifeImporter.employerMatchSetting, to: "2.5")
        ManuLifeImporter.set(setting: ManuLifeImporter.employeeVoluntarySetting, to: "0")
        ManuLifeImporter.set(setting: ManuLifeImporter.cashAccountSetting, to: "Setting")

        let importer = ManuLifeImporter(ledger: TestUtils.lederFund, transaction: transaction, balance: "")
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result, """
            2020-05-29 * "" ""
              Assets:Cash:Setting                                                 149.28    USD
              Assets:Cash:Employee:Basic:1234 ML Category Fund 9876 y8              0.11028 1234 ML Category Fun {21.221 USD}
              Assets:Cash:Employer:Basic:1234 ML Category Fund 9876 y8              0.22056 1234 ML Category Fun {21.221 USD}
              Assets:Cash:Employer:Match:1234 ML Category Fund 9876 y8              0.11028 1234 ML Category Fun {21.221 USD}
              Assets:Cash:Employee:Basic:\(TestUtils.fundSymbol)                                       3.82386 \(TestUtils.fundSymbol)                 {9.148 USD}
              Assets:Cash:Employer:Basic:\(TestUtils.fundSymbol)                                       7.64772 \(TestUtils.fundSymbol)                 {9.148 USD}
              Assets:Cash:Employer:Match:\(TestUtils.fundSymbol)                                       3.82386 \(TestUtils.fundSymbol)                 {9.148 USD}

            2020-05-29 price 1234 ML Category Fun 21.221 USD
            2020-05-29 price \(TestUtils.fundSymbol)                 9.148 USD
            """) // Note: End of long symbol in transaction cut off (#4)

        clearSettings()
    }

    func testTransactionSettingsZero2() {
        ManuLifeImporter.set(setting: ManuLifeImporter.employeeBasicSetting, to: "0")
        ManuLifeImporter.set(setting: ManuLifeImporter.employerBasicSetting, to: "0")
        ManuLifeImporter.set(setting: ManuLifeImporter.employerMatchSetting, to: "0")
        ManuLifeImporter.set(setting: ManuLifeImporter.employeeVoluntarySetting, to: "1")
        ManuLifeImporter.set(setting: ManuLifeImporter.cashAccountSetting, to: "Setting")

        let importer = ManuLifeImporter(ledger: TestUtils.lederFund, transaction: transaction, balance: "")
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result, """
            2020-05-29 * "" ""
              Assets:Cash:Setting                                                 149.28    USD
              Assets:Cash:Employee:Voluntary:1234 ML Category Fund 9876 y8          0.44112 1234 ML Category Fun {21.221 USD}
              Assets:Cash:Employee:Voluntary:\(TestUtils.fundSymbol)                                   15.29544 \(TestUtils.fundSymbol)                 {9.148 USD}

            2020-05-29 price 1234 ML Category Fun 21.221 USD
            2020-05-29 price \(TestUtils.fundSymbol)                 9.148 USD
            """) // Note: End of long symbol in transaction cut off (#4)

        clearSettings()
    }

    func testTransactionGarbage() {
        let importer = ManuLifeImporter(ledger: TestUtils.lederFund, transaction: "This is not a valid Transaction", balance: "")
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result, "")
    }

    func testTransactionInvalidData() {
        let importer = ManuLifeImporter(ledger: TestUtils.lederFund, transaction: transactionInvalidDate, balance: "")
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result.components(separatedBy: "\n").first, #"* "" """#)
    }

    func testBalanceAndTransaction() {
        clearSettings()
        let importer = ManuLifeImporter(ledger: TestUtils.lederFund, transaction: transaction, balance: balance)
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result, "\(transactionResult)\n\n\(balanceResult)") // Note: End of long symbol in transaction cut off (#4)
    }

    private func clearSettings() {
        UserDefaults.standard.removeObject(forKey: ManuLifeImporter.getUserDefaultsKey(for: ManuLifeImporter.employeeBasicSetting))
        UserDefaults.standard.removeObject(forKey: ManuLifeImporter.getUserDefaultsKey(for: ManuLifeImporter.employerBasicSetting))
        UserDefaults.standard.removeObject(forKey: ManuLifeImporter.getUserDefaultsKey(for: ManuLifeImporter.employerMatchSetting))
        UserDefaults.standard.removeObject(forKey: ManuLifeImporter.getUserDefaultsKey(for: ManuLifeImporter.employeeVoluntarySetting))
        UserDefaults.standard.removeObject(forKey: ManuLifeImporter.getUserDefaultsKey(for: ManuLifeImporter.cashAccountSetting))
    }

}
