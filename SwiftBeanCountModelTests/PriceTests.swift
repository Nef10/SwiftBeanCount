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
        let sameCommodity = Commodity(symbol: "CAD")
        let amount = Amount(number: Decimal(1), commodity: sameCommodity)
        let differentCommodity = Commodity(symbol: "EUR")
        XCTAssertNoThrow(try Price(date: TestUtils.date20170608, commodity: differentCommodity, amount: amount))
        XCTAssertThrowsError(try Price(date: TestUtils.date20170608, commodity: sameCommodity, amount: amount)) {
            XCTAssertEqual($0.localizedDescription, "Invalid Price, using same commodity: 2017-06-08 price CAD 1 CAD")
        }
    }

    func testDescription() {
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "CAD"))
        let commodity = Commodity(symbol: "EUR")

        var price = try! Price(date: TestUtils.date20170608, commodity: commodity, amount: amount)
        XCTAssertEqual(String(describing: price), "2017-06-08 price \(commodity.symbol) \(String(describing: amount))")

        price = try! Price(date: TestUtils.date20170608, commodity: commodity, amount: amount, metaData: ["A": "B"])
        XCTAssertEqual(String(describing: price), "2017-06-08 price \(commodity.symbol) \(String(describing: amount))\n  A: \"B\"")

    }

    func testEqual() {
        let amount = Amount(number: Decimal(1), commodity: Commodity(symbol: "CAD"))
        let commodity = Commodity(symbol: "EUR")
        var price = try! Price(date: TestUtils.date20170608, commodity: commodity, amount: amount)
        var price2 = try! Price(date: TestUtils.date20170608, commodity: commodity, amount: amount)

        XCTAssertEqual(price, price2)

        // Meta Data
        price = try! Price(date: TestUtils.date20170608, commodity: commodity, amount: amount, metaData: ["A": "B"])
        XCTAssertNotEqual(price, price2)
        price2 = try! Price(date: TestUtils.date20170608, commodity: commodity, amount: amount, metaData: ["A": "B"])
        XCTAssertEqual(price, price2)

        // Date different
        let price3 = try! Price(date: TestUtils.date20170609, commodity: commodity, amount: amount)
        XCTAssertNotEqual(price, price3)

        // Commodity different
        let commodity2 = Commodity(symbol: "USD")
        let price4 = try! Price(date: TestUtils.date20170608, commodity: commodity2, amount: amount)
        XCTAssertNotEqual(price, price4)

        // Amount commodity different
        let amount2 = Amount(number: Decimal(1), commodity: Commodity(symbol: "USD"))
        let price5 = try! Price(date: TestUtils.date20170608, commodity: commodity, amount: amount2)
        XCTAssertNotEqual(price, price5)

        // Amount number different
        let amount3 = Amount(number: Decimal(2), commodity: Commodity(symbol: "CAD"))
        let price6 = try! Price(date: TestUtils.date20170608, commodity: commodity, amount: amount3)
        XCTAssertNotEqual(price, price6)
    }

}
