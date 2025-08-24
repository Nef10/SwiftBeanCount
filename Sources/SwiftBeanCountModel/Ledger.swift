//
//  Ledger.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// Errors which can occur when working with the ledger
public enum LedgerError: Error {
    /// Error if the object your try to add already exists in the ledger
    case alreadyExists(String)
}

/// A Ledger is the main part of the model, it contains all necessary information.
public class Ledger {

    /// Array of all `Transaction`s in this ledger
    public private(set) var transactions = [Transaction]()

    /// Errors from the ledger and the parsing
    ///
    /// Returns `ledgerErrors` and `parsingErrors`
    /// Note: This property is computed, so please cache the result
    public var errors: [String] { parsingErrors + ledgerErrors }

    /// Errors which this ledger contains
    ///
    /// This includes failed balances assertions, ...
    /// Note: This property is computed, so please cache the result
    public var ledgerErrors: [String] { validate() }

    /// Errors while reading the ledger
    ///
    /// This can be used by a parser to store errors which occurred while trying
    /// to fill in the ledger. The ledger itself will not put anything inside.
    public var parsingErrors = [String]()

    /// Array of all `Commodity`s in this ledger
    public var commodities: [Commodity] { Array(commodity.values) }

    /// Array of all `Account`s in this ledger
    public var accounts: [Account] { Array(account.values) }

    /// Array of all `Tag`s in this ledger
    public var tags: [Tag] { Array(tag.values) }

    ///  Array of all `Price`s in this ledger
    public var prices: [Price] {
        Array(price.values.map { Array($0.values) }.map { $0.map { Array($0.values) } }.joined().joined())
    }

    /// Array of the main `AccountGroup`s (all five `AccountType`s) in this ledger
    public var accountGroups: [AccountGroup] { Array(accountGroup.values) }

    /// Array of all plugins
    public var plugins = [String]()

    /// Array of all options
    public var option = [Option]()

    /// Array of all events
    public var events = [Event]()

    /// Array of all Custom directives
    public var custom = [Custom]()

    private var commodity = [String: Commodity]()
    private var account = [String: Account]()
    private var tag = [String: Tag]()
    private var price = [CommoditySymbol: [CommoditySymbol: [Date: Price]]]()
    private let accountGroup: [String: AccountGroup]

    var postingPrices = [Transaction: [Posting: MultiCurrencyAmount]]()

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
    /// - Parameter transaction: transaction to add
    public func add(_ transaction: Transaction) {
        transactions.append(transaction)
        transaction.metaData.tags.forEach {
            addTagIfNeccessary($0)
        }
        transaction.postings.forEach {
            addAccountIfNeccessary(name: $0.accountName)
            addCommodityIfNeccessary(symbol: $0.amount.commoditySymbol)
            if let price = $0.price {
                addCommodityIfNeccessary(symbol: price.commoditySymbol)
            }
            if let costAmount = $0.cost?.amount {
                addCommodityIfNeccessary(symbol: costAmount.commoditySymbol)
            }
        }
    }

    /// Adds an `Account` to the ledger
    ///
    /// - Parameter account: account to add
    /// - Throws: If the account already exists
    public func add(_ account: Account) throws {
        guard self.account[account.name.fullName] == nil else {
            throw LedgerError.alreadyExists(String(describing: account))
        }
        addAccountToStructure(account)
        if let commoditySymbol = account.commoditySymbol {
            addCommodityIfNeccessary(symbol: commoditySymbol)
        }
    }

    /// Adds a `Commodity` to the ledger
    ///
    /// - Parameter commodity: commodity to add
    /// - Throws: If the commodity already exists
    public func add(_ commodity: Commodity) throws {
        guard self.commodity[commodity.symbol] == nil else {
            throw LedgerError.alreadyExists(String(describing: commodity))
        }
        self.commodity[commodity.symbol] = commodity
    }

    /// Adds a `Price` to the ledger
    ///
    /// - Parameter price: `Price` to add
    /// - Throws: If the price already exists
    public func add(_ price: Price) throws {
        guard self.price[price.commoditySymbol]?[price.amount.commoditySymbol]?[price.date] == nil else {
            throw LedgerError.alreadyExists(String(describing: price))
        }
        if self.price[price.commoditySymbol] == nil {
            self.price[price.commoditySymbol] = [CommoditySymbol: [Date: Price]]()
        }
        if self.price[price.commoditySymbol]![price.amount.commoditySymbol] == nil {
            self.price[price.commoditySymbol]![price.amount.commoditySymbol] = [Date: Price]()
        }
        self.price[price.commoditySymbol]![price.amount.commoditySymbol]![price.date] = price
        addCommodityIfNeccessary(symbol: price.commoditySymbol)
    }

