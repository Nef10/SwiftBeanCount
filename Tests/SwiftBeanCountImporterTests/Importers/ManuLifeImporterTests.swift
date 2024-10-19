//
//  ManuLifeImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

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
    Employer Basic	1,010.4000	31.25	325.00
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
    June 5, 2020 Bonus Contribution (Ref.# 12345678)

    To:			Amount($)
    ../Images/colour7.gif	 1234 ML Category Fund 9876 y8
    Contribution 0.44112 units @ $21.221/unit	9.36
    Total		9.36
    ../Images/colour10.gif	 \(TestUtils.fundName)
    Bonus Contribution 15.29544 units @ $9.148/unit	139.92
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

private func transactionResult(fundSymbol: String = TestUtils.fundSymbol, currencySymbol: String = TestUtils.usd) -> String {
    """
    2020-06-05 * "" ""
      Assets:Cash:Parking -149.28 \(currencySymbol)
      Assets:Cash:Employee:Basic:1234 ML Category Fund 9876 y8 0.11028 1234 ML Category Fund 9876 y8 {21.221 \(currencySymbol)}
      Assets:Cash:Employer:Basic:1234 ML Category Fund 9876 y8 0.11028 1234 ML Category Fund 9876 y8 {21.221 \(currencySymbol)}
      Assets:Cash:Employer:Match:1234 ML Category Fund 9876 y8 0.11028 1234 ML Category Fund 9876 y8 {21.221 \(currencySymbol)}
      Assets:Cash:Employee:Voluntary:1234 ML Category Fund 9876 y8 0.11028 1234 ML Category Fund 9876 y8 {21.221 \(currencySymbol)}
      Assets:Cash:Employee:Basic:\(fundSymbol) 3.82386 \(fundSymbol) {9.148 \(currencySymbol)}
      Assets:Cash:Employer:Basic:\(fundSymbol) 3.82386 \(fundSymbol) {9.148 \(currencySymbol)}
      Assets:Cash:Employer:Match:\(fundSymbol) 3.82386 \(fundSymbol) {9.148 \(currencySymbol)}
      Assets:Cash:Employee:Voluntary:\(fundSymbol) 3.82386 \(fundSymbol) {9.148 \(currencySymbol)}
    """
}

private func transactionPricesResult(fundSymbol: String = TestUtils.fundSymbol, currencySymbol: String = TestUtils.usd) -> String {
    """
    2020-06-05 price 1234 ML Category Fund 9876 y8 21.221 \(currencySymbol)
    2020-06-05 price \(fundSymbol) 9.148 \(currencySymbol)
    """
}

private let printDateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter
}()

private var date: Date {
    var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
    dateComponents.hour = 0
    dateComponents.minute = 0
    dateComponents.second = 0
    return Calendar.current.date(from: dateComponents)!
}

private var dateString: String = {
    printDateFormatter.string(from: date)
}()

private func balanceResult(fundSymbol: String = TestUtils.fundSymbol) -> String {
    """
    \(dateString) balance Assets:Cash:Employee:Basic:1234 ML Category Fund 9876 y8 8.0000 1234 ML Category Fund 9876 y8
    \(dateString) balance Assets:Cash:Employer:Basic:1234 ML Category Fund 9876 y8 1,010.4000 1234 ML Category Fund 9876 y8
    \(dateString) balance Assets:Cash:Employer:Match:1234 ML Category Fund 9876 y8 8.0000 1234 ML Category Fund 9876 y8
    \(dateString) balance Assets:Cash:Employee:Voluntary:1234 ML Category Fund 9876 y8 5.6000 1234 ML Category Fund 9876 y8
    \(dateString) balance Assets:Cash:Employee:Basic:\(fundSymbol) 11.7280 \(fundSymbol)
    \(dateString) balance Assets:Cash:Employer:Basic:\(fundSymbol) 15.24640 \(fundSymbol)
    \(dateString) balance Assets:Cash:Employer:Match:\(fundSymbol) 11.72800 \(fundSymbol)
    \(dateString) balance Assets:Cash:Employee:Voluntary:\(fundSymbol) 8.20960 \(fundSymbol)
    """
}

private func balancePricesResult(fundSymbol: String = TestUtils.fundSymbol, currencySymbol: String = TestUtils.usd) -> String {
    """
    \(dateString) price 1234 ML Category Fund 9876 y8 31.25 \(currencySymbol)
    \(dateString) price \(fundSymbol) 5.000 \(currencySymbol)
    """
}

final class ManuLifeImporterTests: XCTestCase {

