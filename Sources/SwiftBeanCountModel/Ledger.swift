//
//  Ledger.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// Errors which can occur when working with the ledger
public enum LedgerError: Error, Equatable {
    /// Error if the object your try to add already exists in the ledger
    case alreadyExists(String)
}

/// An immutable, completed view of a ledger.
public final class Ledger {
    /// Array of all `Transaction`s in this ledger
    public let transactions: [Transaction]

    /// Errors from the ledger and the parsing
    public let errors: [String]

    /// Errors which this ledger contains
    public let ledgerErrors: [String]

    /// Errors while reading the ledger
    public let parsingErrors: [String]

    /// Array of all `Commodity`s in this ledger
    public let commodities: [Commodity]

    /// Array of all `Account`s in this ledger
    public let accounts: [Account]

    /// Array of all `Tag`s in this ledger
    public let tags: [Tag]

    /// Array of all `Price`s in this ledger
    public let prices: [Price]

    /// Array of the main `AccountGroup`s in this ledger
    public let accountGroups: [AccountGroup]

    /// Array of all plugins
    public let plugins: [String]

    /// Array of all options
    public let option: [Option]

    /// Array of all events
    public let events: [Event]

    /// Array of all Custom directives
    public let custom: [Custom]

    let postingPrices: [Transaction: [Posting: MultiCurrencyAmount]]

    init(builder: LedgerBuilder) {
        transactions = builder.storedTransactions
        parsingErrors = builder.parsingErrors
        plugins = builder.plugins
        option = builder.option
        events = builder.events
        custom = builder.custom

        let accountCopies = Self.copyAccounts(builder.account.values)
        accounts = Array(accountCopies.values)
        commodities = Array(builder.commodity.values)
        tags = Array(builder.tag.values)
        prices = builder.price.values.flatMap { $0.values.flatMap(\.values) }
        accountGroups = Self.copyGroups(builder.accountGroup, accounts: accountCopies)
        postingPrices = [:]

        ledgerErrors = []
        errors = []
    }

    init(
        copying ledger: Ledger,
        postingPrices: [Transaction: [Posting: MultiCurrencyAmount]],
        ledgerErrors: [String]
    ) {
        transactions = ledger.transactions
        parsingErrors = ledger.parsingErrors
        plugins = ledger.plugins
        option = ledger.option
        events = ledger.events
        custom = ledger.custom
        accounts = ledger.accounts
        commodities = ledger.commodities
        tags = ledger.tags
        prices = ledger.prices
        accountGroups = ledger.accountGroups
        self.postingPrices = postingPrices
        self.ledgerErrors = ledgerErrors
        errors = parsingErrors + ledgerErrors
    }

    /// Creates an empty immutable ledger with its account groups set up.
    public convenience init() {
        self.init(builder: LedgerBuilder())
    }

    private static func copyAccounts(_ accounts: Dictionary<String, Account>.Values) -> [String: Account] {
        Dictionary(uniqueKeysWithValues: accounts.map { account in
            let copy = Account(
                name: account.name,
                bookingMethod: account.bookingMethod,
                commoditySymbol: account.commoditySymbol,
                opening: account.opening,
                closing: account.closing,
                metaData: account.metaData
            )
            copy.balances = account.balances
            return (account.name.fullName, copy)
        })
    }

    private static func copyGroups(_ source: [String: AccountGroup], accounts: [String: Account]) -> [AccountGroup] {
        func copy(_ group: AccountGroup) -> AccountGroup {
            let result = AccountGroup(nameItem: group.nameItem, accountType: group.accountType, baseGroup: group.baseGroup)
            for (name, account) in group.accounts {
                result.accounts[name] = accounts[account.name.fullName]
            }
            for (name, child) in group.accountGroups {
                result.accountGroups[name] = copy(child)
            }
            return result
        }
        return source.values.map(copy)
    }

