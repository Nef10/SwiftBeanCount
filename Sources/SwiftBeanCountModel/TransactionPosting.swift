//
//  TransactionPosting.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// Type of price specification in posting
public enum PostingPriceType {
    /// Price per unit (@)
    case perUnit
    /// Total price (@@)
    case total
}

/// Errors an Posting can throw
public enum PostingError: Error, Equatable {
    /// if a posting adds to the an inventory without specifying an amount
    case noCost(String)
    /// if a price is provided without a price type
    case priceWithoutType
    /// if a price type is provided without a price
    case priceTypeWithoutPrice
}

/// A Posting contains an `AccountName` with the corresponding `Amount`,
/// as well as the `price` and `cost` (if applicable).
public class Posting {

    /// `AccountName` of the account the posting is in
    public let accountName: AccountName

    /// `Amount` of the posting
    public let amount: Amount

    /// Price amount per unit
    public let price: Amount?

    /// Total price amount
    public let totalPrice: Amount?

    /// Type of price specification for the original input
    public let priceType: PostingPriceType?

    /// optional `Cost` if the amount was aquired on a cost basis
    public let cost: Cost?

    /// MetaData of the Posting
    public let metaData: [String: String]

    /// Creats an posting with the given parameters
    ///
    /// - Parameters:
    ///   - accountName: `AccountName`
    ///   - amount: `Amount`
    ///   - price: optional `Amount` which was paid to get this `amount`
    ///   - cost: optional `Cost` which was paid to get this `amount`
    ///   - metaData: metadata dictionary
    public init(accountName: AccountName, amount: Amount, price: Amount? = nil, cost: Cost? = nil, metaData: [String: String] = [:]) {
        self.accountName = accountName
        self.amount = amount
        self.cost = cost
        self.metaData = metaData
        self.priceType = price != nil ? .perUnit : nil

        // Calculate both per-unit and total prices
        if let price {
            self.price = price  // Assumed to be per-unit price
            self.totalPrice = Amount(number: price.number * amount.number,
                                     commoditySymbol: price.commoditySymbol,
                                     decimalDigits: price.decimalDigits)
        } else {
            self.price = nil
            self.totalPrice = nil
        }
    }

    /// Creats an posting with the given parameters including price type
    ///
    /// - Parameters:
    ///   - accountName: `AccountName`
    ///   - amount: `Amount`
    ///   - price: optional `Amount` which was paid to get this `amount`
    ///   - priceType: optional type of price specification
    ///   - cost: optional `Cost` which was paid to get this `amount`
    /// - Throws: PostingError if price and priceType validation fails
    public init(
        accountName: AccountName,
        amount: Amount,
        price: Amount?,
        priceType: PostingPriceType? = nil,
        cost: Cost? = nil,
        metaData: [String: String] = [:]
    ) throws {
        self.accountName = accountName
        self.amount = amount
        self.cost = cost
        self.metaData = metaData

        // Validate price and priceType combination
        if price != nil && priceType == nil {
            throw PostingError.priceWithoutType
        }
        if price == nil && priceType != nil {
            throw PostingError.priceTypeWithoutPrice
        }

        self.priceType = priceType

        // Calculate per-unit and total prices based on input
        if let price, let priceType {
            switch priceType {
            case .perUnit:
                // Input is per-unit price, calculate total
                self.price = price
                self.totalPrice = Amount(number: price.number * amount.number,
                                         commoditySymbol: price.commoditySymbol,
                                         decimalDigits: price.decimalDigits)
            case .total:
                // Input is total price, calculate per-unit
                self.totalPrice = price
                self.price = Amount(number: price.number / amount.number,
                                    commoditySymbol: price.commoditySymbol,
                                    decimalDigits: price.decimalDigits)
            }
        } else {
            self.price = nil
            self.totalPrice = nil
        }
    }

}

/// A TransactionPosting is part of an `Transaction`. It contains an `AccountName` with the corresponding `Amount`,
/// as well as the `price` (if applicable) and a link back to the `Transaction`.
public class TransactionPosting: Posting {

