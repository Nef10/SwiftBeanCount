//
//  PriceParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2018-05-26.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class PriceParserTests: XCTestCase {

    // swiftlint:disable:next force_try
    private let price = try! Price(date: TestUtils.date20170609,
                                   commoditySymbol: "EUR",
                                   amount: Amount(number: Decimal(211) / Decimal(100), commoditySymbol: "CAD", decimalDigits: 2))

    private let basicPrice = "2017-06-09 price EUR 2.11 CAD"
    private let priceComment = "2017-06-09 price EUR 2.11 CAD ;fsajfdsanfjsak"
    private let priceWhitespace = "2017-06-09       price        EUR        2.11           CAD"

    private let priceSpecialCharacter = "2017-06-09 price 💵 2.11 💸"
    private let priceWholeNumber = "2017-06-09 price EUR 2 CAD"

    private let invalidPriceMissingNumber = "2017-06-09 price EUR  CAD"
    private let invalidPriceMissingFirstCurrency = "2017-06-09 price  2.11 CAD"
    private let invalidPriceMissingSecondCurrency = "2017-06-09 price EUR 2.11"
    private let invalidPriceMissingCurrencies = "2017-06-09 price 2.11"

    func testBasic() {
        let parsedPrice = PriceParser.parseFrom(line: basicPrice)
        XCTAssertNotNil(parsedPrice)
        XCTAssertEqual(parsedPrice, price)
    }

    func testComment() {
        let parsedPrice = PriceParser.parseFrom(line: priceComment)
        XCTAssertNotNil(parsedPrice)
        XCTAssertEqual(parsedPrice, price)
    }

    func testWhitespace() {
        let parsedPrice = PriceParser.parseFrom(line: priceWhitespace)
        XCTAssertNotNil(parsedPrice)
        XCTAssertEqual(parsedPrice, price)
    }

    func testSpecialCharacter() {
        let parsedPrice = PriceParser.parseFrom(line: priceSpecialCharacter)
        XCTAssertNotNil(parsedPrice)
        XCTAssertEqual(parsedPrice!.commoditySymbol, "💵")
        XCTAssertEqual(parsedPrice!.amount.commoditySymbol, "💸")
    }

    func testWholeNumber() {
        let parsedPrice = PriceParser.parseFrom(line: priceWholeNumber)
        XCTAssertNotNil(parsedPrice)
        XCTAssertEqual(parsedPrice!.amount.number, 2)
        XCTAssertEqual(parsedPrice!.amount.decimalDigits, 0)
    }

    func testInvalid() {
        XCTAssertNil(PriceParser.parseFrom(line: invalidPriceMissingNumber))
        XCTAssertNil(PriceParser.parseFrom(line: invalidPriceMissingFirstCurrency))
        XCTAssertNil(PriceParser.parseFrom(line: invalidPriceMissingSecondCurrency))
        XCTAssertNil(PriceParser.parseFrom(line: invalidPriceMissingCurrencies))
    }

}
