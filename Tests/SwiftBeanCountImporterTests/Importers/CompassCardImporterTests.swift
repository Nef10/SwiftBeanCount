//
//  CompassCardImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2023-03-18.
//  Copyright © 2023 Steffen Kötte. All rights reserved.
//

import CSV
import SwiftBeanCountCompassCardMapper
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class CompassCardImporterTests: XCTestCase {

    func testHeaders() {
        // swiftlint:disable:next line_length
        XCTAssertEqual(CompassCardImporter.headers, [["DateTime", "Transaction", "Product", "LineItem", "Amount", "BalanceDetails", "JourneyId", "LocationDisplay", "TransactonTime", "OrderDate", "Payment", "OrderNumber", "AuthCode", "Total"]])
    }

    func testImporterName() {
        XCTAssertEqual(CompassCardImporter.importerName, "Compass Card")
    }

    func testImporterType() {
        XCTAssertEqual(CompassCardImporter.importerType, "compass-card")
    }

    func testHelpText() {
        XCTAssert(CompassCardImporter.helpText.starts(with: "Imports Compass Card transactions from CSV files downloaded from the Compass Card website."))
    }

    func testImportName() throws {
        XCTAssertEqual(
            CompassCardImporter(ledger: nil, csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName,
            "Compass Card File TestName"
        )
    }

    func testImport() throws {
        // swiftlint:disable:next line_length
        let transactions = "DateTime,Transaction,Product,LineItem,Amount,BalanceDetails,JourneyId,LocationDisplay,TransactonTime,OrderDate,Payment,OrderNumber,AuthCode,Total\nNov-17-2022 08:39 PM,Tap in at Bus Stop 60572,Stored Value,,-$2.50,$7.45,2022-11-18T04:39:00.0000000Z,\"Tap in at Bus Stop 60572 Stored Value\",08:39 PM,,,,,\n"
        let reader = try CSVReader(string: transactions, hasHeaderRow: true)
        let accountName = try AccountName("Assets:CompassCard")
        let ledger = Ledger()
        try ledger.add(Account(name: accountName, metaData: ["importer-type": "compass-card"]))

        let delegate = BaseTestImporterDelegate()
        let importer = CompassCardImporter(ledger: ledger, csvReader: reader, fileName: "")
        importer.delegate = delegate
        importer.load()

        let posting1 = Posting(accountName: accountName, amount: Amount(number: -Decimal(2.50), commoditySymbol: "CAD", decimalDigits: 2))
        let posting2 = Posting(accountName: SwiftBeanCountCompassCardMapper(ledger: Ledger()).defaultExpenseAccountName,
                               amount: Amount(number: Decimal(2.50), commoditySymbol: "CAD", decimalDigits: 2))
        let date = Date(timeIntervalSince1970: 1_668_746_340)
        let metaData = TransactionMetaData(date: date, payee: "TransLink", narration: "Bus Stop 60572", metaData: ["journey-id": "2022-11-18T04:39:00.0000000Z"])
        let transaction = Transaction(metaData: metaData, postings: [posting1, posting2])

        let result = importer.nextTransaction()

        XCTAssertEqual(result!.transaction, transaction)
        XCTAssertEqual(result?.accountName, accountName)
        XCTAssert(importer.balancesToImport().isEmpty)
        XCTAssert(importer.pricesToImport().isEmpty)
        XCTAssertNil(importer.nextTransaction())
    }

    func testError() throws {
        let reader = try CSVReader(string: ",\n,", hasHeaderRow: true)
        let delegate = ErrorCheckDelegate(inputNames: ["Account"], inputTypes: [.text([])], inputReturnValues: ["Assets:CompassCard"]) {
            if case let DecodingError.keyNotFound(key, _) = $0 {
                return key.stringValue == "DateTime"
            }
            return false
        }
        let importer = CompassCardImporter(ledger: Ledger(), csvReader: reader, fileName: "")
        importer.delegate = delegate
        importer.load()
        XCTAssertNil(importer.nextTransaction())
        XCTAssertTrue(delegate.verified)
    }

}
