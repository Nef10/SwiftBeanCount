//
//  PriceTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2018-05-13.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

final class PriceTests: XCTestCase {

    func testInit() {
        let amount = Amount(number: Decimal(1), commoditySymbol: TestUtils.cad)
        XCTAssertNoThrow(try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount))
        XCTAssertThrowsError(try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.cad, amount: amount)) {
            XCTAssertEqual($0.localizedDescription, "Invalid Price, using same commodity: CAD")
        }
    }

    func testDescription() throws {
        let amount = Amount(number: Decimal(1), commoditySymbol: TestUtils.cad)
        var price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount)
        XCTAssertEqual(String(describing: price), "2017-06-08 price \(TestUtils.eur) \(String(describing: amount))")

        price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount, metaData: ["A": "B"])
        XCTAssertEqual(String(describing: price), "2017-06-08 price \(TestUtils.eur) \(String(describing: amount))\n  A: \"B\"")

    }

    func testEqual() throws {
        let amount = Amount(number: Decimal(1), commoditySymbol: TestUtils.cad)
        var price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount)
        var price2 = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount)

        XCTAssertEqual(price, price2)

        // Meta Data
        price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount, metaData: ["A": "B"])
        XCTAssertNotEqual(price, price2)
        price2 = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount, metaData: ["A": "B"])
        XCTAssertEqual(price, price2)

        // Date different
        let price3 = try Price(date: TestUtils.date20170609, commoditySymbol: TestUtils.eur, amount: amount)
        XCTAssertNotEqual(price, price3)

        // Commodity different
        let price4 = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.usd, amount: amount)
        XCTAssertNotEqual(price, price4)

        // Amount commodity different
        let amount2 = Amount(number: Decimal(1), commoditySymbol: TestUtils.usd)
        let price5 = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount2)
        XCTAssertNotEqual(price, price5)

        // Amount number different
        let amount3 = Amount(number: Decimal(2), commoditySymbol: TestUtils.cad)
        let price6 = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount3)
        XCTAssertNotEqual(price, price6)
    }

    func testValidateWithoutPlugin() throws {
        // Test that price validation is skipped when plugin is not enabled
        let ledger = Ledger()

        // Add commodities with opening dates after the price date
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170609)
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170609)
        try ledger.add(eurCommodity)
        try ledger.add(cadCommodity)

        // Create price before commodity opening dates
        let amount = Amount(number: Decimal(1.2), commoditySymbol: TestUtils.cad)
        let price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount)

        // Should be valid since plugin is not enabled
        guard case .valid = price.validate(in: ledger) else {
            XCTFail("Price should be valid when check_commodity plugin is not enabled")
            return
        }
    }

    func testValidateWithPlugin() throws {
        // Test that price validation works when plugin is enabled
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodities with opening dates after the price date
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170609)
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170609)
        try ledger.add(eurCommodity)
        try ledger.add(cadCommodity)

        // Create price before commodity opening dates
        let amount = Amount(number: Decimal(1.2), commoditySymbol: TestUtils.cad)
        let price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount)

        // Should be invalid since EUR commodity is used before opening
        if case .invalid(let error) = price.validate(in: ledger) {
            XCTAssertTrue(error.contains("EUR used on 2017-06-08 before its opening date of 2017-06-09"))
        } else {
            XCTFail("Price should be invalid when commodity is used before opening date")
        }
    }

    func testValidateAmountCommodityUsageDate() throws {
        // Test validation of amount commodity usage date
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodities with different opening dates
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170608)
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170609)
        try ledger.add(eurCommodity)
        try ledger.add(cadCommodity)

        // Create price where amount commodity (CAD) is used before its opening
        let amount = Amount(number: Decimal(1.2), commoditySymbol: TestUtils.cad)
        let price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount)

        // Should be invalid since CAD (amount commodity) is used before opening
        if case .invalid(let error) = price.validate(in: ledger) {
            XCTAssertTrue(error.contains("CAD used on 2017-06-08 before its opening date of 2017-06-09"))
        } else {
            XCTFail("Price should be invalid when amount commodity is used before opening date")
        }
    }

    func testValidateValid() throws {
        // Test that validation passes when commodities are used on or after opening dates
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Add commodities with opening dates before or on the price date
        let eurCommodity = Commodity(symbol: TestUtils.eur, opening: TestUtils.date20170608)
        let cadCommodity = Commodity(symbol: TestUtils.cad, opening: TestUtils.date20170608)
        try ledger.add(eurCommodity)
        try ledger.add(cadCommodity)

        // Create price on the commodity opening dates
        let amount = Amount(number: Decimal(1.2), commoditySymbol: TestUtils.cad)
        let price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount)

        // Should be valid since commodities are used on or after opening dates
        guard case .valid = price.validate(in: ledger) else {
            XCTFail("Price should be valid when commodities are used on or after opening dates")
            return
        }
    }

    func testValidateWithAutoCreatedCommodities() throws {
        // Test with auto-created commodities (no explicit opening date)
        let ledger = Ledger()
        ledger.plugins.append("beancount.plugins.check_commodity")

        // Auto-created commodities don't have opening dates
        // Create price - should validate as if commodities were auto-created
        let amount = Amount(number: Decimal(1.2), commoditySymbol: TestUtils.cad)
        let price = try Price(date: TestUtils.date20170608, commoditySymbol: TestUtils.eur, amount: amount)

        // Should be valid since auto-created commodities are not in the ledger commodities collection
        guard case .valid = price.validate(in: ledger) else {
            XCTFail("Price should be valid when commodities are auto-created")
            return
        }
    }

}
