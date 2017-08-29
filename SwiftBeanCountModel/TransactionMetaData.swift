//
//  TransactionMetaData.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

struct TransactionMetaData {

    let date: Date
    let payee: String
    let narration: String
    let flag: Flag
    let tags: [Tag]

}

extension TransactionMetaData : CustomStringConvertible {

    var description: String {
        var tagString =  ""
        tags.forEach({ tagString += " \(String(describing: $0))" })
        return "\(self.dateString) \(String(describing: flag)) \"\(payee)\" \"\(narration)\"\(tagString)"
    }

    private var dateString: String { return type(of: self).dateFormatter.string(from: date) }

    static private let dateFormatter: DateFormatter = {
        let _dateFormatter = DateFormatter()
        _dateFormatter.dateFormat = "yyyy-MM-dd"
        return _dateFormatter
    }()

}

extension TransactionMetaData : Equatable {
    static func == (lhs: TransactionMetaData, rhs: TransactionMetaData) -> Bool {
        return lhs.date == rhs.date && lhs.payee == rhs.payee && lhs.narration == rhs.narration && lhs.flag == rhs.flag && lhs.tags == rhs.tags
    }
}
