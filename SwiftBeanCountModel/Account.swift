//
//  Account.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// AccountType represents the five base account types
public enum AccountType: String {

    /// Asserts is everything an entity owns
    case asset = "Assets"

    /// Liabilities is everything that an entity owes
    case liability = "Liabilities"

    /// Income is everything an entity gets
    case income = "Income"

    /// Expenses is everything an entity loses
    case expense = "Expenses"

    /// Equity consits of the net assets of an entity
    ///
    /// `equity` = `asset` - `liability`
    case equity = "Equity"

    /// Gets all types
    ///
    /// - Returns: `Array` with all five AccountTypes
    public static func allValues() -> [AccountType] {
        return [.asset, .liability, .income, .expense, .equity]
    }
}

/// AccountItems have a name item, which is the last part of the name and and `AccountType`
public protocol AccountItem {

    /// Last part of the name, for **Assets:Cash:CAD** this would be **CAD**
    var nameItem: String { get }
    /// Type, see `AccountType`
    var accountType: AccountType { get }

}

/// A group of accounts.
///
/// If e.g. **Assets:Cash:CAD** and **Assets:Cash:EUR** are `Account`s, **Assets** and **Assets:Cash** would be AccountGroups.
/// In this case **Assets** would be a `baseGroup`
public class AccountGroup: AccountItem {

    /// Last part of the name, for **Assets:Cash:CAD** this would be **CAD**
    public let nameItem: String

    /// Indicates if this a a base group, meaning it directly is one of the 5 `AccountType`s
    public let baseGroup: Bool

    /// Type, see `AccountType`
    public let accountType: AccountType

    var accounts = [String: Account]()
    var accountGroups = [String: AccountGroup]()

    /// Creates an AccountGroup
    ///
    /// - Parameters:
    ///   - nameItem: name for the group, without any **:**
    ///   - accountType: type
    ///   - baseGroup: if this group is one of the five base `AccountType`s
    public init(nameItem: String, accountType: AccountType, baseGroup: Bool = false) {
        self.nameItem = nameItem
        self.accountType = accountType
        self.baseGroup = baseGroup
    }

    /// Get all `AccountItem`s which are children of this group
    ///
    /// AccountItems are the `Account`s which are direct children under this group
    /// and the sub `AccountGroup`s under this group.
    ///
    /// - Returns: Array sorted by name item of children
    public func children() -> [AccountItem] {
        var result = [AccountItem]()
        result.append(contentsOf: Array(accountGroups.values) as [AccountItem])
        result.append(contentsOf: Array(accounts.values) as [AccountItem])
        return result.sorted { $0.nameItem < $1.nameItem }
    }
}

/// Class with represents an Account with a name, commodity, opening and closing date, as well as a type.
///
/// It does hot hold any `Transaction`s
public class Account: AccountItem {

    /// Errors an account can throw
    public enum AccoutError: Error {
        /// an invalid account name
        case invaildName(String)
    }

    static let nameSeperator = Character(":")

    /// Full quilified name of the account, e.g. Assets:Cash:CAD
    public let name: String

    /// Type, see `AccountType`
    public let accountType: AccountType

    /// `Commodity` of this account
    public var commodity: Commodity?

    /// Optional date of opening.
    /// If it exists `isPostingValid(:)` checks that the transaction is on or after this date
    public var opening: Date?

    /// Optional closing date.
    /// If it exists `isPostingValid(:)` checks that the transaction is before or on this date
    public var closing: Date?

    public internal(set) var balances = [Balance]()

    /// Last part of the name, for **Assets:Cash:CAD** this would be **CAD**
    public var nameItem: String {
        return String(describing: name.split(separator: Account.nameSeperator).last!)
    }

    /// Creates an Account
    ///
    /// - Parameters:
    ///   - name: a vaild name for the account
    /// - Throws: AccoutError.invaildName in case the account name is invalid
    public init(name: String) throws {
        guard Account.isNameValid(name) else {
            throw AccoutError.invaildName(name)
        }
        self.name = name
        self.accountType = Account.getAccountType(for: name)
    }

    /// Checks if the given `Posting` is a valid posting for this account.
    /// This includes that the account of the posting is this one, the commodity matches and the account was open at the day of posting
    ///
    /// - Parameter posting: posting to check
    /// - Returns: `ValidationResult`
    func validate(_ posting: Posting) -> ValidationResult {
        assert(posting.account == self, "Checking Posting \(posting) on wrong Account \(self)")
        guard self.allowsPosting(in: posting.amount.commodity) else {
            return .invalid("\(posting.transaction) uses a wrong commodiy for account \(self.name) - Only \(self.commodity!.symbol) is allowed")
        }
        guard self.wasOpen(at: posting.transaction.metaData.date) else {
            return .invalid("\(posting.transaction) was posted while the accout \(self.name) was closed")
        }
        return .valid
    }

    /// Checks if the account is valid
    ///
    /// An account is valid if it has no closing date or a closing date which is >= the opening date
    ///
    /// - Returns: `ValidationResult`
    func validate() -> ValidationResult {
        if let closing = closing {
            guard let opening = opening else {
                return .invalid("Account \(self.name) has a closing date but no opening")
            }
            guard opening <= closing else {
                let closingString = type(of: self).dateFormatter.string(from: closing)
                let openingString = type(of: self).dateFormatter.string(from: opening)
                return .invalid("Account \(self.name) was closed on \(closingString) before it was opened on \(openingString)")
            }
        }
        return .valid
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

    /// Checks if a given name for an account is valid
    ///
    /// This includes that the name start with one of the base groups and is correctly formattet with seperators
    ///
    /// - Parameter name: String to check
    /// - Returns: if the name is valid
    public class func isNameValid(_ name: String) -> Bool {
        guard !name.isEmpty else {
            return false
        }
        for type in AccountType.allValues() {
            if name.starts(with: type.rawValue + String(Account.nameSeperator)) // has to start with one base account followed by a seperator
                && name.last != Account.nameSeperator //  is not allowed to end in a seperator
                && name.range(of: "\(Account.nameSeperator)\(Account.nameSeperator)") == nil { // no account item is allowed to be empty
                return true
            }
        }
        return false
    }

    /// Gets the `AccountType` from a name string
    ///
    /// In case of an invalid account name the function might just return .assets
    ///
    /// - Parameter name: valid account name
    /// - Returns: `AccountType` of the account with this name
    private class func getAccountType(for name: String) -> AccountType {
        var type = AccountType.asset
        for accountType in AccountType.allValues() {
            if name.starts(with: accountType.rawValue ) {
                type = accountType
            }
        }
        return type
    }

}

extension Account: CustomStringConvertible {

    /// Returns the Acount opening and closing string for the ledger.
    ///
    /// If no open date is set it returns an empty string, if only the opening is set the closing line is ommitted
    public var description: String {
        var string = ""
        if let opening = self.opening {
            string += "\(type(of: self).dateFormatter.string(from: opening)) open \(name)"
            if let commodity = self.commodity {
                string += " \(commodity.symbol)"
            }
            if let closing = self.closing {
                string += "\n\(type(of: self).dateFormatter.string(from: closing)) close \(name)"
            }
        }
        return string
    }

    static private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

}

extension Account: Equatable {

    /// Compare the name, commodity as well as the opening and closing of two Accounts.
    ///
    /// This does not compare `Transaction`s as they are not part of Accounts
    public static func == (lhs: Account, rhs: Account) -> Bool {
        return rhs.name == lhs.name && rhs.commodity == lhs.commodity && rhs.opening == lhs.opening && rhs.closing == lhs.closing
    }

}
