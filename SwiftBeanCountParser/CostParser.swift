//
//  CostParser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2019-09-13.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

enum CostParser {

    private static let labelGroup = "(\"([^\"]*)\")"
    private static let lookahedStart = "(?=((.*?,\\s*)?"
    private static let lookahedEnd = "\\s*(,|\\}))?)"

    private static let costLabelGroup = "\(lookahedStart)\(labelGroup)\(lookahedEnd)"
    private static let costPriceGroup = "\(lookahedStart)(\(ParserUtils.amountGroup))\(lookahedEnd)" // allow normal amount - negative amount will throw exception in Cost init
    private static let costDateGroup = "\(lookahedStart)\(DateParser.dateGroup)\(lookahedEnd)"

    static let costGroup = "(\\{\\s*\(costLabelGroup)\(costPriceGroup)\(costDateGroup).*\\})"

    static func parseFrom(match: [String], startIndex: Int) throws -> Cost? {
        var cost: Cost?
        if !match[startIndex].isEmpty { // cost
            var amount: Amount?
            var date: Date?
            var label: String?
            if !match[startIndex + 3].isEmpty {
                label = match[startIndex + 4]
            }
            if !match[startIndex + 16].isEmpty, let parsedDate = DateParser.parseFrom(string: match[startIndex + 16]) {
                date = parsedDate
            }
            if !match[startIndex + 8].isEmpty {
                let (costAmount, costDecimalDigits) = ParserUtils.parseAmountDecimalFrom(string: match[startIndex + 9])
                let costCommodity = Commodity(symbol: match[startIndex + 12])
                amount = Amount(number: costAmount, commodity: costCommodity, decimalDigits: costDecimalDigits)
            }
            cost = try Cost(amount: amount, date: date, label: label)
        }
        return cost
    }

}
