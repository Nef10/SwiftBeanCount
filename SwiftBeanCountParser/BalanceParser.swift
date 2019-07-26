//
//  BalanceParser
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2019-07-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

struct BalanceParser {

    static private let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^\(DateParser.dateGroup)\\s+balance\\s+\(ParserUtils.accountGroup)\\s+\(ParserUtils.amountGroup)\\s*(;.*)?$", options: [])
    }()

    /// Parse balance from a line String
    ///
    /// - Parameter line: String of one line
    /// - Returns: balance if the line could be parsed, otherwise nil
    static func parseFrom(line: String) -> Balance? {
        let balanceMatches = line.matchingStrings(regex: self.regex)
        guard
            let match = balanceMatches[safe: 0],
            let date = DateParser.parseFrom(string: match[1]),
            let account = try? Account(name: match[2])
        else {
            return nil
        }
        let commodity = Commodity(symbol: match[6])
        let (amountDecimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: match[3])
        let amount = Amount(number: amountDecimal, commodity: commodity, decimalDigits: decimalDigits)
        return Balance(date: date, account: account, amount: amount)
    }

}
