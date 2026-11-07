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
public final class Ledger: LedgerContext {
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

    let postingIdentities: Set<ObjectIdentifier>
    let processedState: ProcessedLedgerState?
    let postingPrices: [Transaction: [Posting: MultiCurrencyAmount]]

    /// Installs completed accounting results; does not copy or process builder contents.
    private init(completed context: LedgerBuildContext) {
        transactions = context.transactions
        parsingErrors = context.parsingErrors
        plugins = context.plugins
        option = context.option
        events = context.events
        custom = context.custom
        accounts = context.accounts
        commodities = context.commodities
        tags = context.tags
        prices = context.prices
        accountGroups = context.accountGroups
        postingIdentities = Set(transactions.flatMap(\.postings).map(ObjectIdentifier.init))
        processedState = context.processedState
        postingPrices = context.postingPrices
        ledgerErrors = context.ledgerErrors
        errors = parsingErrors + ledgerErrors
    }

    /// Creates a completed empty ledger with the five account groups.
    public convenience init() {
        self.init(completed: LedgerBuildContext(builder: LedgerBuilder()))
    }

    /// Completes accounting on isolated builder contents, then creates the snapshot once.
    static func build(from builder: LedgerBuilder, processed projection: ProcessedLedgerProjection? = nil) -> Ledger {
        Ledger(completed: LedgerBuildContext(builder: builder, processed: projection))
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
        #if RustLedger
        if let source = retainedSourceDescription {
            return source
        }
        #endif
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
