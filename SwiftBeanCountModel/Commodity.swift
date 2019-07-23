//
//  Commodity.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// A commodity just consists of a symbol
public class Commodity {

    /// symbol of the commodity
    public let symbol: String

    /// opening of the commodity
    public let opening: Date?

    /// full name of the commodity
    public let name: String?

    /// string describing how to get the price of the commodity
    public let price: String?

    /// Creates an commodity with the given symbol, all other properties are set to nil
    ///
    /// - Parameter symbol: symbol of the commodity
    public init(symbol: String) {
        self.symbol = symbol
        self.opening = nil
        self.name = nil
        self.price = nil
    }

    /// Creates an commodity with the given parameters
    ///
    /// - Parameters:
    ///   - symbol: symbol of the commodity
    ///   - opening: date the commodity was opened
    ///   - name: full name of the commodity
    ///   - price: string describing how to get the price of the commodity
    public init(symbol: String, opening: Date?, name: String? = nil, price: String? = nil) {
        self.symbol = symbol
        self.opening = opening
        self.name = name
        self.price = price
    }

    /// Validates the commodity
    ///
    /// A commodity is valid if it has an opening date. Name and price are optional
    ///
    /// - Returns: `ValidationResult`
    func validate() -> ValidationResult {
        guard opening != nil else {
            return .invalid("Commodity \(symbol) does not have an opening date")
        }
        return .valid
    }

}

extension Commodity: CustomStringConvertible {

    /// String of the commodity definition
    public var description: String {
        var result = ""
        if let opening = opening {
            result += "\(type(of: self).dateFormatter.string(from: opening)) "
        }
        result += "commodity \(symbol)"
        if let name = name {
            result += "\n  name: \(name)"
        }
        if let price = price {
            result += "\n  price: \(price)"
        }
        return result
    }

    static private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

}

extension Commodity: Comparable {

    /// **<** comparision of the `symbol`s
    ///
    /// - Parameters:
    ///   - lhs: commodity 1
    ///   - rhs: commodity 1
    /// - Returns: lhs.symbol < rhs.symbol
    public static func < (lhs: Commodity, rhs: Commodity) -> Bool {
        return lhs.symbol < rhs.symbol
    }

    /// Retuns if the two commodities are equal, meaning their `symbol`s are equal
    ///
    /// - Parameters:
    ///   - lhs: commodity 1
    ///   - rhs: commodity 1
    /// - Returns: true if the sybols are equal, false otherwise
    public static func == (lhs: Commodity, rhs: Commodity) -> Bool {
        return lhs.symbol == rhs.symbol
    }

}

extension Commodity: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(symbol)
    }

}
