//
//  Event.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

/// Event
public struct Event: MetaDataAttachable {

    /// Date of the event
    public let date: Date

    /// Name of the event
    public let name: String

    /// Value of the event
    public let value: String

    /// MetaData of the event
    public var metaData = [String: String]()

    /// Create an Event
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

extension Event: CustomStringConvertible {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// Returns the event string for the ledger.
    public var description: String {
        "\(Self.dateFormatter.string(from: date)) event \"\(name)\" \"\(value)\""
    }

}

extension Event: Equatable {

    /// Retuns if the two events are equal
    ///
    /// - Parameters:
    ///   - lhs: event 1
    ///   - rhs: event 2
    /// - Returns: true if the events are equal, false otherwise
    public static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.date == rhs.date && lhs.name == rhs.name && lhs.value == rhs.value && lhs.metaData == rhs.metaData
    }

}
