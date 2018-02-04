//
//  AccountParser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2017-06-11.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

struct AccountParser {

    static private let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^\(DateParser.dateGroup)\\s+(open|close)\\s+\(Parser.accountGroup)(\\s+([^;\\s][^\\s]*))?\\s*(;.*)?$", options: [])
    }()

    /// Parse account openings and closings from a line String
    ///
    /// - Parameter line: String of one line
    /// - Returns: Bool if the line could be parsed
    static func parseFrom(line: String) -> Account? {
        let transactionMatches = line.matchingStrings(regex: self.regex)
        guard
            let match = transactionMatches[safe: 0],
            let date = DateParser.parseFrom(string: match[1]),
            let account = try? Account(name: match[3])
        else {
            return nil
        }
        if match[2] == "open" && account.opening == nil {
            let commodity = match[4] != "" ? Commodity(symbol: match[5]) : nil
            account.opening = date
            account.commodity = commodity
            return account
        } else if match[2] == "close" && match[5] == "" && account.closing == nil {
            account.closing = date
            return account
        }
        return nil
    }

}
