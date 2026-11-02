//
//  LedgerBuilder.swift
//  SwiftBeanCountModel
//

import Foundation

/// Mutable assembly object. Call `build()` to publish a stable snapshot.
public final class LedgerBuilder {

    /// Diagnostics collected while parsing or assembling the ledger.
    public var parsingErrors = [String]()

    /// Plugins configured for this ledger.
    public var plugins = [String]()

    /// Options configured for this ledger.
    public var option = [Option]()

    /// Events included in this ledger.
    public var events = [Event]()

    /// Custom directives included in this ledger.
    public var custom = [Custom]()

    /// Transactions currently assembled by this builder.
    public var transactions: [Transaction] { storedTransactions }

    /// Commodities currently assembled by this builder.
    public var commodities: [Commodity] { Array(commodity.values) }

    /// Accounts currently assembled by this builder.
    public var accounts: [Account] { Array(account.values) }

    /// Tags currently assembled by this builder.
    public var tags: [Tag] { Array(tag.values) }

    /// Prices currently assembled by this builder.
    public var prices: [Price] { price.values.flatMap { $0.values.flatMap(\.values) } }

    /// Top-level account groups currently assembled by this builder.
    public var accountGroups: [AccountGroup] { Array(accountGroup.values) }

    var commodity = [String: Commodity]()
    var account = [String: Account]()
    var tag = [String: Tag]()
    var price = [CommoditySymbol: [CommoditySymbol: [Date: Price]]]()
    var accountGroup: [String: AccountGroup]
    var storedTransactions = [Transaction]()

    /// Creates an empty builder with five account groups; does not process a ledger.
    public init() {
        var groups = [String: AccountGroup]()
        for type in AccountType.allValues() {
            groups[type.rawValue] = AccountGroup(nameItem: type.rawValue, accountType: type, baseGroup: true)
        }
        accountGroup = groups
    }

    /// Adds a `Transaction` and creates any referenced accounts, commodities, and tags.
    /// - Parameter transaction: The transaction to add.
    public func add(_ transaction: Transaction) {
        storedTransactions.append(transaction)
        transaction.metaData.tags.forEach(addTagIfNecessary)
        transaction.postings.forEach { posting in
            addAccountIfNecessary(name: posting.accountName)
            addCommodityIfNecessary(symbol: posting.amount.commoditySymbol)
            if let price = posting.price { addCommodityIfNecessary(symbol: price.commoditySymbol) }
            if let costAmount = posting.cost?.amount { addCommodityIfNecessary(symbol: costAmount.commoditySymbol) }
        }
    }

    /// Adds an account to the builder.
    /// - Parameter account: The account to add.
    /// - Throws: `LedgerError.alreadyExists` when the account name is already present.
    public func add(_ account: Account) throws(LedgerError) {
        guard self.account[account.name.fullName] == nil else { throw .alreadyExists(String(describing: account)) }
        addAccountToStructure(account)
        if let symbol = account.commoditySymbol { addCommodityIfNecessary(symbol: symbol) }
    }

    /// Adds a commodity to the builder.
    /// - Parameter commodity: The commodity to add.
    /// - Throws: `LedgerError.alreadyExists` when the symbol is already present.
    public func add(_ commodity: Commodity) throws(LedgerError) {
        guard self.commodity[commodity.symbol] == nil else { throw .alreadyExists(String(describing: commodity)) }
        self.commodity[commodity.symbol] = commodity
    }

    /// Adds a price to the builder.
    /// - Parameter price: The price to add.
    /// - Throws: `LedgerError.alreadyExists` when a price exists for the same date and pair.
    public func add(_ price: Price) throws(LedgerError) {
        guard self.price[price.commoditySymbol]?[price.amount.commoditySymbol]?[price.date] == nil else {
            throw .alreadyExists(String(describing: price))
        }
        self.price[price.commoditySymbol, default: [:]][price.amount.commoditySymbol, default: [:]][price.date] = price
        addCommodityIfNecessary(symbol: price.commoditySymbol)
    }

    /// Adds a balance assertion, creating its account and commodity if needed.
    /// - Parameter balance: The balance assertion to add.
    public func add(_ balance: Balance) {
        getAccount(by: balance.accountName).balances.append(balance)
        addCommodityIfNecessary(symbol: balance.amount.commoditySymbol)
    }

    /// Returns a booked, validated snapshot without changing this builder.
    public func build() -> Ledger {
        Ledger.build(from: self)
    }

    private func addAccountToStructure(_ account: Account) {
        let parts = account.name.fullName.split(separator: Account.nameSeperator).map(String.init)
        var group: AccountGroup!
        for (index, part) in parts.enumerated() {
            switch index {
            case 0:
                group = accountGroup[part]
            case parts.count - 1:
                group.accounts[part] = account
            default:
                if group.accountGroups[part] == nil {
                    group.accountGroups[part] = AccountGroup(nameItem: part, accountType: group.accountType)
                }
                group = group.accountGroups[part]!
            }
        }
        self.account[account.name.fullName] = account
    }

    private func getAccount(by name: AccountName) -> Account {
        addAccountIfNecessary(name: name)
        return account[name.fullName]!
    }

    private func addAccountIfNecessary(name: AccountName) {
        if account[name.fullName] == nil { addAccountToStructure(Account(name: name)) }
    }

    private func addTagIfNecessary(_ tag: Tag) {
        if self.tag[tag.name] == nil { self.tag[tag.name] = tag }
    }

    private func addCommodityIfNecessary(symbol: CommoditySymbol) {
        if commodity[symbol] == nil { commodity[symbol] = Commodity(symbol: symbol) }
    }
}
