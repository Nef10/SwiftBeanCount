//
//  Custom.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

/// Custom directive
public struct Custom {

    /// Date of the directive
    public let date: Date

    /// Name of the custom directive
    public let name: String

    /// Value of the custom directives
    public let value: String

    /// Create a Custom directive
    ///
    /// - Parameters:
    ///   - date: date
    ///   - name: name
    ///   - value: value
    public init(date: Date, name: String, value: String) {
        self.date = date
        self.name = name
        self.value = value
    }

}

extension Custom: CustomStringConvertible {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// Returns the price string for the ledger.
    public var description: String {
        "\(Self.dateFormatter.string(from: date)) custom \"\(name)\" \(value)"
    }

}

extension Custom: Equatable {

    /// Retuns if the two Custom directives are equal
    ///
    /// - Parameters:
    ///   - lhs: custom 1
    ///   - rhs: custom 1
    /// - Returns: true if the custom directives are equal, false otherwise
    public static func == (lhs: Custom, rhs: Custom) -> Bool {
        lhs.date == rhs.date && lhs.name == rhs.name && lhs.value == rhs.value
    }

}
