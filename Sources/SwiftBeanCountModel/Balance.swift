//
//  Balance.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2018-05-13.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

import Foundation

/// An assert that the balance of a given commodity is correct for the accout at the end of the given day
public struct Balance {

    /// Date of the Balance
    public let date: Date

    /// `AccountName` of the Balance
    public let accountName: AccountName

    /// `Amount` of the Balance
    public let amount: Amount

    /// MetaData of the Balance
    public let metaData: [String: String]

    /// Create a Balance
    ///
    /// - Parameters:
    ///   - date: date of the balance
    ///   - account: account
    ///   - amount: amount
    public init(date: Date, accountName: AccountName, amount: Amount, metaData: [String: String] = [:]) {
        self.date = date
        self.accountName = accountName
        self.amount = amount
        self.metaData = metaData
    }

    /// Validates that the commodity used in the balance is not used before its opening date
    ///
    /// - Parameter ledger: The ledger context
    /// - Returns: `ValidationResult`
    func validate(in ledger: Ledger) -> ValidationResult {
        if let commodity = ledger.commodities.first(where: { $0.symbol == amount.commoditySymbol }) {
            return commodity.validateUsageDate(date, in: ledger)
        }
        return .valid
    }

}

extension Balance: CustomStringConvertible {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// Returns the price string for the ledger.
    public var description: String {
        var result = "\(Self.dateFormatter.string(from: date)) balance \(accountName) \(amount)"
        if !metaData.isEmpty {
            result += "\n\(metaData.map { "  \($0): \"\($1)\"" }.joined(separator: "\n"))"
        }
        return result
    }

}

extension Balance: Equatable {

    /// Retuns if the two prices are equal
    ///
    /// - Parameters:
    ///   - lhs: price 1
    ///   - rhs: price 2
    /// - Returns: true if the prices are equal, false otherwise
    public static func == (lhs: Balance, rhs: Balance) -> Bool {
        lhs.date == rhs.date && lhs.accountName == rhs.accountName && lhs.amount == rhs.amount && lhs.metaData == rhs.metaData
    }

}
