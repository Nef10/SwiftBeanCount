//
//  Posting.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

public struct Posting {

    public let account: Account
    public let amount: Amount
    public unowned let transaction: Transaction
    public let price: Amount?

    public init(account: Account, amount: Amount, transaction: Transaction, price: Amount? = nil) {
        self.account = account
        self.amount = amount
        self.transaction = transaction
        self.price = price
    }

}

extension Posting : CustomStringConvertible {
    public var description: String {
        var result = "  \(account.name) \(String(describing: amount))"
        if let price = price {
            result += " @ \(String(describing: price))"
        }
        return result
    }
}

extension Posting : Equatable {
    public static func == (lhs: Posting, rhs: Posting) -> Bool {
        return lhs.account == rhs.account && lhs.amount == rhs.amount && lhs.price == rhs.price
    }
}
