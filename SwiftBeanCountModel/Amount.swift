//
//  Amount.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-21.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// Represents an Amount - a number with a commodity
public struct Amount {

    /// Mumeric value of the amount
    public let number: Decimal

    /// Commodity the number is in
    public let commodity: Commodity

    /// Number of decimal digits the number has
    ///
    /// This is used to maintain the accuracy the number was recorded in to correctly print it and
    /// do checks with the correct tolerance.
    public let decimalDigits: Int

    /// Creates an amount with the given parameters
    ///
    /// - Parameters:
    ///   - number: numeric value
    ///   - commodity: `Commodity`
    ///   - decimalDigits: number of decimal digits the number has
    public init(number: Decimal, commodity: Commodity, decimalDigits: Int = 0) {
        self.number = number
        self.commodity = commodity
        self.decimalDigits = decimalDigits
    }
}

extension Amount: CustomStringConvertible {

    /// Returns a `String` for the ledger which contains the number with the correct number of decimal digits as well as the `commodity`
    public var description: String { return "\(amountString) \(commodity)" }

    private var amountString: String { return type(of: self).numberFormatter(fractionDigits: decimalDigits).string(from: number as NSDecimalNumber)! }

    static private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 100
        return formatter
    }()

    static private func numberFormatter(fractionDigits: Int) -> NumberFormatter {
        let numberFormatter = self.numberFormatter
        numberFormatter.maximumFractionDigits = fractionDigits
        numberFormatter.minimumFractionDigits = fractionDigits
        return numberFormatter
    }

}

extension Amount: MultiCurrencyAmountRepresentable {

    /// the ammount represented as `MultiCurrencyAmount`
    public var multiAccountAmount: MultiCurrencyAmount {
        return MultiCurrencyAmount(amounts: [commodity: number], decimalDigits: [commodity: decimalDigits])
    }

}

extension Amount: Equatable {

    /// Compares two `Amount`s
    ///
    /// Note that the number of decimal digits is compared as well. This means *1.0* and *1.00* is **not** the same.
    ///
    /// - Parameters:
    ///   - lhs: first amount
    ///   - rhs: second amount
    /// - Returns: True if the amounts are the same, false otherwise
    public static func == (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.number == rhs.number && lhs.commodity == rhs.commodity && lhs.decimalDigits == rhs.decimalDigits
    }

}
