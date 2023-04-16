//
//  Transaction.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// A Transaction has meta data as well as multiple postings
public class Transaction {

    /// Meta data of the Transaction
    public let metaData: TransactionMetaData

    /// Arrary of the `Posting`s of the transaction.
    ///
    /// Should at least have two elements, otherwise the Transaction is not valid
    public var postings: [TransactionPosting] {
        internalPostings
    }

    // can only be set in the init, but must not be let because otherwise not all required lets are set in init
    // before calling out to create the TransactionPostings
    private var internalPostings = [TransactionPosting]()

    /// Creates a transaction
    ///
    /// - Parameters:
    ///   - metaData: `TransactionMetaData`
    ///   - postings: `Postings`
    public init(metaData: TransactionMetaData, postings: [Posting]) {
        self.metaData = metaData
        self.internalPostings = postings.map { TransactionPosting(posting: $0, transaction: self) }
    }

    func validate(in ledger: Ledger) -> ValidationResult {
        guard !postings.isEmpty else {
            return .invalid("\(self) has no postings")
        }
        let balanced = validateBalance(in: ledger)
        guard case .valid = balanced else {
            return balanced
        }
        for posting in postings {
            guard let account = ledger.accounts.first(where: { $0.name == posting.accountName }) else {
                return .invalid("Account \(posting.accountName) does not exist in the ledger")
            }
            let validationResult = account.validate(posting)
            guard case .valid = validationResult else {
                return validationResult
            }
        }
        return .valid
    }

    /// Gets the balance of a transaction, should be zero (within tolerance)
    ///
    /// This method just adds up the balances of the individual postings
    ///
    /// - Parameter ledger: ledger to calculate in
    /// - Throws: if the balances cannot be calculated
    /// - Returns: MultiCurrencyAmount
    public func balance(in ledger: Ledger) throws -> MultiCurrencyAmount {
        try postings.map { try $0.balance(in: ledger) }.reduce(MultiCurrencyAmount(), +)
    }

    /// Returns the effect (income + expenses) a transaction has
    ///
    /// This methods adds up the amount of all postings from income and expense accounts in the transaction
    ///
    /// - Parameter ledger: ledger to calculate in
    /// - Throws: if the effect cannot be calculated
    /// - Returns: MultiCurrencyAmount
    public func effect(in ledger: Ledger) throws -> MultiCurrencyAmount {
        try postings.compactMap {
            ($0.accountName.accountType == .income || $0.accountName.accountType == .expense) ? try $0.balance(in: ledger) : nil
        }
        .reduce(MultiCurrencyAmount(), +)
    }

    /// Checks if a Transaction is balanced within the allowed Tolerance
    ///
    /// **Tolerance**: If multiple postings are in the same currency the percision of the number with the best precision is used
    ///  *Note*: Price and cost values are ignored
    ///  *Note*: Tolerance for interger amounts is zero
    ///
    /// - Parameter ledger: ledger to calculate in
    /// - Returns: `ValidationResult`
    private func validateBalance(in ledger: Ledger) -> ValidationResult {
        let amount: MultiCurrencyAmount
        do {
            amount = try balance(in: ledger)
        } catch {
            return .invalid(error.localizedDescription)
        }
        let validation = amount.validateZeroWithTolerance()
        if case .invalid(let error) = validation {
            return .invalid("\(self) is not balanced - \(error)")
        }
        return validation
    }

}

extension Transaction: CustomStringConvertible {

    /// the `String` representation of this transaction for the ledger file
    public var description: String {
        var string = String(describing: metaData)
        postings.forEach { string += "\n\(String(describing: $0))" }
        return string
    }

}

extension Transaction: Equatable {

    /// Checks if two transactions are the same
    ///
    /// This means the `metaData` and all `postings` must be the same
    ///
    /// - Parameters:
    ///   - lhs: first transaction
    ///   - rhs: second transaction
    /// - Returns: if they are the same
    public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.metaData == rhs.metaData && lhs.postings == rhs.postings
    }

}

extension Transaction: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(metaData)
        hasher.combine(postings)
    }

}

extension Transaction: Comparable {

    public static func < (lhs: Transaction, rhs: Transaction) -> Bool {
        String(describing: lhs) < String(describing: rhs)
    }

}
