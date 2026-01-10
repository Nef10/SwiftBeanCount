//
//  CostParser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2019-09-13.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParserUtils

enum CostParsingError: LocalizedError {
    case unexpectedElements(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedElements(let elements):
            return "Unexpected elements in cost: \(elements)"
        }
    }
}

enum CostParser {

    private static let labelGroup = "(\"([^\"]*)\")"
    private static let lookahedStart = "(?=((.*?,\\s*)?"
    private static let lookahedEnd = "\\s*(,|\\}))?)"

    private static let costLabelGroup = "\(lookahedStart)\(labelGroup)\(lookahedEnd)"
    private static let costPriceGroup = "\(lookahedStart)(\(ParserUtils.amountGroup))\(lookahedEnd)" // allow normal amount - negative amount will throw exception in Cost init
    private static let costDateGroup = "\(lookahedStart)\(DateParser.dateGroup)\(lookahedEnd)"

    static let costGroup = "(\\{\\s*\(costLabelGroup)\(costPriceGroup)\(costDateGroup).*\\})"

    static func parseFrom(match: [String], startIndex: Int) throws(any Error) -> Cost? {
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
                let (costAmount, costDecimalDigits) = match[startIndex + 9].amountDecimal()
                amount = Amount(number: costAmount, commoditySymbol: match[startIndex + 12], decimalDigits: costDecimalDigits)
            }

            // First try to create the Cost to let the model handle its own validation (e.g., negative amounts)
            cost = try Cost(amount: amount, date: date, label: label)

            // Only then validate that there are no unexpected elements in the cost
            try validateCostContent(match[startIndex], amount: amount, date: date, label: label)
        }
        return cost
    }

    /// Validates that the cost string contains only expected elements
    /// - Parameters:
    ///   - costString: The full cost string (e.g., "{2017-06-09, 1.003 EUR, \"TEST\"}")
    ///   - amount: The parsed amount
    ///   - date: The parsed date
    ///   - label: The parsed label
    /// - Throws: Error if unexpected elements are found
    private static func validateCostContent(_ costString: String, amount: Amount?, date: Date?, label: String?) throws(CostParsingError) {
        // Remove the braces and extract the content
        let content = String(costString.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)

        // If empty, it's valid
        if content.isEmpty {
            return
        }

        // Instead of splitting by commas (which breaks for commodities containing commas),
        // let's remove each expected element from the content and check if anything remains
        var remainingContent = content

        // Remove the label if present
        if let label {
            let quotedLabel = "\"\(label)\""
            remainingContent = remainingContent.replacingOccurrences(of: quotedLabel, with: "")
        }

        // Remove the amount if present
        if let amount {
            let amountString = "\(amount.number) \(amount.commoditySymbol)"
            remainingContent = remainingContent.replacingOccurrences(of: amountString, with: "")
        }

        // Remove the date if present
        if let date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: date)
            remainingContent = remainingContent.replacingOccurrences(of: dateString, with: "")
        }

        // Remove valid separators (commas and whitespace)
        remainingContent = remainingContent.replacingOccurrences(of: ",", with: "")
        remainingContent = remainingContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // If anything remains, it's unexpected content
        if !remainingContent.isEmpty {
            throw CostParsingError.unexpectedElements(remainingContent)
        }
    }

}
