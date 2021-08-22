//
//  ParserUtils.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2021-08-22.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation

enum ParserUtils {

    /// Parses an string into an Decimal
    /// - Parameter string: string with the amount
    /// - Returns: Tuple with the decimal ane the number of decimal palces the string contained
    static func parseAmountDecimalFrom(string: String) -> (Decimal, Int) {
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

}
