//
//  Account.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

public enum AccountType: String {
    case asset = "Assets"
    case liability = "Liabilities"
    case income = "Income"
    case expense = "Expenses"
    case equity = "Equity"

    static func allValues() -> [AccountType] {
        return [.asset, .liability, .income, .expense, .equity]
    }
}

public protocol AccountItem {
    var nameItem: String { get }
    var accountType: AccountType { get }
}

public class AccountGroup: AccountItem {
    public let nameItem: String
    public let baseGroup: Bool
    public let accountType: AccountType
    var accounts = [String: Account]()
    var accountGroups = [String: AccountGroup]()

    public init(nameItem: String, accountType: AccountType, baseGroup: Bool = false) {
        self.nameItem = nameItem
        self.accountType = accountType
        self.baseGroup = baseGroup
    }

    public func children() -> [AccountItem] {
        var result = [AccountItem]()
        result.append(contentsOf: Array(accountGroups.values) as [AccountItem])
        result.append(contentsOf: Array(accounts.values) as [AccountItem])
        return result.sorted { $0.nameItem < $1.nameItem }
    }
}

public class Account: AccountItem {

    public let name: String
    public let accountType: AccountType
    public var commodity: Commodity?
    public var opening: Date?
    public var closing: Date?
    public var nameItem: String {
        return String(describing: name.split(separator: ":").last!)
    }

    public init(name: String, accountType: AccountType) {
        self.name = name
        self.accountType = accountType
    }

    public func isPostingValid(_ posting: Posting) -> Bool {
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

extension Account: CustomStringConvertible {

    public var description: String {
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

extension Account: Equatable {

    public static func == (lhs: Account, rhs: Account) -> Bool {
        return rhs.name == lhs.name && rhs.commodity == lhs.commodity && rhs.opening == lhs.opening && rhs.closing == lhs.closing
    }

}
