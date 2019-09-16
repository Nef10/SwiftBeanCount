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

    /// Parses a given file into a Ledger
    ///
    /// - Parameter contentOf: URL to parse Encoding has to be UTF-8
    /// - Returns: Ledger with parsed content
    /// - Throws: Exceptions from opening the file
    public static func parse(contentOf path: URL) throws -> Ledger {
        let text = try String(contentsOf: path)
        return self.parse(string: text)
    }

    /// Parses a given String into a Ledger
    ///
    /// - Parameter string: String to parse
    /// - Returns: Ledger with parsed content
    public static func parse(string: String) -> Ledger {

        let ledger = Ledger()

        let lines = string.components(separatedBy: .newlines)

        var openTransaction: Transaction?

        for (lineNumber, line) in lines.enumerated() {
            openTransaction = parse(line, number: lineNumber, into: ledger, openTransaction: openTransaction)
        }

        closeOpen(transaction: openTransaction, inLedger: ledger, onLine: lines.count)

        ledger.validate()

        return ledger
    }

    /// Parses a single line
    ///
    /// - Parameters:
    ///   - line: string of the line
    ///   - lineNumber: number of the line for error messages
    ///   - ledger: ledger where result will be saved into
    ///   - openTransaction: currently open transaction from last line
    /// - Returns: new open transaction or nil if no transaction open
    private static func parse(_ line: String, number lineNumber: Int, into ledger: Ledger, openTransaction: Transaction?) -> Transaction? {
        if line.isEmpty || line[line.startIndex] == Parser.comment {
            // Ignore empty lines and comments
            return openTransaction
        }

        // Posting
        if let transaction = openTransaction {
            do {
                if let posting = try PostingParser.parseFrom(line: line, into: transaction) {
                    transaction.postings.append(posting)
                    return transaction
                } else { // No posting, need to close previous transaction
                    closeOpen(transaction: openTransaction, inLedger: ledger, onLine: lineNumber + 1)
                }
            } catch {
                ledger.errors.append("\(error.localizedDescription) (line \(lineNumber + 1))")
                return nil
            }
        }

        // Transaction
        if let transactionMetaData = TransactionMetaDataParser.parseFrom(line: line) {
            return Transaction(metaData: transactionMetaData)
        }

        // Account
        if let account = AccountParser.parseFrom(line: line) {
            add(account, to: ledger, line: line, lineNumber: lineNumber)
            return nil
        }

        // Price
        if let price = PriceParser.parseFrom(line: line) {
            add(price, to: ledger, lineNumber: lineNumber)
            return nil
        }

        // Commodity
        if let commodity = CommodityParser.parseFrom(line: line) {
            add(commodity, to: ledger, lineNumber: lineNumber)
            return nil
        }

        // Balance
        if let balance = BalanceParser.parseFrom(line: line) {
            add(balance, to: ledger, lineNumber: lineNumber)
            return nil
        }

        ledger.errors.append("Invalid format in line \(lineNumber + 1): \(line)")
        return nil
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

    /// Tries to add a commodity to the ledger
    ///
    /// Adds an error to the ledger if the commodity cannot be added
    ///
    /// - Parameters:
    ///   - commodity: commodity to add
    ///   - ledger: ledger to add the commodity into
    ///   - lineNumber: line number which should be included in the error if the commodity cannot be added
    private static func add(_ commodity: Commodity, to ledger: Ledger, lineNumber: Int) {
        do {
            try ledger.add(commodity)
        } catch let error {
            ledger.errors.append("Error with commodity \(commodity): \(error.localizedDescription) in line \(lineNumber + 1)")
        }
    }

    /// Tries to add a balance to the ledger
    ///
    /// Adds an error to the ledger if the balance cannot be added
    ///
    /// - Parameters:
    ///   - balance: balance to add
    ///   - ledger: ledger to add the balance into
    ///   - lineNumber: line number which should be included in the error if the balance cannot be added
    private static func add(_ balance: Balance, to ledger: Ledger, lineNumber: Int) {
        do {
            try ledger.add(balance)
        } catch let error {
            ledger.errors.append("Error with balance \(balance): \(error.localizedDescription) in line \(lineNumber + 1)")
        }
    }

}
