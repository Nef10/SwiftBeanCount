//
//  Price.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2018-05-13.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

import Foundation

/// Price of a commodity in another commodity on a given date
public struct Price {

    /// Errors a price can throw
    public enum PriceError: Error {
        /// the price is listed in its own commodity
        case sameCommodity(String)
    }

    /// Date of the Price
    public let date: Date

    /// `Commodity` of the Price
    public let commodity: Commodity

    /// `Amount` of the Price
    public let amount: Amount

    /// Create a price
    ///
    /// - Parameters:
    ///   - date: date of the price
    ///   - commodity: commodity
    ///   - amount: amount
    /// - Throws: PriceError.sameCommodity if the commodity and the commodity of the amount are the same
    init(date: Date, commodity: Commodity, amount: Amount) throws {
        self.date = date
        self.commodity = commodity
        self.amount = amount
        guard commodity != amount.commodity else {
            throw PriceError.sameCommodity(String(describing: self))
        }
    }

}

extension Price: CustomStringConvertible {

    /// Returns the price string for the ledger.
    public var description: String {
        return "\(type(of: self).dateFormatter.string(from: date)) price \(commodity.symbol) \(amount)"
    }

    static private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

}

extension Price: Equatable {

    /// Retuns if the two prices are equal
    ///
    /// - Parameters:
    ///   - lhs: price 1
    ///   - rhs: price 1
    /// - Returns: true if the prices are equal, false otherwise
    public static func == (lhs: Price, rhs: Price) -> Bool {
        return lhs.date == rhs.date && lhs.commodity == rhs.commodity && lhs.amount == rhs.amount
    }

}