    func finalizeAccounting() -> Ledger {
        var weights = [Transaction: [Posting: MultiCurrencyAmount]]()
        for account in accounts {
            let (_, accountWeights) = account.inventoryBooking(in: self)
            for (posting, amount) in accountWeights {
                weights[posting.transaction, default: [:]][posting] = amount
            }
        }
        let intermediate = Ledger(copying: self, postingPrices: weights, ledgerErrors: [])
        let errors = intermediate.validate()
        return Ledger(copying: intermediate, postingPrices: weights, ledgerErrors: errors)
    }

}

extension Ledger {
    func validate() -> [String] {
        var result = [String]()
        result.append(contentsOf: validateAccounts())
        result.append(contentsOf: validateTransactions())
        result.append(contentsOf: validateCommodities())
        result.append(contentsOf: validatePrices())
        result.append(contentsOf: validateBalanceAssertions())
        return result
    }

    /// Validates all accounts
    func validateAccounts() -> [String] {
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
        return result
    }

    /// Validates all transactions
    func validateTransactions() -> [String] {
        var result = [String]()
        transactions.forEach {
            if case .invalid(let error) = $0.validate(in: self) {
                result.append(error)
            }
        }
        return result
    }

    /// Validates all commodities
    func validateCommodities() -> [String] {
        var result = [String]()
        commodities.forEach {
            if case .invalid(let error) = $0.validate(in: self) {
                result.append(error)
            }
        }
        return result
    }

    /// Validates all prices
    func validatePrices() -> [String] {
        var result = [String]()
        prices.forEach {
            if case .invalid(let error) = $0.validate(in: self) {
                result.append(error)
            }
        }
        return result
    }

    /// Validates all balance assertions
    func validateBalanceAssertions() -> [String] {
        var result = [String]()
        accounts.forEach { account in
            account.balances.forEach { balance in
                if case .invalid(let error) = balance.validate(in: self) {
                    result.append(error)
                }
            }
        }
        return result
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
        string.append(option.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !plugins.isEmpty {
            string.append("\n")
        }
        string.append(plugins.map { "plugin \"\($0)\"" }.joined(separator: "\n"))
        if !string.isEmpty && !custom.isEmpty {
            string.append("\n")
        }
        string.append(custom.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !events.isEmpty {
            string.append("\n")
        }
        string.append(events.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !commodities.isEmpty {
            string.append("\n")
        }
        string.append(commodities.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !accounts.isEmpty {
            string.append("\n")
        }
        string.append(accounts.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !transactions.isEmpty {
            string.append("\n")
        }
        string.append(transactions.map { String(describing: $0) }.joined(separator: "\n"))
        if !string.isEmpty && !prices.isEmpty {
            string.append("\n")
        }
        string.append(prices.sorted { $0.date < $1.date }.map { String(describing: $0) }.joined(separator: "\n"))
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
        lhs.accounts.sorted { $0.name.fullName < $1.name.fullName } == rhs.accounts.sorted { $0.name.fullName < $1.name.fullName }
            && lhs.commodities.sorted { $0.symbol < $1.symbol } == rhs.commodities.sorted { $0.symbol < $1.symbol }
            && lhs.tags.sorted { $0.name < $1.name } == rhs.tags.sorted { $0.name < $1.name }
            && rhs.transactions.sorted() == lhs.transactions.sorted()
            && lhs.prices.sorted(by: Self.priceSort) == rhs.prices.sorted(by: Self.priceSort)
            && rhs.custom.sorted() == lhs.custom.sorted()
            && rhs.option.sorted() == lhs.option.sorted()
            && rhs.events.sorted() == lhs.events.sorted()
            && rhs.plugins.sorted() == lhs.plugins.sorted()
    }

    private static func priceSort(_ lhs: Price, _ rhs: Price) -> Bool {
        if lhs.commoditySymbol != rhs.commoditySymbol {
            return lhs.commoditySymbol < rhs.commoditySymbol
        }
        if lhs.amount.commoditySymbol != rhs.amount.commoditySymbol {
            return lhs.amount.commoditySymbol < rhs.amount.commoditySymbol
        }
        return lhs.date < rhs.date
    }

}
