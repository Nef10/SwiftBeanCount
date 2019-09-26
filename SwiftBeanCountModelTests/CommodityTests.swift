//
//  CommodityTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-11.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class CommodityTests: XCTestCase {

    func testDescription() {
        let symbol = "String"
        let string = "commodity \(symbol)"
        let commodity = Commodity(symbol: symbol)
        XCTAssertEqual(String(describing: commodity), string)
    }

    func testDescriptionSpecialCharacters() {
        let symbol = "💵"
        let string = "commodity \(symbol)"
        let commodity = Commodity(symbol: symbol)
        XCTAssertEqual(String(describing: commodity), string)
    }

    func testDescriptionOpening() {
        let symbol = "CAD"
        let string = "2017-06-08 commodity \(symbol)"
        let date = Date(timeIntervalSince1970: 1_496_905_200)
        let commodity = Commodity(symbol: symbol, opening: date)
        XCTAssertEqual(String(describing: commodity), string)
    }

    func testDescriptionName() {
        let symbol = "CAD"
        let name = "TEST"
        let string = "2017-06-08 commodity \(symbol)\n  name: \(name)"
        let date = Date(timeIntervalSince1970: 1_496_905_200)
        let commodity = Commodity(symbol: symbol, opening: date, name: name)
        XCTAssertEqual(String(describing: commodity), string)
    }

    func testDescriptionNamePrice() {
        let symbol = "CAD"
        let name = "TEST"
        let price = "💵"
        let string = "2017-06-08 commodity \(symbol)\n  name: \(name)\n  price: \(price)"
        let date = Date(timeIntervalSince1970: 1_496_905_200)
        let commodity = Commodity(symbol: symbol, opening: date, name: name, price: price)
        XCTAssertEqual(String(describing: commodity), string)
    }

    func testDescriptionPrice() {
        let symbol = "CAD"
        let price = "💵"
        let string = "2017-06-08 commodity \(symbol)\n  price: \(price)"
        let date = Date(timeIntervalSince1970: 1_496_905_200)
        let commodity = Commodity(symbol: symbol, opening: date, name: nil, price: price)
        XCTAssertEqual(String(describing: commodity), string)
    }

    func testValidate() {
        let commodity = Commodity(symbol: "EUR", opening: Date(timeIntervalSince1970: 1_496_905_200), name: "EURO", price: "TEST")
        guard case .valid = commodity.validate() else {
            XCTFail("\(commodity) is not valid")
            return
        }
    }

    func testValidateWithoutPrice() {
        let commodity = Commodity(symbol: "EUR", opening: Date(timeIntervalSince1970: 1_496_905_200), name: "EURO")
        guard case .valid = commodity.validate() else {
            XCTFail("\(commodity) is not valid")
            return
        }
    }

    func testValidateWithoutName() {
        let commodity = Commodity(symbol: "EUR", opening: Date(timeIntervalSince1970: 1_496_905_200), name: nil, price: "TEST")
        guard case .valid = commodity.validate() else {
            XCTFail("\(commodity) is not valid")
            return
        }
    }

    func testValidateWithoutPriceAndName() {
        let commodity = Commodity(symbol: "EUR", opening: Date(timeIntervalSince1970: 1_496_905_200))
        guard case .valid = commodity.validate() else {
            XCTFail("\(commodity) is not valid")
            return
        }
    }

    func testValidateWithoutDate() {
        let commodity = Commodity(symbol: "EUR")
        if case .invalid(let error) = commodity.validate() {
            XCTAssertEqual(error, "Commodity EUR does not have an opening date")
        } else {
            XCTFail("\(commodity) is valid")
        }
    }

    func testEqual() {
        let eur = Commodity(symbol: "EUR")
        let eur2 = Commodity(symbol: "EUR")
        let cad = Commodity(symbol: "CAD")
        XCTAssertEqual(eur, eur2)
        XCTAssertNotEqual(eur, cad)

        // meta data
        eur2.metaData["A"] = "B"
        XCTAssertNotEqual(eur, eur2)
        eur.metaData["A"] = "B"
        XCTAssertEqual(eur, eur2)
    }

    func testGreater() {
        let eur = Commodity(symbol: "EUR")
        let cad = Commodity(symbol: "CAD")

        XCTAssert(eur > cad)
        XCTAssertFalse(eur < cad)

        XCTAssertFalse(eur > eur) // swiftlint:disable:this identical_operands
        XCTAssertFalse(cad < cad) // swiftlint:disable:this identical_operands
    }

}
