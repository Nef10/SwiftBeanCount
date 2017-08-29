//
//  Account.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

class Account {

    let name: String
    var commodity: Commodity?
    var opening: Date?
    var closing: Date?

    init(name: String) {
        self.name = name
    }

    func isPostingValid(_ posting: Posting) -> Bool {
        return posting.account == self && self.allowsPosting(in: posting.amount.commodity) && self.wasOpen(at: posting.transaction.metaData.date)
    }

    private func wasOpen(at date: Date) -> Bool {
        if let opening = self.opening, opening <= date {
            if let closing = self.closing {
                return closing >= date
            }
            return true
        }
        return false
    }

    private func allowsPosting(in commodity: Commodity) -> Bool {
        if let ownCommodity = self.commodity {
            return ownCommodity == commodity
        }
        return true
    }

}

extension Account : CustomStringConvertible {

    var description: String {
        var string = ""
        if let opening = self.opening {
            string += "\(type(of: self).dateFormatter.string(from: opening)) open \(name)"
            if let commodity = self.commodity {
                string += " \(String(describing: commodity))"
            }
            if let closing = self.closing {
                string += "\n\(type(of: self).dateFormatter.string(from: closing)) close \(name)"
            }
        }
        return string
    }

    static private let dateFormatter: DateFormatter = {
        let _dateFormatter = DateFormatter()
        _dateFormatter.dateFormat = "yyyy-MM-dd"
        return _dateFormatter
    }()

}

extension Account : Equatable {

    static func == (lhs: Account, rhs: Account) -> Bool {
        return rhs.name == lhs.name && rhs.commodity == lhs.commodity && rhs.opening == lhs.opening && rhs.closing == lhs.closing
    }

}