    private var parkingAccountDelegate: InputProviderDelegate! // swiftlint:disable:this weak_delegate

    override func setUpWithError() throws {
        parkingAccountDelegate = InputProviderDelegate(names: ["Account"], types: [.text([])], returnValues: [TestUtils.parking.fullName])
        try super.setUpWithError()
    }

    func testImporterName() {
        XCTAssertEqual(ManuLifeImporter.importerName, "ManuLife")
    }

    func testImporterType() {
        XCTAssertEqual(ManuLifeImporter.importerType, "manulife")
    }

    func testHelpText() {
        XCTAssert(ManuLifeImporter.helpText.contains("importer-type: \"manulife\""))
    }

    func testImportName() {
        XCTAssertEqual(loadedImporter().importName, "ManuLife Text")
    }

    func testParseEmpty() {
        let importer = loadedImporter()
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(importer.balancesToImport(), [])
        XCTAssertEqual(importer.pricesToImport(), [])
    }

    func testParseBalance() throws {
        let importer = loadedImporter(ledger: try TestUtils.ledgerManuLife(), balance: balance)
        XCTAssertNil(importer.nextTransaction())
        let balances = importer.balancesToImport()
        let prices = importer.pricesToImport()
        XCTAssertEqual(balances.count, 8)
        XCTAssertEqual(prices.count, 2)

        XCTAssertEqual(
            "\(balances.map { "\($0)" }.joined(separator: "\n"))\n\n\(prices.map { "\($0)" }.joined(separator: "\n"))",
            "\(balanceResult())\n\n\(balancePricesResult())"
        )
        XCTAssert(parkingAccountDelegate.verified)
    }

    func testTransaction() throws {
        let importer = loadedImporter(ledger: try TestUtils.ledgerManuLife(), transaction: transaction)
        let transaction = importer.nextTransaction()
        XCTAssertNotNil(transaction)
        XCTAssertEqual(transaction!.originalDescription, "")
        XCTAssertFalse(transaction!.shouldAllowUserToEdit)
        XCTAssertNil(transaction!.accountName)
        XCTAssertNil(importer.nextTransaction())
        let prices = importer.pricesToImport()
        XCTAssertTrue(importer.balancesToImport().isEmpty)
        XCTAssertEqual(prices.count, 2)

        XCTAssertEqual(
            "\(transaction!.transaction)\n\n\(prices.map { "\($0)" }.joined(separator: "\n"))",
            "\(transactionResult())\n\n\(transactionPricesResult())"
        )
        XCTAssert(parkingAccountDelegate.verified)
    }

    func testBalanceAndTransaction() throws {
        let importer = loadedImporter(ledger: try TestUtils.ledgerManuLife(), transaction: transaction, balance: balance)
        let transaction = importer.nextTransaction()
        XCTAssertNotNil(transaction)
        let balances = importer.balancesToImport()
        let prices = importer.pricesToImport()
        XCTAssertEqual(balances.count, 8)
        XCTAssertEqual(prices.count, 4)
        XCTAssertEqual(
            "\(transaction!.transaction)\n\n\(balances.map { "\($0)" }.joined(separator: "\n"))\n\n\(prices.map { "\($0)" }.joined(separator: "\n"))",
            "\(transactionResult())\n\n\(balanceResult())\n\n\(transactionPricesResult())\n\(balancePricesResult())"
        )
        XCTAssert(parkingAccountDelegate.verified)
    }

    func testNoLedger() {
        let importer = loadedImporter(transaction: transaction, balance: balance)
        let transaction = importer.nextTransaction()
        XCTAssertNotNil(transaction)
        let balances = importer.balancesToImport()
        let prices = importer.pricesToImport()
        XCTAssertEqual(balances.count, 8)
        XCTAssertEqual(prices.count, 4)
        XCTAssertEqual(
            "\(transaction!.transaction)\n\n\(balances.map { "\($0)" }.joined(separator: "\n"))\n\n\(prices.map { "\($0)" }.joined(separator: "\n"))",
            """
            \(transactionResult(fundSymbol: "5678 ML Easy BB q9", currencySymbol: "CAD"))\n\n\(balanceResult(fundSymbol: "5678 ML Easy BB q9"))\n
            \(transactionPricesResult(fundSymbol: "5678 ML Easy BB q9", currencySymbol: "CAD"))
            \(balancePricesResult(fundSymbol: "5678 ML Easy BB q9", currencySymbol: "CAD"))
            """
        )
    }

