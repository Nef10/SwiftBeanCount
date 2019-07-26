//
//  Parser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

public class Parser {

    static let comment: Character = ";"

    /// Parses a given file into an array of Transactions
    ///
    /// - Parameter contentOf: URL to parse Encoding has to be UTF-8
    /// - Returns: Array of parsed Transactions
    /// - Throws: Exceptions from opening the file
    public static func parse(contentOf path: URL) throws -> Ledger {
        let text = try String(contentsOf: path)
        return self.parse(string: text)
    }

    /// Parses a given String into an array of Transactions
    ///
    /// - Parameter string: String to parse
    /// - Returns: Array of parsed Transactions
    public static func parse(string: String) -> Ledger {

        let ledger = Ledger()

        let lines = string.components(separatedBy: .newlines)

        var openTransaction: Transaction?

        for (lineNumber, line) in lines.enumerated() {

            if line.isEmpty || line[line.startIndex] == Parser.comment {
                // Ignore empty lines and comments
                continue
            }

            // Posting
            if let transaction = openTransaction {
                if let posting = PostingParser.parseFrom(line: line, into: transaction) {
                    transaction.postings.append(posting)
                    continue
                } else { // No posting, need to close previous transaction
                    closeOpen(transaction: openTransaction, inLedger: ledger, onLine: lineNumber + 1)
                    openTransaction = nil
                }
            }

            // Transaction
            if let transactionMetaData = TransactionMetaDataParser.parseFrom(line: line) {
                openTransaction = Transaction(metaData: transactionMetaData)
                continue
            }

            // Account
            if let account = AccountParser.parseFrom(line: line) {
                add(account, to: ledger, line: line, lineNumber: lineNumber)
                continue
            }

            // Price
            if let price = PriceParser.parseFrom(line: line) {
                add(price, to: ledger, lineNumber: lineNumber)
                continue
            }

            ledger.errors.append("Invalid format in line \(lineNumber + 1): \(line)")

        }

        closeOpen(transaction: openTransaction, inLedger: ledger, onLine: lines.count)

        ledger.validate()

        return ledger
    }

    /// Tries to close an open transaction if any
    ///
    /// Adds an error to the ledger if the transaction does not have any postings
    ///
    /// - Parameters:
    ///   - openTransaction: the open transaction if any
    ///   - ledger: ledger to add the tranaction to
    ///   - line: line number which should be included in the error if the transaction cannot be closed
    private static func closeOpen(transaction openTransaction: Transaction?, inLedger ledger: Ledger, onLine line: Int) {
        if let transaction = openTransaction { // Need to close last transaction
            if !transaction.postings.isEmpty {
                _ = ledger.add(transaction)
            } else {
                ledger.errors.append("Invalid format in line \(line): previous Transaction \(transaction) without postings")
            }
        }
    }

    /// Tries to add an account to the ledger
    ///
    /// Adds an error to the ledger if the account cannot be added
    ///
    /// - Parameters:
    ///   - account: account to add
    ///   - ledger: ledger to add the account into
    ///   - line: line which should be included in the error if the account cannot be added
    ///   - lineNumber: line number which should be included in the error if the account cannot be added
    private static func add(_ account: Account, to ledger: Ledger, line: String, lineNumber: Int) {
        if let ledgerAccount = ledger.accounts.first(where: { $0.name == account.name }) {
            if account.opening != nil {
                if ledgerAccount.opening == nil {
                    ledgerAccount.opening = account.opening
                } else {
                    ledger.errors.append("Second opening for account \(account.name) in line \(lineNumber + 1): \(line)")
                    return
                }
            }
            if account.commodity != nil {
                if ledgerAccount.commodity == nil {
                    ledgerAccount.commodity = account.commodity
                } else {
                    assertionFailure("Cannot have a duplicated commodity without a duplicate opening")
                }
            }
            if account.closing != nil {
                if ledgerAccount.closing == nil {
                    ledgerAccount.closing = account.closing
                } else {
                    ledger.errors.append("Second closing for account \(account.name) in line \(lineNumber + 1): \(line)")
                }
            }
        } else {
            do {
                try ledger.add(account)
            } catch let error {
                ledger.errors.append("Error with account \(account.name): \(error.localizedDescription) in line \(lineNumber + 1): \(line)")
            }
        }
    }

    /// Tries to add a price to the ledger
    ///
    /// Adds an error to the ledger if the price cannot be added
    ///
    /// - Parameters:
    ///   - price: price to add
    ///   - ledger: ledger to add the account into
    ///   - lineNumber: line number which should be included in the error if the price cannot be added
    private static func add(_ price: Price, to ledger: Ledger, lineNumber: Int) {
        do {
            try ledger.add(price)
        } catch let error {
            ledger.errors.append("Error with price \(price): \(error.localizedDescription) in line \(lineNumber + 1)")
        }
    }

}
