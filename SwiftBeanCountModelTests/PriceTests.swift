//
//  PriceTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2018-05-13.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class PriceTests: XCTestCase {

    func testInit() {
        let amount = Amount(number: Decimal(1), commodity: TestUtils.cad)
        XCTAssertNoThrow(try Price(date: TestUtils.date20170608, commodity: TestUtils.eur, amount: amount))
        XCTAssertThrowsError(try Price(date: TestUtils.date20170608, commodity: TestUtils.cad, amount: amount)) {
            XCTAssertEqual($0.localizedDescription, "Invalid Price, using same commodity: 2017-06-08 price CAD 1 CAD")
        }
    }

    func testDescription() {
        let amount = Amount(number: Decimal(1), commodity: TestUtils.cad)
        var price = try! Price(date: TestUtils.date20170608, commodity: TestUtils.eur, amount: amount)
        XCTAssertEqual(String(describing: price), "2017-06-08 price \(TestUtils.eur.symbol) \(String(describing: amount))")

        price = try! Price(date: TestUtils.date20170608, commodity: TestUtils.eur, amount: amount, metaData: ["A": "B"])
        XCTAssertEqual(String(describing: price), "2017-06-08 price \(TestUtils.eur.symbol) \(String(describing: amount))\n  A: \"B\"")

    }

    func testEqual() {
        let amount = Amount(number: Decimal(1), commodity: TestUtils.cad)
        var price = try! Price(date: TestUtils.date20170608, commodity: TestUtils.eur, amount: amount)
        var price2 = try! Price(date: TestUtils.date20170608, commodity: TestUtils.eur, amount: amount)

        XCTAssertEqual(price, price2)

        // Meta Data
        price = try! Price(date: TestUtils.date20170608, commodity: TestUtils.eur, amount: amount, metaData: ["A": "B"])
        XCTAssertNotEqual(price, price2)
        price2 = try! Price(date: TestUtils.date20170608, commodity: TestUtils.eur, amount: amount, metaData: ["A": "B"])
        XCTAssertEqual(price, price2)

        // Date different
        let price3 = try! Price(date: TestUtils.date20170609, commodity: TestUtils.eur, amount: amount)
        XCTAssertNotEqual(price, price3)

        // Commodity different
        let price4 = try! Price(date: TestUtils.date20170608, commodity: TestUtils.usd, amount: amount)
        XCTAssertNotEqual(price, price4)

        // Amount commodity different
        let amount2 = Amount(number: Decimal(1), commodity: TestUtils.usd)
        let price5 = try! Price(date: TestUtils.date20170608, commodity: TestUtils.eur, amount: amount2)
        XCTAssertNotEqual(price, price5)

        // Amount number different
        let amount3 = Amount(number: Decimal(2), commodity: TestUtils.cad)
        let price6 = try! Price(date: TestUtils.date20170608, commodity: TestUtils.eur, amount: amount3)
        XCTAssertNotEqual(price, price6)
    }

}
