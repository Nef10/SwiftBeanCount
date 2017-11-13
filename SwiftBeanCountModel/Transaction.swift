//
//  Transaction.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

public class Transaction {

    public let metaData: TransactionMetaData
    public var postings: [Posting]

    public init(metaData: TransactionMetaData, postings: [Posting] = []) {
        self.metaData = metaData
        self.postings = postings
    }

    func isValid() -> Bool {
        guard !postings.isEmpty else {
            return false
        }
        guard isBalanced() else {
            return false
        }
        for posting in postings {
            if !posting.account.isPostingValid(posting) {
                return false
            }
        }
        return true
    }

    /// Checks if a Transaction is balanced
    ///
    /// Tolerance: Half of the last digit of precision provided
    ///            separately for each currency
    ///            (if multiple postings are in the same currency the percision of the number with the best precision is used)
    ///            Note: Price and cost values are ignored
    ///            Note: Tolerance for interger amounts is zero
    ///
    /// - Returns: if the Transaction is balanced
    private func isBalanced() -> Bool {
        var amount = MultiCurrencyAmount()
        for posting in postings {
            if let price = posting.price {
                let postingAmount = MultiCurrencyAmount(amounts: [price.commodity: price.number * posting.amount.number],
                                                        decimalDigits: [posting.amount.commodity: posting.amount.decimalDigits])
                amount += postingAmount
            } else {
                amount += posting.amount
            }
        }
        for (commodity, decimal) in amount.amounts {
            let decimalDigits = amount.decimalDigits[commodity]!
            var tolerance = Decimal()
            if decimalDigits != 0 {
                tolerance = Decimal(sign: FloatingPointSign.plus, exponent: -(decimalDigits + 1), significand: Decimal(5))
            }
            if decimal > tolerance || decimal < -tolerance {
                return false
            }
        }
        return true
    }

}

extension Transaction: CustomStringConvertible {
    public var description: String {
        var string = String(describing: metaData)
        postings.forEach { string += "\n\(String(describing: $0))" }
        return string
    }
}

extension Transaction: Equatable {
    public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.metaData == rhs.metaData && lhs.postings == rhs.postings
    }
}
