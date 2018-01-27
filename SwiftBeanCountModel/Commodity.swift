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

    /// Creates an commodity with the given symbol
    ///
    /// - Parameter symbol: symbol for the commodity
    public init(symbol: String) {
        self.symbol = symbol
    }

}

extension Commodity: CustomStringConvertible {

    /// Just returns the symbol
    public var description: String { return symbol }
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

    /// Hash of the `symbol`
    public var hashValue: Int {
        return symbol.hashValue
    }

}
