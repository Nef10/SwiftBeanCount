//
//  Price.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2018-05-13.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

import Foundation

public struct Price {

    /// Date of the Price
    public let date: Date

    /// `Commodity` of the Price
    public let commodity: Commodity

    /// `Amount` of the Price
    public let amount: Amount

}

extension Price: CustomStringConvertible {

    /// Returns the price string for the ledger.
    public var description: String {
        return "\(type(of: self).dateFormatter.string(from: date)) price \(commodity) \(amount)"
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