    /// *unowned* link back to the `Transaction`
    public unowned let transaction: Transaction

    /// Creates an TransactionPosting based on an existing `Posting`
    ///
    /// - Parameters:
    ///   - posting: `Posting`, which values will be copied
    ///   - transaction: the `Transaction` the posting is in - an *unowned* reference will be stored
    init(posting: Posting, transaction: Transaction) {
        self.transaction = transaction
        let originalPrice = Self.extractOriginalPrice(from: posting)

        do {
            try super.init(accountName: posting.accountName,
                           amount: posting.amount,
                           price: originalPrice,
                           priceType: posting.priceType,
                           cost: posting.cost,
                           metaData: posting.metaData)
        } catch {
            // This should never happen as we're copying from a valid posting
            fatalError("Failed to create TransactionPosting from valid Posting: \(error)")
        }
    }

    /// Extracts the original price from a posting based on its price type
    private static func extractOriginalPrice(from posting: Posting) -> Amount? {
        guard posting.priceType != nil else {
            return nil
        }

        switch posting.priceType {
        case .perUnit:
            return posting.price
        case .total:
            return posting.totalPrice
        case nil:
            return nil
        }
    }

    /// Returns the balance of a posting, this is the impact it has when you respect the cost or price
    ///
    /// - Parameter ledger: ledger to calculate in
    /// - Throws: PostingError if the balance could not be calculated
    /// - Returns: MultiCurrencyAmount
    func balance(in ledger: Ledger) throws -> MultiCurrencyAmount {
        if let cost {
            if let postingAmount = ledger.postingPrices[transaction]?[self] {
                return MultiCurrencyAmount(amounts: postingAmount.amounts,
                                           decimalDigits: [amount.commoditySymbol: amount.decimalDigits])
            }
            if let costAmount = cost.amount, costAmount.number > 0 {
                return MultiCurrencyAmount(amounts: [costAmount.commoditySymbol: costAmount.number * amount.number],
                                           decimalDigits: [amount.commoditySymbol: amount.decimalDigits])
            }
            throw PostingError.noCost("Posting \(self) of transaction \(transaction) does not have an amount in the cost and adds to the inventory")
        }
        if let price, let totalPrice, let priceType {
            switch priceType {
            case .perUnit:
                return MultiCurrencyAmount(amounts: [price.commoditySymbol: price.number * amount.number],
                                           decimalDigits: [amount.commoditySymbol: amount.decimalDigits])
            case .total:
                return MultiCurrencyAmount(amounts: [totalPrice.commoditySymbol: totalPrice.number],
                                           decimalDigits: [amount.commoditySymbol: amount.decimalDigits])
            }
        }
        return amount.multiCurrencyAmount
    }

}

extension Posting: CustomStringConvertible {

    /// String to describe the posting in the ledget file
    public var description: String {
        var result = "  \(accountName) \(String(describing: amount))"
        if let cost {
            result += " \(String(describing: cost))"
        }
        if let price, let totalPrice, let priceType {
            switch priceType {
            case .perUnit:
                result += " @ \(String(describing: price))"
            case .total:
                result += " @@ \(String(describing: totalPrice))"
            }
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
        // First check basic properties
        guard lhs.accountName == rhs.accountName &&
              lhs.amount == rhs.amount &&
              lhs.priceType == rhs.priceType &&
              lhs.cost == rhs.cost &&
              lhs.metaData == rhs.metaData else {
            return false
        }

        // Compare only the original input price to avoid comparing calculated values
        switch lhs.priceType {
        case .perUnit:
            return lhs.price == rhs.price
        case .total:
            return lhs.totalPrice == rhs.totalPrice
        case nil:
            return lhs.price == nil && rhs.price == nil
        }
    }

}

extension Posting: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(accountName)
        hasher.combine(amount)
        hasher.combine(cost)
        hasher.combine(metaData)
        hasher.combine(priceType)

        // Hash only the original input price to avoid hashing calculated values
        switch priceType {
        case .perUnit:
            hasher.combine(price)
        case .total:
            hasher.combine(totalPrice)
        case nil:
            break
        }
    }

}
