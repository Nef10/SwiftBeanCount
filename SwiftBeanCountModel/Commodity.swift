//
//  Commodity.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

class Commodity {

    static let noCommodity = Commodity(symbol: "")

    let symbol: String

    init(symbol: String) {
        self.symbol = symbol
    }

}

extension Commodity : CustomStringConvertible {
    var description: String { return symbol }
}

extension Commodity : Comparable {

    static func < (lhs: Commodity, rhs: Commodity) -> Bool {
        return lhs.symbol < rhs.symbol
    }

    static func == (lhs: Commodity, rhs: Commodity) -> Bool {
        return lhs.symbol == rhs.symbol
    }

}

extension Commodity : Hashable {
    var hashValue: Int {
        return symbol.hashValue
    }
}
