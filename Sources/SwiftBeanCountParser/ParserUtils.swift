//
//  ParserUtils.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2018-05-26.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

import Foundation

/// Helper methods for parsing a ledger file
public enum ParserUtils {

    static let accountGroup = "([^\\s]+:[^\\s]+)"
    static let decimalGroup = "([-+]?[0-9]+(,[0-9]{3})*(.[0-9]+)?)"
    static let commodityGroup = "([^\\s]+)"
    static let amountGroup = "\(decimalGroup)\\s+\(commodityGroup)"

    /// Parses an string into an Decimal
    /// - Parameter string: string with the amount
    /// - Returns: Tuple with the decimal ane the number of decimal palces the string contained
    public static func parseAmountDecimalFrom(string: String) -> (Decimal, Int) {
        var amountString = string
        var sign = FloatingPointSign.plus
        while let index = amountString.firstIndex(of: ",") {
            amountString.remove(at: index)
        }
        if amountString.prefix(1) == "-" {
            sign = FloatingPointSign.minus
            amountString = String(amountString.suffix(amountString.count - 1))
        } else if amountString.prefix(1) == "+" {
            amountString = String(amountString.suffix(amountString.count - 1))
        }
        var exponent = 0
        if let range = amountString.firstIndex(of: ".") {
            let beforeDot = amountString[..<range]
            let afterDot = amountString[amountString.index(range, offsetBy: 1)...]
            amountString = String(beforeDot + afterDot)
            exponent = afterDot.count
        }
        return (Decimal(sign: sign, exponent: -exponent, significand: Decimal(UInt64(amountString)!)), exponent)
    }

    /// Returns the matches of a NSRegularExpression on a string
    /// - Parameters:
    ///   - regex: NSRegularExpression to match
    ///   - string: String to match in
    /// - Returns: [[String]], the outer array contains an entry for each match and the inner arrays contain an entry for each capturing group
    public static func match(regex: NSRegularExpression, in string: String) -> [[String]] {
        // This helper function is to expose the helpful string extension wouth polluting the string class
        string.matchingStrings(regex: regex)
    }

}
