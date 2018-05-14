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

    /// Errors which can occur when working with the ledger
    public enum LedgerError: Error {
        /// Error if the object your try to add already exists in the ledger
        case alreadyExists(String)
    }

    /// Array of all `Transaction`s in this ledger
    public private(set) var transactions = [Transaction]()

    /// Errors which this ledger contains
    public var errors = [String]()

    /// Array of all `Commodity`s in this ledger
    public var commodities: [Commodity] { return Array(commodity.values) }

    /// Array of all `Account`s in this ledger
    public var accounts: [Account] { return Array(account.values) }

    /// Array of all `Tag`s in this ledger
    public var tags: [Tag] { return Array(tag.values) }

    public var prices: [Price] {
        return Array(price.values.map { Array($0.values) }.map { $0.map { Array($0.values) } }.joined().joined())
    }

    /// Array of the main `AccountGroup`s (all five `AccountType`s) in this ledger
    public var accountGroups: [AccountGroup] { return Array(accountGroup.values) }

    private var commodity = [String: Commodity]()
    private var account = [String: Account]()
    private var tag = [String: Tag]()
    private var price = [Commodity: [Commodity: [Date: Price]]]()
    private let accountGroup: [String: AccountGroup]

    /// Creates an empty ledger with the `accountGroups` set up
    public init() {
        var groups = [String: AccountGroup]()
        for accountType in AccountType.allValues() {
            groups[accountType.rawValue] = AccountGroup(nameItem: accountType.rawValue, accountType: accountType, baseGroup: true)
        }
        accountGroup = groups
    }

    /// Adds a `Transcaction` to the ledger
    ///
    /// This function does not preserve properties of the accounts,
    /// tags or commodities added other than name/symbol.
    ///
    /// Please note that this function internally copies the object,
    /// therefore you should not keep a copy. However the old object
    /// is equal to the new one if the contained accouts are either coming from
    /// the ledger or have all properties set correctly.
    ///
    /// - Parameter transaction: transaction to add
    /// - Returns: added transaction
    public func add(_ transaction: Transaction) -> Transaction {
        let newTransaction = Transaction(metaData: getTransactionMetaData(for: transaction.metaData))
        newTransaction.postings = transaction.postings.map { try! getPosting(for: $0, transaction: newTransaction) } // swiftlint:disable:this force_try
        transactions.append(newTransaction)
        return newTransaction
    }

    /// Adds an `Account` to the ledger
    ///
    /// - Parameter account: account to add
    /// - Throws: If the account already exists
    public func add(_ account: Account) throws {
        self.account[account.name] = try getAccount(for: account, keepProperties: true)
    }

    /// Adds a `Commodity` to the ledger
    ///
    /// - Parameter commodity: commodity to add
    /// - Throws: If the commodity already exists
    public func add(_ commodity: Commodity) throws {
        self.commodity[commodity.symbol] = try getCommodityWithProperties(for: commodity)
    }

    /// Adds a `Tag` to the ledger
    ///
    /// - Parameter tag: tag to add
    /// - Throws: If the tag already exists
    public func add(_ tag: Tag) throws {
        self.tag[tag.name] = try getTagWithProperties(for: tag)
    }

    /// Adds a `Price` to the ledger
    ///
    /// - Parameter price: `Price` to add
    /// - Throws: If the price already exists
    public func add(_ price: Price) throws {
        guard self.price[price.commodity]?[price.amount.commodity]?[price.date] == nil else {
            throw LedgerError.alreadyExists(String(describing: price))
        }
        if self.price[price.commodity] == nil {
            self.price[price.commodity] = [Commodity: [Date: Price]]()
        }
        if self.price[price.commodity]![price.amount.commodity] == nil {
            self.price[price.commodity]![price.amount.commodity] = [Date: Price]()
        }
        self.price[price.commodity]![price.amount.commodity]![price.date] = price
    }

    /// Validates ledger and adds all validation errors to the error array
    ///
    /// Note: If called multiple times, the error will show up multiple times
    public func validate() {
        errors.append(contentsOf: transactions.compactMap { $0.isValid() ? nil : "Transaction \($0) is invalid" })
        errors.append(contentsOf: accounts.compactMap { $0.isValid() ? nil : "Account \($0) is invalid" })
    }

    /// Converts `TransactionMetaData` so that the new one uses the correct `Tag` objects.
    /// Properties of these objects are not maintained.
    ///
    /// - Parameter metaData: TransactionMetaData to convert
    /// - Returns: TransactionMetaData which can be added to the ledger
    private func getTransactionMetaData(for metaData: TransactionMetaData) -> TransactionMetaData {
        return TransactionMetaData(date: metaData.date,
                                   payee: metaData.payee,
                                   narration: metaData.narration,
                                   flag: metaData.flag,
                                   tags: metaData.tags.map { getTag(for: $0) })
    }

    /// Converts `Posting`s so that the new one uses the correct `Account` and `Commodity` objects.
    /// Properties of these objects are not maintained.
    ///
    /// - Parameter posting: Posting to convert
    /// - Returns: Posting which can be added to the ledger
    /// - Throws: If the account name is invalid
    private func getPosting(for posting: Posting, transaction: Transaction) throws -> Posting {
        return Posting(account: try getAccount(for: posting.account),
                       amount: getLedgerAmount(for: posting.amount),
                       transaction: transaction,
                       price: posting.price != nil ? getLedgerAmount(for: posting.price!) : nil)
    }

    /// Converts `Amount`s so that the new one uses the correct `Commodity` objects.
    /// Properties of these objects are not maintained.
    ///
    /// - Parameter metaData: amount to convert
    /// - Returns: Amount which can be added to the ledger
    private func getLedgerAmount(for amount: Amount) -> Amount {
        return Amount(number: amount.number,
                      commodity: getCommodity(for: amount.commodity),
                      decimalDigits: amount.decimalDigits)
    }

    /// Converts `Account`s so that all accounts exists only once in a ledger
    ///
    /// - Parameters:
    ///   - account: account to convert
    ///   - keepProperties: if true all properties of the accounts are added to the return object, otherwise only the name
    ///                     Note: You cannot keep properties if an account with this name already exists in the ledger
    /// - Returns: Account to add to the ledger
    /// - Throws: If the account name is invalid or you try to keep properties of an account which already exists
    private func getAccount(for account: Account, keepProperties: Bool = false) throws -> Account {
        let name = account.name
        if self.account[name] == nil {
            let account = keepProperties ? account : try Account(name: name)
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
        } else if keepProperties {
            throw LedgerError.alreadyExists(String(describing: account))
        }
        return self.account[name]!
    }

    /// Converts `Tag`s so that all tags exists only once in a ledger. This function only keeps the name of the tag.
    ///
    /// - Parameter tag: tag to convert
    /// - Returns: Tag to add to the ledger
    private func getTag(for tag: Tag) -> Tag {
        let name = tag.name
        if self.tag[name] == nil {
            self.tag[name] = Tag(name: name)
        }
        return self.tag[name]!
    }

    /// Converts `Tag`s so that all tags exists only once in a ledger. This function keeps all properties.
    ///
    /// Note: You can only do this if a tag with the name does not yet exists in the ledger.
    ///
    /// - Parameter tag: tag to convert
    /// - Returns: Tag to add to the ledger
    /// - Throws: If a tag with the name does exists in the ledger
    private func getTagWithProperties(for tag: Tag) throws -> Tag {
        guard self.tag[tag.name] == nil else {
            throw LedgerError.alreadyExists(String(describing: tag))
        }
        self.tag[tag.name] = tag
        return tag
    }

    /// Converts `Commodity`s so that all commodities exists only once in a ledger. This function only keeps the symbol
    ///
    /// - Parameter commodity: commodity to convert
    /// - Returns: Commodity to add to the ledger
    private func getCommodity(for commodity: Commodity) -> Commodity {
        let symbol = commodity.symbol
        if self.commodity[symbol] == nil {
            self.commodity[symbol] = Commodity(symbol: symbol)
        }
        return self.commodity[symbol]!
    }

    /// Converts `Commodity`s so that all commodities exists only once in a ledger. This function keeps all properties
    ///
    /// Note: You can only do this if a commodity with the symbol does not yet exists in the ledger.
    ///
    /// - Parameter commodity: commodity to convert
    /// - Returns: Commodity to add to the ledger
    /// - Throws: If a commodity with the symbol does exists in the ledger
    private func getCommodityWithProperties(for commodity: Commodity) throws -> Commodity {
        guard self.commodity[commodity.symbol] == nil else {
            throw LedgerError.alreadyExists(String(describing: commodity))
        }
        self.commodity[commodity.symbol] = commodity
        return commodity
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
