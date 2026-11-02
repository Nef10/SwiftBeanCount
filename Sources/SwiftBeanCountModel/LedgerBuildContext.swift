//
//  LedgerBuildContext.swift
//  SwiftBeanCountModel
//

import Foundation

/// Read-only inputs shared by accounting during construction and by completed ledgers.
protocol LedgerContext {
    var transactions: [Transaction] { get }
    var accounts: [Account] { get }
    var commodities: [Commodity] { get }
    var plugins: [String] { get }
    var postingPrices: [Transaction: [Posting: MultiCurrencyAmount]] { get }
}

/// Isolates builder contents and completes accounting before a Ledger is created.
final class LedgerBuildContext: LedgerContext {
    let transactions: [Transaction]
    let parsingErrors: [String]
    let commodities: [Commodity]
    let accounts: [Account]
    let tags: [Tag]
    let prices: [Price]
    let accountGroups: [AccountGroup]
    let plugins: [String]
    let option: [Option]
    let events: [Event]
    let custom: [Custom]
    private(set) var postingPrices = [Transaction: [Posting: MultiCurrencyAmount]]()
    private(set) var ledgerErrors = [String]()

    /// Copies builder contents, books inventory, and validates without changing the builder.
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
        bookInventory()
        ledgerErrors = validate()
    }

    private static func copyAccounts(_ accounts: Dictionary<String, Account>.Values) -> [String: Account] {
        Dictionary(uniqueKeysWithValues: accounts.map { account in
            (account.name.fullName, Account(copying: account))
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

    private func bookInventory() {
        for account in accounts {
            let (_, accountWeights) = account.inventoryBooking(in: self)
            for (posting, amount) in accountWeights {
                postingPrices[posting.transaction, default: [:]][posting] = amount
            }
        }
    }

}

extension LedgerBuildContext {
    private func validate() -> [String] {
        var result = [String]()
        result.append(contentsOf: validateAccounts())
        result.append(contentsOf: validateTransactions())
        result.append(contentsOf: validateCommodities())
        result.append(contentsOf: validatePrices())
        result.append(contentsOf: validateBalanceAssertions())
        return result
    }

    /// Validates all accounts
    private func validateAccounts() -> [String] {
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
    private func validateTransactions() -> [String] {
        var result = [String]()
        transactions.forEach {
            if case .invalid(let error) = $0.validate(in: self) {
                result.append(error)
            }
        }
        return result
    }

    /// Validates all commodities
    private func validateCommodities() -> [String] {
        var result = [String]()
        commodities.forEach {
            if case .invalid(let error) = $0.validate(in: self) {
                result.append(error)
            }
        }
        return result
    }

    /// Validates all prices
    private func validatePrices() -> [String] {
        var result = [String]()
        prices.forEach {
            if case .invalid(let error) = $0.validate(in: self) {
                result.append(error)
            }
        }
        return result
    }

    /// Validates all balance assertions
    private func validateBalanceAssertions() -> [String] {
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
