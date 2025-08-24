//
//  CommodityTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-11.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

final class CommodityTests: XCTestCase {

    func testDescription() {
        let commodity = Commodity(symbol: TestUtils.cad)
        XCTAssertEqual(String(describing: commodity), "")
    }

    func testDescriptionSpecialCharactersOpening() {
        let symbol = "💵"
        let string = "2017-06-08 commodity \(symbol)"
        let commodity = Commodity(symbol: symbol, opening: TestUtils.date20170608)
        XCTAssertEqual(String(describing: commodity), string)
    }

    func testDescriptionMetaData() {
        let symbol = "CAD"
        let string = "2017-06-08 commodity \(symbol)\n  A: \"B\""
        let commodity = Commodity(symbol: symbol, opening: TestUtils.date20170608, metaData: ["A": "B"])
        XCTAssertEqual(String(describing: commodity), string)
    }

    func testValidate() {
        let commodity = Commodity(symbol: "EUR", opening: TestUtils.date20170608)
        let ledgerWithPlugin = Ledger()
        ledgerWithPlugin.plugins.append("beancount.plugins.check_commodity")
        guard case .valid = commodity.validate(in: ledgerWithPlugin) else {
            XCTFail("\(commodity) is not valid")
            return
        }
    }

    func testValidateWithoutDate() {
        let commodity = Commodity(symbol: "EUR")

        // Test without plugin - should be valid
        let ledgerWithoutPlugin = Ledger()
        guard case .valid = commodity.validate(in: ledgerWithoutPlugin) else {
            XCTFail("\(commodity) should be valid when check_commodity plugin is not enabled")
            return
        }

        // Test with plugin - should be invalid
        let ledgerWithPlugin = Ledger()
        ledgerWithPlugin.plugins.append("beancount.plugins.check_commodity")
        if case .invalid(let error) = commodity.validate(in: ledgerWithPlugin) {
            XCTAssertEqual(error, "Commodity EUR does not have an opening date")
        } else {
            XCTFail("\(commodity) should be invalid when check_commodity plugin is enabled")
        }
    }

    func testEqual() {
        var eur = Commodity(symbol: "EUR")
        var eur2 = Commodity(symbol: "EUR")
        let cad = Commodity(symbol: "CAD")
        XCTAssertEqual(eur, eur2)
        XCTAssertNotEqual(eur, cad)

        // meta data
        eur2 = Commodity(symbol: "EUR", metaData: ["A": "B"])
        XCTAssertNotEqual(eur, eur2)
        eur = Commodity(symbol: "EUR", metaData: ["A": "B"])
        XCTAssertEqual(eur, eur2)
    }

    func testGreater() {
        let eur = TestUtils.eur
        let cad = TestUtils.cad

        XCTAssert(eur > cad)
        XCTAssertFalse(eur < cad)

        XCTAssertFalse(eur > eur) // swiftlint:disable:this identical_operands
        XCTAssertFalse(cad < cad) // swiftlint:disable:this identical_operands
    }

}
