//
//  TransactionPosting.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// A Posting contains an `AccountName` with the corresponding `Amount`,
/// as well as the `price` and `cost` (if applicable).
public class Posting: MetaDataAttachable {

    /// `AccountName` of the account the posting is in
    public let accountName: AccountName

    /// `Amount` of the posting
    public let amount: Amount

    /// optional `Amount` which was paid to get this amount (should be in another `Commodity`)
    public let price: Amount?

    /// optional `Cost` if the amount was aquired on a cost basis
    public let cost: Cost?

    /// MetaData of the Posting
    public var metaData = [String: String]()

    /// Creats an posting with the given parameters
    ///
    /// - Parameters:
    ///   - accountName: `AccountName`
    ///   - amount: `Amount`
    ///   - price: optional `Amount` which was paid to get this `amount`
    ///   - cost: optional `Cost` which was paid to get this `amount`
    public init(accountName: AccountName, amount: Amount, price: Amount? = nil, cost: Cost? = nil) {
        self.accountName = accountName
        self.amount = amount
        self.price = price
        self.cost = cost
    }

}

/// A TransactionPosting is part of an `Transaction`. It contains an `AccountName` with the corresponding `Amount`,
/// as well as the `price` (if applicable) and a link back to the `Transaction`.
public class TransactionPosting: Posting {

    /// *unowned* link back to the `Transcation`
    public unowned let transaction: Transaction

    /// Creats an TransactionPosting with the given parameters
    ///
    /// - Parameters:
    ///   - accountName: `AccountName`
    ///   - amount: `Amount`
    ///   - transaction: the `Transaction` the posting is in - an *unowned* reference will be stored
    ///   - price: optional `Amount` which was paid to get this `amount`
    ///   - cost: optional `Cost` which was paid to get this `amount`
    init(accountName: AccountName, amount: Amount, transaction: Transaction, price: Amount? = nil, cost: Cost? = nil) {
        self.transaction = transaction
        super.init(accountName: accountName, amount: amount, price: price, cost: cost)
    }

    /// Creats an TransactionPosting based on an existing `Posting`
    ///
    /// - Parameters:
    ///   - posting: `Posting`, which values will be copied
    ///   - transaction: the `Transaction` the posting is in - an *unowned* reference will be stored
    init(posting: Posting, transaction: Transaction) {
        self.transaction = transaction
        super.init(accountName: posting.accountName, amount: posting.amount, price: posting.price, cost: posting.cost)
    }

}

extension Posting: CustomStringConvertible {

    /// String to describe the posting in the ledget file
    public var description: String {
        var result = "  \(accountName) \(String(describing: amount))"
        if let cost = cost {
            result += " \(String(describing: cost))"
        }
        if let price = price {
            result += " @ \(String(describing: price))"
        }
        if !metaData.isEmpty {
            result += "\n\(metaData.map { "    \($0): \"\($1)\"" }.joined(separator: "\n"))"
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
    /// - Returns: if the accountName, ammount, meta data and price are the same on both postings
    public static func == (lhs: Posting, rhs: Posting) -> Bool {
        lhs.accountName == rhs.accountName && lhs.amount == rhs.amount && lhs.price == rhs.price && lhs.cost == rhs.cost && lhs.metaData == rhs.metaData
    }

}

extension Posting: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }

}
