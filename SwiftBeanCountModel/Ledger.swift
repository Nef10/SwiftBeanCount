//
//  Ledger.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

public class Ledger {

    public var transactions = [Transaction]()
    public var errors = [String]()

    private var commodity = [String: Commodity]()
    private var account = [String: Account]()
    private var tag = [String: Tag]()

    var commodities: [Commodity] { return Array(commodity.values) }
    var accounts: [Account] { return Array(account.values) }
    var tags: [Tag] { return Array(tag.values) }

    public init() {
    }

    /// Gets Commodity object for the Commodity with the given string
    /// This function ensures that there is exactly one object per Commodity
    ///
    /// - Parameter name: commodity name
    /// - Returns: Commodity
    public func getCommodityBy(symbol: String) -> Commodity {
        if self.commodity[symbol] == nil {
            let commodity = Commodity(symbol:symbol)
            self.commodity[symbol] = commodity
        }
        return self.commodity[symbol]!
    }

    /// Gets Account object for Account with the given string
    /// This function ensures that there is exactly one object per Account
    ///
    /// - Parameter name: account name
    /// - Returns: Account
    public func getAccountBy(name: String) -> Account {
        if self.account[name] == nil {
            let account = Account(name:name)
            self.account[name] = account
        }
        return self.account[name]!
    }

    /// Gets Tag object for Tag with the given string
    /// This function ensures that there is exactly one object per Tag
    ///
    /// - Parameter name: tag name
    /// - Returns: Tag
    public func getTagBy(name: String) -> Tag {
        if self.tag[name] == nil {
            let tag = Tag(name:name)
            self.tag[name] = tag
        }
        return self.tag[name]!
    }

}

extension Ledger : CustomStringConvertible {
    public var description: String {
        var string = ""
        string.append(self.transactions.map({ String(describing: $0) }).joined(separator: "\n"))
        if !string.isEmpty && !self.accounts.isEmpty {
            string.append("\n")
        }
        string.append(self.accounts.map({ String(describing: $0) }).joined(separator: "\n"))
        return string
    }
}

extension Ledger : Equatable {

    /// erros are not taken into account
    public static func == (lhs: Ledger, rhs: Ledger) -> Bool {
        return lhs.account == rhs.account && rhs.commodity == lhs.commodity && rhs.tag == lhs.tag && rhs.transactions == lhs.transactions
    }

}