    /// Adds a `Balance` to the ledger
    ///
    /// - Parameter balance: `Balance` to add
    public func add(_ balance: Balance) {
        getAccount(by: balance.accountName).balances.append(balance)
        addCommodityIfNeccessary(symbol: balance.amount.commoditySymbol)
    }

    /// Validates ledger and returns all validation errors
    private func validate() -> [String] {
        var result = [String]()
        accounts.forEach {
            if case .invalid(let error) = $0.validate() {
                result.append(error)
            }
            if case .invalid(let error) = $0.validateBalance(in: self) {
                result.append(error)
            }
            if case .invalid(let error) = $0.validateInventory(in: self) {
                result.append(error)
            }
        }

        // Check for unused accounts if the nounused plugin is enabled
        if plugins.contains("beancount.plugins.nounused") {
            accounts.forEach { account in
                if !account.hasPostings(in: self) {
                    result.append("Account \(account.name) has no postings")
                }
            }
        }

        transactions.forEach {
            if case .invalid(let error) = $0.validate(in: self) {
                result.append(error)
            }
        }
        commodities.forEach {
            if case .invalid(let error) = $0.validate(in: self) {
                result.append(error)
            }
        }
        return result
    }

    /// Adds an account the the account structure in the ledger
    /// - Parameter account: account to add
    private func addAccountToStructure(_ account: Account) {
        let name = account.name.fullName
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

    /// Gets an `Account` so that all accounts exists only once in a ledger, create a new one if it doesn't exist yet
    ///
    /// - Parameters:
    ///   - accountName: accountName to get
    /// - Returns: Account from the ledger
    private func getAccount(by name: AccountName) -> Account {
        addAccountIfNeccessary(name: name)
        return self.account[name.fullName]!
    }

    /// Adds an `Account` to the structure if it does not exist yet
    ///
    /// - Parameters:
    ///   - name: accountName of the account to add
    private func addAccountIfNeccessary(name: AccountName) {
        if self.account[name.fullName] == nil {
            let account = Account(name: name)
            addAccountToStructure(account)
        }
    }

    /// Adds a `Tag` if it does not exist yet
    ///
    /// - Parameters:
    ///   - tag: Tag to add
    private func addTagIfNeccessary(_ tag: Tag) {
        if self.tag[tag.name] == nil {
            self.tag[tag.name] = tag
        }
    }

    /// Adds a `Commodity` if it does not exist yet
    ///
    /// - Parameters:
    ///   - symbol: Symbol of Commodity to add
    private func addCommodityIfNeccessary(symbol: CommoditySymbol) {
        if self.commodity[symbol] == nil {
            self.commodity[symbol] = Commodity(symbol: symbol)
        }
    }

}

extension LedgerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .alreadyExists(error):
            return "Entry already exists in Ledger: \(error)"
        }
    }
}

extension Ledger: CustomStringConvertible {

    /// Retuns the ledger file for this ledger.
    ///
    /// It consists of all `Account` and `Transaction` statements, but does not include `errors`
    public var description: String {
        var string = ""
        string.append(self.option.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !self.plugins.isEmpty {
            string.append("\n")
        }
        string.append(self.plugins.map { "plugin \"\($0)\"" }.joined(separator: "\n"))
        if !string.isEmpty && !self.custom.isEmpty {
            string.append("\n")
        }
        string.append(self.custom.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !self.events.isEmpty {
            string.append("\n")
        }
        string.append(self.events.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !self.commodities.isEmpty {
            string.append("\n")
        }
        string.append(self.commodities.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !self.accounts.isEmpty {
            string.append("\n")
        }
        string.append(self.accounts.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !self.transactions.isEmpty {
            string.append("\n")
        }
        string.append(self.transactions.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !self.prices.isEmpty {
            string.append("\n")
        }
        string.append(self.prices.sorted { $0.date < $1.date }.map { String(describing: $0) }.joined(separator: "\n"))
        return string
    }

}

extension Ledger: Equatable {

    /// Compares two Ledgers
    ///
    /// Compared are the `Account`s, `Transaction`s, `Commodity`s, `Tag`s, `Event`s, `Custom`s, as well `option`s and `plugins`, but not the `errors`
    ///
    /// - Parameters:
    ///   - lhs: ledger one
    ///   - rhs: ledger two
    /// - Returns: true if they hold the same information, otherwise false
    public static func == (lhs: Ledger, rhs: Ledger) -> Bool {
        lhs.account == rhs.account
            && rhs.commodity == lhs.commodity
            && rhs.tag == lhs.tag
            && rhs.transactions.sorted() == lhs.transactions.sorted()
            && rhs.price == lhs.price
            && rhs.custom.sorted() == lhs.custom.sorted()
            && rhs.option.sorted() == lhs.option.sorted()
            && rhs.events.sorted() == lhs.events.sorted()
            && rhs.plugins.sorted() == lhs.plugins.sorted()
    }

}
