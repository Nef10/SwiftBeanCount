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

    /// CommoditySymbol the number is in
    public let commoditySymbol: CommoditySymbol

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
    public init(number: Decimal, commoditySymbol: CommoditySymbol, decimalDigits: Int = 0) {
        self.number = number
        self.commoditySymbol = commoditySymbol
        self.decimalDigits = decimalDigits
    }
}

extension Amount: CustomStringConvertible {

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 100
        return formatter
    }()

    /// Returns a `String` for the ledger which contains the number with the correct number of decimal digits as well as the `commodity`
    public var description: String { "\(amountString) \(commoditySymbol)" }

    // swiftlint:disable:next legacy_objc_type
    private var amountString: String { Self.numberFormatter(fractionDigits: decimalDigits).string(from: number as NSDecimalNumber)! }

    private static func numberFormatter(fractionDigits: Int) -> NumberFormatter {
        let numberFormatter = self.numberFormatter
        numberFormatter.maximumFractionDigits = fractionDigits
        numberFormatter.minimumFractionDigits = fractionDigits
        return numberFormatter
    }

}

extension Amount: MultiCurrencyAmountRepresentable {

    /// the ammount represented as `MultiCurrencyAmount`
    public var multiCurrencyAmount: MultiCurrencyAmount {
        MultiCurrencyAmount(amounts: [commoditySymbol: number], decimalDigits: [commoditySymbol: decimalDigits])
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
        lhs.number == rhs.number && lhs.commoditySymbol == rhs.commoditySymbol && lhs.decimalDigits == rhs.decimalDigits
    }

}

extension Amount: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(number)
        hasher.combine(commoditySymbol)
        hasher.combine(decimalDigits)
    }

}
