//
//  Ledger.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// A Ledger is the main part of the model, it contains all necessary information.
public class Ledger {

    /// Array of all `Transaction`s in this ledger
    public var transactions = [Transaction]()

    /// Errors which this ledger contains
    public var errors = [String]()

    /// Array of all `Commodity`s in this ledger
    public var commodities: [Commodity] { return Array(commodity.values) }

    /// Array of all `Account`s in this ledger
    public var accounts: [Account] { return Array(account.values) }

    /// Array of all `Tag`s in this ledger
    public var tags: [Tag] { return Array(tag.values) }

    /// Array of the main `AccountGroup`s (all five `AccountType`s) in this ledger
    public var accountGroups: [AccountGroup] { return Array(accountGroup.values) }

    private var commodity = [String: Commodity]()
    private var account = [String: Account]()
    private var tag = [String: Tag]()
    private let accountGroup: [String: AccountGroup]

    /// Creates an empty ledget with the `accountGroups` set up
    public init() {
        var groups = [String: AccountGroup]()
        for accountType in AccountType.allValues() {
            groups[accountType.rawValue] = AccountGroup(nameItem: accountType.rawValue, accountType: accountType, baseGroup: true)
        }
        accountGroup = groups
    }

    /// Gets `Commodity` object for the Commodity with the given string
    /// This function ensures that there is exactly one object per Commodity
    ///
    /// - Parameter name: commodity name
    /// - Returns: Commodity
    public func getCommodityBy(symbol: String) -> Commodity {
        if self.commodity[symbol] == nil {
            let commodity = Commodity(symbol: symbol)
            self.commodity[symbol] = commodity
        }
        return self.commodity[symbol]!
    }

    /// Gets the `Account` object for Account with the given string
    /// This function ensures that there is exactly one object per Account
    ///
    /// - Parameter name: account name
    /// - Returns: Account or nil if the name is invalid
    public func getAccountBy(name: String) -> Account? {
        if self.account[name] == nil {
            guard let account = try? Account(name: name) else {
                return nil
            }
            var group: AccountGroup!
            let nameItems = name.split(separator: Account.nameSeperator).map { String($0) }
            for (index, nameItem) in nameItems.enumerated() {
                switch index {
                case 0:
                    group = accountGroup[nameItem]
                case nameItems.count - 1:
                    group.accounts[nameItem] = account
                default:
                    if group.accountGroups[nameItem] == nil {
                        group.accountGroups[nameItem] = AccountGroup(nameItem: nameItem, accountType: group.accountType)
                    }
                    group = group.accountGroups[nameItem]!
                }
            }
            self.account[name] = account
        }
        return self.account[name]!
    }

    /// Gets the `Tag` object for Tag with the given string
    /// This function ensures that there is exactly one object per Tag
    ///
    /// - Parameter name: tag name
    /// - Returns: Tag
    public func getTagBy(name: String) -> Tag {
        if self.tag[name] == nil {
            let tag = Tag(name: name)
            self.tag[name] = tag
        }
        return self.tag[name]!
    }

}

extension Ledger: CustomStringConvertible {

    /// Retuns the ledger file for this ledger.
    ///
    /// It consists of all `Account` and `Transaction` statements, but does not include `errors`
    public var description: String {
        var string = ""
        string.append(self.accounts.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !self.transactions.isEmpty {
            string.append("\n")
        }
        string.append(self.transactions.map { String(describing: $0) }.joined(separator: "\n"))
        return string
    }

}

extension Ledger: Equatable {

    /// Compares two Ledgers
    ///
    /// Compared are the `Account`s, `Commodity`s, `Tag`s and `Transaction`s but not the `errors`
    ///
    /// - Parameters:
    ///   - lhs: ledger one
    ///   - rhs: ledger two
    /// - Returns: true if they hold the same information, otherwise false
    public static func == (lhs: Ledger, rhs: Ledger) -> Bool {
        return lhs.account == rhs.account && rhs.commodity == lhs.commodity && rhs.tag == lhs.tag && rhs.transactions == lhs.transactions
    }

}
