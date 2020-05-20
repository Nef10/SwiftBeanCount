//
//  AccountParser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2017-06-11.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

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
    static func parseFrom(line: String) -> Account? {
        let accountMatches = line.matchingStrings(regex: self.regex)
        guard
            let match = accountMatches[safe: 0],
            let date = DateParser.parseFrom(string: match[1])
        else {
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

        guard let accountName = try? AccountName(match[3]) else {
            return nil
        }

        if match[2] == "open" {
            let commodity = match[4] != "" ? Commodity(symbol: match[5]) : nil
            return bookingMethod != nil ? Account(name: accountName, bookingMethod: bookingMethod!, commodity: commodity, opening: date)
                : Account(name: accountName, commodity: commodity, opening: date)
        } else if match[2] == "close" && match[5] == "" {
            guard bookingMethod == nil else {
                return nil
            }
            let account = Account(name: accountName)
            account.closing = date
            return account
        }
        return nil
    }

}
