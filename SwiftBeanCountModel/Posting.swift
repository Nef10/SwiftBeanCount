//
//  Posting.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// A Posting is part of an `Transaction`. It contains an `Account` with the corresponding `Amount`,
/// as well as the `price` (if applicable) and a link back to the `Transaction`.
public struct Posting {

    /// `Account` the posting is in
    public let account: Account

    /// `Amount` of the posting
    public let amount: Amount

    /// *unowned* link back to the `Transcation`
    public unowned let transaction: Transaction

    /// optional `Amount` which was paid to get this amount (should be in another `Commodity`)
    public let price: Amount?

    /// optional `Cost` if the amount was aquired on a cost basis
    public let cost: Cost?

    /// Creats an posting with the given parameters
    ///
    /// - Parameters:
    ///   - account: `Account`
    ///   - amount: `Amount`
    ///   - transaction: the `Transaction` the posting is in - an *unowned* reference will be stored
    ///   - price: optional `Amount` which was paid to get this `amount`
    public init(account: Account, amount: Amount, transaction: Transaction, price: Amount? = nil, cost: Cost? = nil) {
        self.account = account
        self.amount = amount
        self.transaction = transaction
        self.price = price
        self.cost = cost
    }

}

extension Posting: CustomStringConvertible {

    /// String to describe the posting in the ledget file
    public var description: String {
        var result = "  \(account.name) \(String(describing: amount))"
        if let cost = cost {
            result += " \(String(describing: cost))"
        }
        if let price = price {
            result += " @ \(String(describing: price))"
        }
        return result
    }

}

extension Posting: Equatable {

    /// Compares two postings
    ///
    /// If a `price` is set it must match
    ///
    /// - Parameters:
    ///   - lhs: first posting
    ///   - rhs: second posting
    /// - Returns: if the account ammount and price are the same on both postings
    public static func == (lhs: Posting, rhs: Posting) -> Bool {
        lhs.account == rhs.account && lhs.amount == rhs.amount && lhs.price == rhs.price && lhs.cost == rhs.cost
    }

}

extension Posting: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }

}
