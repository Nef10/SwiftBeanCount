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

    /// Returns a `String` for the ledger which contains the number with the correct number of decimal digits as well as the `commodity`
    public var description: String { "\(amountString) \(commoditySymbol)" }

    public var amountString: String {
#if canImport(Darwin)
        return Self.numberFormatter(fractionDigits: decimalDigits).string(for: number)!
#else // Ugly workaround for https://github.com/swiftlang/swift-corelibs-foundation/issues/4221
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let separator = Character(formatter.decimalSeparator)

        formatter.minimumFractionDigits = 0 // Set to 0 first to respect maximumFractionDigits
        formatter.maximumFractionDigits = decimalDigits
        // Max will have the maximum length allowed, but might not have enough decimal digits
        let max = formatter.string(for: number)!
        let maxDecimalDigits = max.contains(separator) ? max.split(separator: separator).last!.count : 0
        if maxDecimalDigits == decimalDigits {
            return max
        }

        // Min will have the minimum length required, but might have too many decimal digits
        formatter.minimumFractionDigits = decimalDigits
        formatter.maximumFractionDigits = decimalDigits // will be ignored
        let min = formatter.string(for: number)!
        let minDecimalDigits = min.contains(separator) ? min.split(separator: separator).last!.count : 0
        if minDecimalDigits == decimalDigits {
            return min
        }

        fatalError("Unable to format amountString for number: \(number) with decimalDigits: \(decimalDigits). " +
            "Min decimal digits: \(minDecimalDigits), Max decimal digits: \(maxDecimalDigits)")
#endif
    }

    private static func numberFormatter(fractionDigits: Int) -> NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
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
