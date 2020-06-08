//
//  ManuLifeImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import XCTest

final class ManuLifeImporterTests: XCTestCase {

    private static let printDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    let balance = """

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
        let dateString = Self.printDateFormatter.string(from: Date())
        let importer = ManuLifeImporter(ledger: TestUtils.lederFund, transaction: "", balance: balance)
        importer.useAccount(name: TestUtils.cash)
        let result = importer.parse()
        XCTAssertEqual(result, """
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
""")
    }

}
