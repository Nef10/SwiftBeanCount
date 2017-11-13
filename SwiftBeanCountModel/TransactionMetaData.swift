//
//  TransactionMetaData.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

public struct TransactionMetaData {

    public let date: Date
    public let payee: String
    public let narration: String
    public let flag: Flag
    public let tags: [Tag]

    public init(date: Date, payee: String, narration: String, flag: Flag, tags: [Tag]) {
        self.date = date
        self.payee = payee
        self.narration = narration
        self.flag = flag
        self.tags = tags
    }

}

extension TransactionMetaData: CustomStringConvertible {

    public var description: String {
        var tagString =  ""
        tags.forEach { tagString += " \(String(describing: $0))" }
        return "\(self.dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\"\(tagString)"
    }

    private var dateString: String { return type(of: self).dateFormatter.string(from: date) }

    static private let dateFormatter: DateFormatter = {
        let _dateFormatter = DateFormatter()
        _dateFormatter.dateFormat = "yyyy-MM-dd"
        return _dateFormatter
    }()

}

extension TransactionMetaData: Equatable {
    public static func == (lhs: TransactionMetaData, rhs: TransactionMetaData) -> Bool {
        return lhs.date == rhs.date && lhs.payee == rhs.payee && lhs.narration == rhs.narration && lhs.flag == rhs.flag && lhs.tags == rhs.tags
    }
}
