//
//  Posting.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

struct Posting {

    let account: Account
    let amount: Amount
    unowned let transaction: Transaction
    let price: Amount?

    init(account: Account, amount: Amount, transaction: Transaction, price: Amount? = nil) {
        self.account = account
        self.amount = amount
        self.transaction = transaction
        self.price = price
    }

}

extension Posting : CustomStringConvertible {
    var description: String {
        var result = "  \(account.name) \(String(describing: amount))"
        if let price = price {
            result += " @ \(String(describing: price))"
        }
        return result
    }
}

extension Posting : Equatable {
    static func == (lhs: Posting, rhs: Posting) -> Bool {
        return lhs.account == rhs.account && lhs.amount == rhs.amount && lhs.price == rhs.price
    }
}
