//
//  ParserUtils.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2018-05-26.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

import Foundation

struct ParserUtils {

    static let accountGroup = "([^\\s]+:[^\\s]+)"
    static let decimalGroup = "([-+]?[0-9]+(,[0-9]{3})*(.[0-9]+)?)"
    static let commodityGroup = "([^\\s]+)"
    static let amountGroup = "\(decimalGroup)\\s+\(commodityGroup)"

    static func parseAmountDecimalFrom(string: String) -> (Decimal, Int) {
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
