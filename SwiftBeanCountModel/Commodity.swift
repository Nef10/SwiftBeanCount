//
//  Commodity.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

public class Commodity {

    public static let noCommodity = Commodity(symbol: "")

    public let symbol: String

    public init(symbol: String) {
        self.symbol = symbol
    }

}

extension Commodity : CustomStringConvertible {
    public var description: String { return symbol }
}

extension Commodity : Comparable {

    public static func < (lhs: Commodity, rhs: Commodity) -> Bool {
        return lhs.symbol < rhs.symbol
    }

    public static func == (lhs: Commodity, rhs: Commodity) -> Bool {
        return lhs.symbol == rhs.symbol
    }

}

extension Commodity : Hashable {
    public var hashValue: Int {
        return symbol.hashValue
    }
}
