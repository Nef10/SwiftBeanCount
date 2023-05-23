//
//  AccountParser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2017-06-11.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParserUtils

enum AccountParser {

    private static let regex: NSRegularExpression = {
        let bookingMethod = "(\\s+\"(FIFO|LIFO|STRICT)\")"
        let commodity = "([^\";\\s][^\\s]*)"
        let regex = "^\(DateParser.dateGroup)\\s+(open|close)\\s+\(ParserUtils.accountGroup)(\\s+\(commodity))?\(bookingMethod)?\\s*(;.*)?$"
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: regex, options: [])
    }()

    /// Parse account openings and closings from a line String
    ///
    /// - Parameter line: String of one line
    /// - Returns: Account if the line could be parsed, otherwise nil
    static func parseFrom(line: String, metaData: [String: String] = [:]) -> Account? {
        let accountMatches = line.matchingStrings(regex: self.regex)
        guard let match = accountMatches[safe: 0], let date = DateParser.parseFrom(string: match[1]), let accountName = try? AccountName(match[3]) else {
            return nil
        }

        var bookingMethod: BookingMethod?
        if !match[7].isEmpty {
            switch match[7] {
            case "STRICT":
                bookingMethod = .strict
            case "LIFO":
                bookingMethod = .lifo
            case "FIFO":
                bookingMethod = .fifo
            default:
                break
            }
        }

        if match[2] == "open" {
            let commoditySymbol = !match[4].isEmpty ? match[5] : nil
            return bookingMethod != nil ? Account(name: accountName, bookingMethod: bookingMethod!, commoditySymbol: commoditySymbol, opening: date, metaData: metaData)
                : Account(name: accountName, commoditySymbol: commoditySymbol, opening: date, metaData: metaData)
        }
        if match[2] == "close" && match[5].isEmpty {
            guard bookingMethod == nil && metaData.isEmpty else {
                return nil
            }
            return Account(name: accountName, closing: date)
        }
        return nil
    }

}