    func testBalanceAndPriceDuplicates() throws {
        let ledger = try TestUtils.ledgerManuLife()
        let balanceAmount = Amount(number: Decimal(8.209_60), commoditySymbol: TestUtils.fundSymbol, decimalDigits: 5)
        let balanceObject = Balance(date: date, accountName: try AccountName("Assets:Cash:Employee:Voluntary:\(TestUtils.fundSymbol)"), amount: balanceAmount)
        ledger.add(balanceObject)
        let priceAmount1 = Amount(number: Decimal(5.000), commoditySymbol: TestUtils.usd, decimalDigits: 3)
        let price1 = try Price(date: date, commoditySymbol: TestUtils.fundSymbol, amount: priceAmount1)
        try ledger.add(price1)
        let priceAmount2 = Amount(number: Decimal(9.148), commoditySymbol: TestUtils.usd, decimalDigits: 3)
        let price2 = try Price(date: TestUtils.date20200605, commoditySymbol: TestUtils.fundSymbol, amount: priceAmount2)
        try ledger.add(price2)
        let importer = loadedImporter(ledger: ledger, transaction: transaction, balance: balance)
        _ = importer.nextTransaction()
        let balances = importer.balancesToImport()
        let prices = importer.pricesToImport()
        XCTAssertEqual(balances.count, 7)
        XCTAssertEqual(prices.count, 2)
        XCTAssertFalse(balances.contains(balanceObject))
        XCTAssertFalse(prices.contains(price1))
        XCTAssertFalse(prices.contains(price2))
    }

    func testTransactionSettings() throws {
        let ledger = try TestUtils.ledgerManuLife(employeeBasic: "2.5", employerBasic: "3.25", employerMatch: "2.5", employeeVoluntary: "1.75")
        let importer = loadedImporter(ledger: ledger, transaction: transaction)
        let transaction = importer.nextTransaction()
        XCTAssertNotNil(transaction)
        XCTAssertTrue(importer.balancesToImport().isEmpty)
        let prices = importer.pricesToImport()
        XCTAssertEqual("\(transaction!.transaction)\n\n\(prices.map { "\($0)" }.joined(separator: "\n"))", """
            2020-06-05 * "" ""
              Assets:Cash:Parking -149.28 USD
              Assets:Cash:Employee:Basic:1234 ML Category Fund 9876 y8 0.11028 1234 ML Category Fund 9876 y8 {21.221 USD}
              Assets:Cash:Employer:Basic:1234 ML Category Fund 9876 y8 0.14336 1234 ML Category Fund 9876 y8 {21.221 USD}
              Assets:Cash:Employer:Match:1234 ML Category Fund 9876 y8 0.11028 1234 ML Category Fund 9876 y8 {21.221 USD}
              Assets:Cash:Employee:Voluntary:1234 ML Category Fund 9876 y8 0.07720 1234 ML Category Fund 9876 y8 {21.221 USD}
              Assets:Cash:Employee:Basic:\(TestUtils.fundSymbol) 3.82386 \(TestUtils.fundSymbol) {9.148 USD}
              Assets:Cash:Employer:Basic:\(TestUtils.fundSymbol) 4.97102 \(TestUtils.fundSymbol) {9.148 USD}
              Assets:Cash:Employer:Match:\(TestUtils.fundSymbol) 3.82386 \(TestUtils.fundSymbol) {9.148 USD}
              Assets:Cash:Employee:Voluntary:\(TestUtils.fundSymbol) 2.67670 \(TestUtils.fundSymbol) {9.148 USD}

            2020-06-05 price 1234 ML Category Fund 9876 y8 21.221 USD
            2020-06-05 price \(TestUtils.fundSymbol) 9.148 USD
            """)
    }

