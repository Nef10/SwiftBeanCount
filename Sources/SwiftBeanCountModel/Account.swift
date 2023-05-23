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
    public static func allValues() -> [Self] {
        [.asset, .liability, .income, .expense, .equity]
    }
}

/// AccountItems have a name item, which is the last part of the name
public protocol AccountItem {

    /// Last part of the name, for **Assets:Cash:CAD** this would be **CAD**
    var nameItem: String { get }

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

/// Class with represents an Account with a name, CommoditySymbol, opening and closing date
///
/// It does hot hold any `Transaction`s
public class Account: AccountItem {

    static let nameSeperator = Character(":")

    /// Name of the account
    public let name: AccountName

    /// `BookingMethod` of the account
    public let bookingMethod: BookingMethod

    /// `Commodity` of this account
    public let commoditySymbol: CommoditySymbol?

    /// MetaData of the Account
    public let metaData: [String: String]

    /// Optional date of opening.
    /// If it exists `isPostingValid(:)` checks that the transaction is on or after this date
    public let opening: Date?

    /// Optional closing date.
    /// If it exists `isPostingValid(:)` checks that the transaction is before or on this date
    public let closing: Date?

    /// Balance asserts for this account
    public internal(set) var balances = [Balance]()

    public var nameItem: String { name.nameItem }

    /// Creates an Account
    ///
    /// - Parameters:
    ///   - name: a vaild name for the account
    ///   - bookingMethod: bookingMethods, defaults to .strict
    public init(
        name: AccountName,
        bookingMethod: BookingMethod = .strict,
        commoditySymbol: CommoditySymbol? = nil,
        opening: Date? = nil,
        closing: Date? = nil,
        metaData: [String: String] = [:]
    ) {
        self.name = name
        self.bookingMethod = bookingMethod
        self.commoditySymbol = commoditySymbol
        self.opening = opening
        self.closing = closing
        self.metaData = metaData
    }

    /// Checks if the given `Posting` is a valid posting for this account.
    /// This includes that the account of the posting is this one, the commodity matches and the account was open at the day of posting
    ///
    /// - Parameter posting: posting to check
    /// - Returns: `ValidationResult`
    func validate(_ posting: TransactionPosting) -> ValidationResult {
        assert(posting.accountName == self.name, "Checking Posting \(posting) on wrong Account \(self)")
        guard self.allowsPosting(in: posting.amount.commoditySymbol) else {
            return .invalid("\(posting.transaction) uses a wrong commodiy for account \(self.name) - Only \(self.commoditySymbol!) is allowed")
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
        if let closing {
            guard let opening else {
                return .invalid("Account \(self.name) has a closing date but no opening")
            }
            guard opening <= closing else {
                let closingString = Self.dateFormatter.string(from: closing)
                let openingString = Self.dateFormatter.string(from: opening)
                return .invalid("Account \(self.name) was closed on \(closingString) before it was opened on \(openingString)")
            }
        }
        return .valid
    }

    /// Checks if the balance assertions of the account are correct
    ///
    /// - Parameter ledger: ledger with the Transactions
    /// - Returns: `ValidationResult`
    func validateBalance(in ledger: Ledger) -> ValidationResult {
        var postingIterator = postings(in: ledger).makeIterator()
        var nextPosting = postingIterator.next()
        var amount = MultiCurrencyAmount(amounts: [:], decimalDigits: [:])
        for balance in balances.sorted(by: { $0.date < $1.date }) {
            while let posting = nextPosting, posting.transaction.metaData.date < balance.date {
                amount += posting.amount
                nextPosting = postingIterator.next()
            }
            let validation = amount.validateOneAmountWithTolerance(amount: balance.amount)
            if case .invalid(let error) = validation {
                return .invalid("Balance failed for \(balance) - \(error)")
            }
        }
        return .valid
    }

    /// Checks if units booked by cost have correct lots
    ///
    /// - Parameter ledger: ledger with the Transactions
    /// - Returns: `ValidationResult`
    func validateInventory(in ledger: Ledger) -> ValidationResult {
        var postingIterator = postings(in: ledger).makeIterator()
        var nextPosting = postingIterator.next()
        let inventory = Inventory(bookingMethod: bookingMethod)
        while let posting = nextPosting {
            if posting.cost != nil {
                do {
                    let pricePaid = try inventory.book(posting: posting)
                    if let pricePaid {
                        if ledger.postingPrices[posting.transaction] != nil {
                            ledger.postingPrices[posting.transaction]![posting] = pricePaid
                        } else {
                            ledger.postingPrices[posting.transaction] = [posting: pricePaid]
                        }
                    }
                } catch {
                    return .invalid(error.localizedDescription)
                }
            }
            nextPosting = postingIterator.next()
        }
        return .valid
    }

    /// Returns all posting for this account ordered by date from the oldest to the newest
    ///
    /// - Parameter ledger: leder with the transactions with the postings
    /// - Returns: all posting for this account ordered by date from the oldest to the newest
    private func postings(in ledger: Ledger) -> [TransactionPosting] {
        var postings = [TransactionPosting]()
        ledger.transactions.forEach { postings.append(contentsOf: $0.postings.filter { $0.accountName == self.name }) }
        postings.sort { $0.transaction.metaData.date < $1.transaction.metaData.date }
        return postings
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

    private func allowsPosting(in commodity: CommoditySymbol) -> Bool {
        if let ownCommoditySymbol = self.commoditySymbol {
            return ownCommoditySymbol == commodity
        }
        return true
    }

}

extension Account: CustomStringConvertible {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// Returns the Acount opening and closing string for the ledger.
    ///
    /// If no open date is set it returns an empty string, if only the opening is set the closing line is ommitted
    public var description: String {
        var string = ""
        if let opening = self.opening {
            string += "\(Self.dateFormatter.string(from: opening)) open \(name)"
            if let commoditySymbol = self.commoditySymbol {
                string += " \(commoditySymbol)"
            }
            if bookingMethod != .strict {
                string += " \"\(bookingMethod)\""
            }
            if !metaData.isEmpty {
                string += "\n\(metaData.map { "  \($0): \"\($1)\"" }.joined(separator: "\n"))"
            }
            if let closing = self.closing {
                string += "\n\(Self.dateFormatter.string(from: closing)) close \(name)"
            }
        }
        return string
    }

}

extension Account: Equatable {

    /// Compare the name, commodity and meta data as well as the opening and closing of two Accounts.
    ///
    /// This does not compare `Transaction`s as they are not part of Accounts
    ///
    /// - Returns: if the accounts are equal
    public static func == (lhs: Account, rhs: Account) -> Bool {
        rhs.name == lhs.name && rhs.commoditySymbol == lhs.commoditySymbol && rhs.opening == lhs.opening && rhs.closing == lhs.closing && lhs.metaData == rhs.metaData
    }

}
