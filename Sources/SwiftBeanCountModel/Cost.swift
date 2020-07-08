//
//  Cost.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2019-09-08.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

/// Errors Cost can throw
public enum CostError: Error {
    /// a negative amount
    case negativeAmount(String)
}

/// Cost of a posting
public class Cost {

    /// Amount
    public let amount: Amount?

    /// Optional date to identify a lot in the inventory - if no date is set for positive amount, the transactions date is used
    public let date: Date?

    /// Optional label to identify a lot in the inventory
    public let label: String?

    /// Creates a Cost
    ///
    /// - Parameters:
    ///   - amount: optional `Amount`
    ///   - date: optinal Date
    ///   - label: optinal label String
    /// - Throws: if the cost cannot be created, e.g. if the amount is negative
    public init(amount: Amount?, date: Date?, label: String?) throws {
        self.amount = amount
        self.date = date
        self.label = label
        if let amount = amount {
            guard amount.number.sign == .plus else {
                throw CostError.negativeAmount("\(self)")
            }
        }
    }

    /// Checks if this price should match another one for inventory booking
    ///
    /// If a property is present in this cost, if needs to be equal to the
    /// on of the given cost. If a property is not present in this cost
    /// the value of the other property does not matter.
    ///
    /// - Parameter cost: cost which should be matched
    /// - Returns: true if the cost matches, false otherwise
    func matches(cost: Cost) -> Bool {
        if let amount = self.amount {
            if amount != cost.amount {
                return false
            }
        }
        if let date = self.date {
            if date != cost.date {
                return false
            }
        }
        if let label = self.label {
            if label != cost.label {
                return false
            }
        }
        return true
    }

}

extension CostError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .negativeAmount(error):
            return "Invalid Cost, negative amount: \(error)"
        }
    }
}

extension Cost: CustomStringConvertible {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// String to describe the cost in the ledger file
    public var description: String {
        var results = [String]()
        if let date = date {
            results.append(Self.dateFormatter.string(from: date))
        }
        if let amount = amount {
            results.append(amount.description)
        }
        if let label = label {
            results.append("\"\(label)\"")
        }
        return "{\(results.joined(separator: ", "))}"
    }

}

extension Cost: Equatable {

    /// Compares two `Cost`s
    ///
    /// - Parameters:
    ///   - lhs: first cost
    ///   - rhs: second const
    /// - Returns: True if the costs are the same, false otherwise
    public static func == (lhs: Cost, rhs: Cost) -> Bool {
        lhs.amount == rhs.amount && lhs.date == rhs.date && lhs.label == rhs.label
    }

}

extension Cost: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(amount)
        hasher.combine(date)
        hasher.combine(label)
    }

}
