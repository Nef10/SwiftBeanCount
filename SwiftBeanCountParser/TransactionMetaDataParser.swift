//
//  TransactionParser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2017-06-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

struct TransactionMetaDataParser {

    static private let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^\(DateParser.dateGroup)\\s+([*!])\\s+(\"([^\"]*)\"\\s+)\"([^\"]*)\"\\s*((#([^\\s#]*)\\s*)*)(;.*)?$", options: [])
    }()

    /// Parse TransactionMetaData from a line String
    ///
    /// - Parameter line: String of one line
    /// - Returns: TransactionMetaData or nil if the line does not contain valid TransactionMetaData
    static func parseFrom(line: String) -> TransactionMetaData? {
        let transactionMatches = line.matchingStrings(regex: self.regex)
        if let match = transactionMatches[safe: 0] {
            let tagStrings = match[6].components(separatedBy: .whitespaces)
            let tags = tagStrings.filter { !$0.isEmpty }.map { tag -> Tag in
                let tagName = String(tag.dropFirst())
                return Tag(name: tagName)
            }
            if let date = DateParser.parseFrom(string: match[1]) {
                return TransactionMetaData(date: date, payee: match[4], narration: match[5], flag: Flag(rawValue: match[2])!, tags: tags)
            }
        }
        return nil
    }

}
