//
//  MultiCurrencyAmount.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-07-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// protocol to describe objects which can be represented as `MultiCurrencyAmount`
public protocol MultiCurrencyAmountRepresentable {

    /// the `MultiCurrencyAmount` representation of the current object
    var multiCurrencyAmount: MultiCurrencyAmount { get }

}

/// Represents an amout which consists of amouts in multiple currencies
///
/// **Tolerance** for validation: Half of the last digit of precision provided separately for each currency
///
public struct MultiCurrencyAmount {

    /// amounts per currency
    public let amounts: [CommoditySymbol: Decimal]
    let decimalDigits: [CommoditySymbol: Int]

    /// Checks if all amounts of the first one are equal to the one in the second
    ///
    /// In the second amount contains amounts in currencies which are not in the first one,
    /// or the tolerance is lower in the second one, this will NOT result in an error.
    ///
    /// To check this combinations call this function twice with switched arguments
    ///
    /// - Parameters:
    ///   - amount1: first amount
    ///   - amount2: second amount
    /// - Returns: `ValidationResult`
    private static func equalWithinTolerance(amount1: Self, amount2: Self) -> ValidationResult {
        for (commoditySymbol, decimal1) in amount1.amounts {
            let decimal2 = amount2.amounts[commoditySymbol] ?? 0
            let result = decimal1 - decimal2
            let decimalDigits = amount1.decimalDigits[commoditySymbol] ?? 0
            var tolerance = Decimal()
            if decimalDigits != 0 {
                tolerance = Decimal(sign: FloatingPointSign.plus, exponent: -(decimalDigits + 1), significand: Decimal(5))
            }
            if result > tolerance || result < (tolerance == 0 ? tolerance : -tolerance) {
                return .invalid("\(result) \(commoditySymbol) too much (\(tolerance) tolerance)")
            }
        }
        return .valid
    }

    /// Returns the amount of one commodity
    ///
    /// If there is not amount for the given symbol in this MultiCurrencyAmount
    /// it returns an amount with zero.
    ///
    /// - Parameter symbol: symbol of the commodity to get
    /// - Returns: Amount
    public func amountFor(symbol: CommoditySymbol) -> Amount {
        guard let number = amounts[symbol] else {
            return Amount(number: 0, commoditySymbol: symbol)
        }
        return Amount(number: number, commoditySymbol: symbol, decimalDigits: decimalDigits[symbol] ?? 0)
    }

    /// Checks is the amount is zero within the allowed tolerance
    ///
    /// - Returns: Bool
    public func isZeroWithTolerance() -> Bool {
        if case .valid = validateZeroWithTolerance() {
            return true
        }
        return false
    }

    /// Validates that the amount is zero within the allowed tolerance
    ///
    /// - Returns: `ValidationResult`
    func validateZeroWithTolerance() -> ValidationResult {
        let zero = Self(amounts: [:], decimalDigits: self.decimalDigits)
        return Self.equalWithinTolerance(amount1: self, amount2: zero)
    }

    /// Validates that the amount is the same in the MultiCurrencyAmount
    ///
    /// Ignores other currencies in the MultiCurrencyAmount
    ///
    /// - Parameter amount: amount to validate
    /// - Returns: `ValidationResult`
    func validateOneAmountWithTolerance(amount: Amount) -> ValidationResult {
        var decimalDigits = amount.multiCurrencyAmount.decimalDigits
        decimalDigits[amount.commoditySymbol] = decimalDigitToKeep(amount.multiCurrencyAmount.decimalDigits[amount.commoditySymbol]!,
                                                                   self.decimalDigits[amount.commoditySymbol])
        return Self.equalWithinTolerance(amount1: Self(amounts: amount.multiCurrencyAmount.amounts,
                                                       decimalDigits: decimalDigits), amount2: self)
    }

}

extension MultiCurrencyAmount {

    /// Creates an empty MultiCurrencyAmount
    public init() {
        amounts = [:]
        decimalDigits = [:]
    }

}

extension MultiCurrencyAmount: MultiCurrencyAmountRepresentable {

    /// returns self to conform to the `MultiCurrencyAmountRepresentable` protocol
    public var multiCurrencyAmount: MultiCurrencyAmount {
        self
    }

}

extension MultiCurrencyAmount: Equatable {
    public static func == (lhs: MultiCurrencyAmount, rhs: MultiCurrencyAmount) -> Bool {
        lhs.amounts == rhs.amounts && lhs.decimalDigits == rhs.decimalDigits
    }
}

/// Adds two `MultiCurrencyAmountRepresentable`s into a MultiCurrencyAmount
///
/// If the MultiCurrencyAmount of both MultiCurrencyAmountRepresentable contain an `Amount` in the same `Commodity`
/// the higher number of decimalDigits will be used to ensure the tolerance is correct, except one is 0 than 0 is used
/// as it is more precise
///
/// - Parameters:
///   - left: first MultiCurrencyAmountRepresentable, the multiAccountAmount will be added
///   - right: second MultiCurrencyAmountRepresentable, the multiAccountAmount will be added
/// - Returns: MultiCurrencyAmount which includes both amounts
public func + (left: MultiCurrencyAmountRepresentable, right: MultiCurrencyAmountRepresentable) -> MultiCurrencyAmount {
    var result = left.multiCurrencyAmount.amounts
    var decimalDigits = left.multiCurrencyAmount.decimalDigits
    for (commodity, decimal) in right.multiCurrencyAmount.amounts {
        result[commodity] = (result[commodity] ?? Decimal(0)) + decimal
    }
    for (commodity, rightDigits) in right.multiCurrencyAmount.decimalDigits {
        decimalDigits[commodity] = decimalDigitToKeep(rightDigits, decimalDigits[commodity])
    }
    return MultiCurrencyAmount(amounts: result, decimalDigits: decimalDigits)
}

/// Adds the `MultiCurrencyAmount` of a `MultiCurrencyAmountRepresentable` to a `MultiCurrencyAmount`
///
/// - Parameters:
///   - left: first MultiCurrencyAmount which at the same time will store the result
///   - right: MultiCurrencyAmountRepresentable of which the multiAccountAmount will be added
public func += (left: inout MultiCurrencyAmount, right: MultiCurrencyAmountRepresentable) {
    left = left + right
}

/// Returns the number of decimals digits which is more precise
///
/// If one of the numbers is zero it returns zero as this indicats no tolerance.
/// Otherwise the higher number is more precise.
///
/// - Parameters:
///   - decimal1: first decimal
///   - decimal2: secons decimal
/// - Returns: the decimal which indicats higher precision
private func decimalDigitToKeep(_ decimal1: Int, _ decimal2: Int?) -> Int {
    guard let decimal2 else {
        return decimal1
    }
    if min(decimal1, decimal2) == 0 {
        return 0
    }
    return max(decimal1, decimal2)
}
