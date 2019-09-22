//
//  TransactionMetaData.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// TransactionMetaData is data which is or can be attatched to an `Transaction`.
///
/// It consists of date, payee, narration as well as a flag and tags.
public struct TransactionMetaData {

    /// Date of the `Transaction`
    public let date: Date

    /// `String` describing the payee
    public let payee: String

    /// `String` with a comment for the `Transaction`
    public let narration: String

    /// `Flag` of the `Transaction`
    public let flag: Flag

    /// Array of `Tag`s, can be empty
    public let tags: [Tag]

    /// Creates an transaction with the given parameters
    ///
    /// - Parameters:
    ///   - date: date of the transaction
    ///   - payee: `String` describing the payee
    ///   - narration: `String` with a comment for the `Transaction`
    ///   - flag: `Flag`
    ///   - tags: Array of `Tag`s, can be empty
    public init(date: Date, payee: String, narration: String, flag: Flag, tags: [Tag]) {
        self.date = date
        self.payee = payee
        self.narration = narration
        self.flag = flag
        self.tags = tags
    }

}

extension TransactionMetaData: CustomStringConvertible {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// `String` to represent the meta data of the `Transaction` in the ledger file (e.g. the first line above the `Posting`s
    public var description: String {
        var tagString =  ""
        tags.forEach { tagString += " \(String(describing: $0))" }
        return "\(self.dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\"\(tagString)"
    }

    private var dateString: String { return Self.dateFormatter.string(from: date) }

}

extension TransactionMetaData: Equatable {

    /// Compares two TransactionMetaData
    ///
    /// - Parameters:
    ///   - lhs: first TransactionMetaData
    ///   - rhs: second TransactionMetaData
    /// - Returns: true if all properties are the same, false otherwise
    public static func == (lhs: TransactionMetaData, rhs: TransactionMetaData) -> Bool {
        lhs.date == rhs.date && lhs.payee == rhs.payee && lhs.narration == rhs.narration && lhs.flag == rhs.flag && lhs.tags == rhs.tags
    }

}
