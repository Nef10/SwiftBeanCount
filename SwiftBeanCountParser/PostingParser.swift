//
//  PostingParser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2017-06-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

struct PostingParser {

    static private let priceGroup = "(\\s+(@@?)\\s+(\(ParserUtils.amountGroup)))"
    static private let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^\\s+\(ParserUtils.accountGroup)\\s+\(ParserUtils.amountGroup)\\s*\(CostParser.costGroup)?\\s*\(priceGroup)?\\s*(;.*)?$",
                                 options: [])
    }()

    /// Parse a Posting from a line String
    ///
    /// - Parameter line: String of one line
    /// - Returns: a Posting or nil if the line does not contain a valid Posting
    static func parseFrom(line: String, into transaction: Transaction) -> Posting? {
        let postingMatches = line.matchingStrings(regex: self.regex)
        guard let match = postingMatches[safe: 0] else {
            return nil
        }
        let (amount, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: match[2])
        guard let account = try? Account(name: match[1]) else {
            return nil
        }
        let commodity = Commodity(symbol: match[5])
        var price: Amount?
        let cost = CostParser.parseFrom(match: match, startIndex: 6)
        if !match[24].isEmpty {  // price
            let priceCommodity = Commodity(symbol: match[30])
            var priceAmount: Decimal
            var priceDecimalDigits: Int
            if match[25] == "@" {
                (priceAmount, priceDecimalDigits) = ParserUtils.parseAmountDecimalFrom(string: match[27])
            } else { // match[25] == "@@"
                (priceAmount, priceDecimalDigits) = ParserUtils.parseAmountDecimalFrom(string: match[27])
                priceAmount /= abs(amount)
            }
            price = Amount(number: priceAmount, commodity: priceCommodity, decimalDigits: priceDecimalDigits)
        }
        return Posting(account: account,
                       amount: Amount(number: amount, commodity: commodity, decimalDigits: decimalDigits),
                       transaction: transaction,
                       price: price,
                       cost: cost)
    }

}
