//
//  Commodity.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-08.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// A CommoditySymbol is just a string
public typealias CommoditySymbol = String

/// A commodity just consists of a symbol
public class Commodity {

    /// symbol of the commodity
    public let symbol: CommoditySymbol

    /// opening of the commodity
    public let opening: Date?

    /// MetaData of the Commodity
    public let metaData: [String: String]

    /// Creates an commodity with the given symbol, and an optinal opening date
    ///
    /// - Parameters:
    ///   - symbol: symbol of the commodity
    ///   - opening: date the commodity was opened
    public init(symbol: CommoditySymbol, opening: Date? = nil, metaData: [String: String] = [:]) {
        self.symbol = symbol
        self.opening = opening
        self.metaData = metaData
    }

    /// Validates the commodity in the context of a ledger
    ///
    /// If the beancount.plugins.check_commodity plugin is enabled, a commodity is only valid if it has an opening date.
    /// Otherwise, commodities are always valid regardless of opening date.
    ///
    /// - Parameter ledger: The ledger context containing enabled plugins
    /// - Returns: `ValidationResult`
    func validate(in ledger: Ledger) -> ValidationResult {
        // Only check for opening date if the check_commodity plugin is enabled
        if ledger.plugins.contains("beancount.plugins.check_commodity") {
            guard opening != nil else {
                return .invalid("Commodity \(symbol) does not have an opening date")
            }
        }
        return .valid
    }

    /// Validates that the commodity is not used before its opening date
    ///
    /// If the beancount.plugins.check_commodity plugin is enabled, validates that the commodity
    /// is not used before its opening date.
    ///
    /// - Parameters:
    ///   - date: The date when the commodity is being used
    ///   - ledger: The ledger context containing enabled plugins
    /// - Returns: `ValidationResult`
    func validateUsageDate(_ date: Date, in ledger: Ledger) -> ValidationResult {
        // Only check if opening date is set. If it is not set, the validate will ouput an error
        // already, so we do not need to do this again.
        // Also only check usage dates if the check_commodity plugin is enabled
        guard let opening, ledger.plugins.contains("beancount.plugins.check_commodity") else {
            return .valid
        }

        guard date >= opening else {
            let dateFormatter = Self.dateFormatter
            let usageDateString = dateFormatter.string(from: date)
            let openingDateString = dateFormatter.string(from: opening)
            return .invalid("Commodity \(symbol) used on \(usageDateString) before its opening date of \(openingDateString)")
        }

        return .valid
    }

}

extension Commodity: CustomStringConvertible {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// String of the commodity definition
    ///
    /// If no opening is set it is an empty string
    public var description: String {
        guard let opening else {
            return ""
        }
        var result = "\(Self.dateFormatter.string(from: opening)) commodity \(symbol)"
        if !metaData.isEmpty {
            result += "\n\(metaData.map { "  \($0): \"\($1)\"" }.joined(separator: "\n"))"
        }
        return result
    }

}

extension Commodity: Equatable {

    /// Retuns if the two commodities are equal, meaning their `symbol`s and meta data are equal
    ///
    /// - Parameters:
    ///   - lhs: commodity 1
    ///   - rhs: commodity 2
    /// - Returns: true if the sybols and meta data are equal, false otherwise
    public static func == (lhs: Commodity, rhs: Commodity) -> Bool {
        lhs.symbol == rhs.symbol && lhs.metaData == rhs.metaData
    }

}
