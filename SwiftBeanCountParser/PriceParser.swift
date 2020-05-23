//
//  PriceParser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2018-05-26.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

enum PriceParser {

    private static let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^\(DateParser.dateGroup)\\s+price\\s+\(ParserUtils.commodityGroup)\\s+\(ParserUtils.amountGroup)\\s*(;.*)?$", options: [])
    }()

    /// Parse prices from a line String
    ///
    /// - Parameter line: String of one line
    /// - Returns: Price if the line could be parsed, otherwise nil
    static func parseFrom(line: String, metaData: [String: String] = [:]) -> Price? {
        let priceMatches = line.matchingStrings(regex: self.regex)
        guard
            let match = priceMatches[safe: 0],
            let date = DateParser.parseFrom(string: match[1])
            else {
                return nil
        }
        let (amount, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: match[3])

        return try? Price(date: date,
                          commoditySymbol: match[2],
                          amount: Amount(number: amount, commoditySymbol: match[6], decimalDigits: decimalDigits),
                          metaData: metaData)

    }

}
