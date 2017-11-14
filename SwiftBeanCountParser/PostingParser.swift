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

    static private let decimalGroup = "([-+]?[0-9]+(,[0-9]{3})*(.[0-9]+)?)"
    static private let commodityGroup = "([^\\s]+)"
    static private let amountGroup = "\(decimalGroup)\\s+\(commodityGroup)"

    static private let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^\\s+\(Parser.accountGroup)\\s+\(amountGroup)(\\s+(@@?)\\s+(\(amountGroup)))?\\s*(;.*)?$", options: [])
    }()

    /// Parse a Posting from a line String
    ///
    /// - Parameter line: String of one line
    /// - Returns: a Posting or nil if the line does not contain a valid Posting
    static func parseFrom(line: String, into transaction: Transaction, for ledger: Ledger) -> Posting? {
        let postingMatches = line.matchingStrings(regex: self.regex)
        guard let match = postingMatches[safe: 0] else {
            return nil
        }
        let (amount, decimalDigits) = self.parseAmountDecimalFrom(string: match[2])
        guard let account = ledger.getAccountBy(name: match[1]) else {
            return nil
        }
        let commodity = ledger.getCommodityBy(symbol: match[5])
        var price: Amount?
        if !match[6].isEmpty {
            let priceCommodity = ledger.getCommodityBy(symbol: match[12])
            var priceAmount: Decimal
            var priceDecimalDigits: Int
            if match[7] == "@" {
                (priceAmount, priceDecimalDigits) = self.parseAmountDecimalFrom(string: match[9])
            } else { // match[7] == "@@"
                (priceAmount, priceDecimalDigits) = self.parseAmountDecimalFrom(string: match[9])
                priceAmount /= amount
            }
            price = Amount(number: priceAmount, commodity: priceCommodity, decimalDigits: priceDecimalDigits)
        }
        return Posting(account: account, amount: Amount(number: amount, commodity: commodity, decimalDigits: decimalDigits), transaction: transaction, price: price)
    }

    static private func parseAmountDecimalFrom(string: String) -> (Decimal, Int) {
        var amountString = string
        var sign = FloatingPointSign.plus
        while let index = amountString.index(of: ",") {
            amountString.remove(at: index)
        }
        if amountString.prefix(1) == "-" {
            sign = FloatingPointSign.minus
            amountString = String(amountString.suffix(amountString.count - 1))
        } else if amountString.prefix(1) == "+" {
            amountString = String(amountString.suffix(amountString.count - 1))
        }
        var exponent = 0
        if let range = amountString.index(of: ".") {
            let beforeDot = amountString[..<range]
            let afterDot = amountString[amountString.index(range, offsetBy: 1)...]
            amountString = String(beforeDot + afterDot)
            exponent = afterDot.count
        }
        return (Decimal(sign: sign, exponent: -exponent, significand: Decimal(UInt64(amountString)!)), exponent)
    }

}
