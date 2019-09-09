//
//  Cost.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2019-09-08.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

/// Cost of a posting
public class Cost {

    // Amount
    public let amount: Amount?

    /// Optional date to identify a lot in the inventory - if no date is set for positive amount, the transactions date is used
    public let date: Date?

    /// Optional label to identify a lot in the inventory
    public let label: String?

    public init(amount: Amount?, date: Date?, label: String?) {
        self.amount = amount
        self.date = date
        self.label = label
    }

}

extension Cost: CustomStringConvertible {

    /// String to describe the cost in the ledget file
    public var description: String {
        var results = [String]()
        if let date = date {
            results.append(type(of: self).dateFormatter.string(from: date))
        }
        if let amount = amount {
            results.append(amount.description)
        }
        if let label = label {
            results.append("\"\(label)\"")
        }
        return "{\(results.joined(separator: ", "))}"
    }

    static private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

}

extension Cost: Equatable {

    /// Compares two `Cost`s
    ///
    /// - Parameters:
    ///   - lhs: first cost
    ///   - rhs: second const
    /// - Returns: True if the costs are the same, false otherwise
    public static func == (lhs: Cost, rhs: Cost) -> Bool {
        return lhs.amount == rhs.amount && lhs.date == rhs.date && lhs.label == rhs.label
    }

}