    func testTransactionSettingsZero1() throws {
        let ledger = try TestUtils.ledgerManuLife(employeeBasic: "2.5", employerBasic: "5", employerMatch: "2.5", employeeVoluntary: "0")
        let importer = loadedImporter(ledger: ledger, transaction: transaction)
        let transaction = importer.nextTransaction()
        XCTAssertNotNil(transaction)
        XCTAssertTrue(importer.balancesToImport().isEmpty)
        let prices = importer.pricesToImport()
        XCTAssertEqual(prices.count, 2)
        XCTAssertEqual("\(transaction!.transaction)\n\n\(prices.map { "\($0)" }.joined(separator: "\n"))", """
            2020-06-05 * "" ""
              Assets:Cash:Parking -149.28 USD
              Assets:Cash:Employee:Basic:1234 ML Category Fund 9876 y8 0.11028 1234 ML Category Fund 9876 y8 {21.221 USD}
              Assets:Cash:Employer:Basic:1234 ML Category Fund 9876 y8 0.22056 1234 ML Category Fund 9876 y8 {21.221 USD}
              Assets:Cash:Employer:Match:1234 ML Category Fund 9876 y8 0.11028 1234 ML Category Fund 9876 y8 {21.221 USD}
              Assets:Cash:Employee:Basic:\(TestUtils.fundSymbol) 3.82386 \(TestUtils.fundSymbol) {9.148 USD}
              Assets:Cash:Employer:Basic:\(TestUtils.fundSymbol) 7.64772 \(TestUtils.fundSymbol) {9.148 USD}
              Assets:Cash:Employer:Match:\(TestUtils.fundSymbol) 3.82386 \(TestUtils.fundSymbol) {9.148 USD}

            2020-06-05 price 1234 ML Category Fund 9876 y8 21.221 USD
            2020-06-05 price \(TestUtils.fundSymbol) 9.148 USD
            """)
    }

    func testTransactionSettingsZero2() throws {
        let ledger = try TestUtils.ledgerManuLife(employeeBasic: "0", employerBasic: "0", employerMatch: "0", employeeVoluntary: "1")
        let importer = loadedImporter(ledger: ledger, transaction: transaction)
        let transaction = importer.nextTransaction()
        XCTAssertNotNil(transaction)
        XCTAssertTrue(importer.balancesToImport().isEmpty)
        let prices = importer.pricesToImport()
        XCTAssertEqual("\(transaction!.transaction)\n\n\(prices.map { "\($0)" }.joined(separator: "\n"))", """
            2020-06-05 * "" ""
              Assets:Cash:Parking -149.28 USD
              Assets:Cash:Employee:Voluntary:1234 ML Category Fund 9876 y8 0.44112 1234 ML Category Fund 9876 y8 {21.221 USD}
              Assets:Cash:Employee:Voluntary:\(TestUtils.fundSymbol) 15.29544 \(TestUtils.fundSymbol) {9.148 USD}

            2020-06-05 price 1234 ML Category Fund 9876 y8 21.221 USD
            2020-06-05 price \(TestUtils.fundSymbol) 9.148 USD
            """)
    }

    func testTransactionGarbage() throws {
        let strings = ["This is not a valid Transaction", transactionInvalidDate]
        for string in strings {
            let importer = loadedImporter(ledger: try TestUtils.ledgerManuLife(), transaction: string)
            XCTAssertNil(importer.nextTransaction())
            XCTAssertEqual(importer.balancesToImport(), [])
            XCTAssertEqual(importer.pricesToImport(), [])
        }
    }

    func testGetPossibleDuplicateFor() throws {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = try TestUtils.ledgerManuLife()
        let metaData = TransactionMetaData(date: TestUtils.date20200605, payee: "a", narration: "b", flag: .incomplete, tags: [])
        let posting1 = Posting(accountName: try AccountName("Assets:Cash:Parking"),
                               amount: Amount(number: Decimal(-149.28), commoditySymbol: TestUtils.usd, decimalDigits: 2),
                               price: nil)
        let posting2 = Posting(accountName: TestUtils.chequing,
                               amount: Amount(number: Decimal(149.28), commoditySymbol: TestUtils.usd, decimalDigits: 2),
                               price: nil)
        let transaction1 = Transaction(metaData: metaData, postings: [posting1, posting2])
        ledger.add(transaction1)

        let importer = loadedImporter(ledger: ledger, transaction: transaction)
        let importedTransaction = importer.nextTransaction()
        XCTAssertNotNil(importedTransaction)
        XCTAssertEqual(importedTransaction!.possibleDuplicate, transaction1)
    }

    func testGetPossibleDuplicateForNone() throws {
        Settings.storage = TestStorage()
        Settings.dateToleranceInDays = 2
        let ledger = try TestUtils.ledgerManuLife()
        let transaction1 = TestUtils.transaction
        ledger.add(transaction1)

        let importer = loadedImporter(ledger: ledger, transaction: transaction)
        let importedTransaction = importer.nextTransaction()
        XCTAssertNotNil(importedTransaction)
        XCTAssertNil(importedTransaction!.possibleDuplicate)
    }

    private func loadedImporter(ledger: Ledger? = nil, transaction: String = "", balance: String = "") -> ManuLifeImporter {
        let importer = ManuLifeImporter(ledger: ledger, transaction: transaction, balance: balance)
        importer.delegate = parkingAccountDelegate
        importer.load()
        return importer
    }
}
