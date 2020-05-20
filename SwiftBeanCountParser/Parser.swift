//
//  Parser.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

/// Parser to parse a string of a file into a Ledger
public class Parser {

    static let comment: Character = ";"

    private let string: String
    private let ledger = Ledger()

    private var openTransaction: Transaction?

    private var accounts = [(Int, String, Account)]()
    private var transactions = [(Int, Transaction)]()
    private var balances = [(Int, Balance)]()
    private var commodities = [(Int, Commodity)]()
    private var prices = [(Int, Price)]()

    /// Creates a parser for a file
    ///
    /// - Parameter contentOf: URL to parse (Encoding has to be UTF-8)
    /// - Throws: Exceptions from opening the file
    public convenience init(url: URL) throws {
        let text = try String(contentsOf: url)
        self.init(string: text)
    }

    /// Creates a parser for a string
    ///
    /// - Parameter string: String to parse
    public init(string: String) {
        self.string = string
    }

    /// Parses the given content into a Ledger
    ///
    /// - Returns: Ledger with parsed content
    public func parse() -> Ledger {

        let lines = string.components(separatedBy: .newlines)

        for (lineNumber, line) in lines.enumerated() {
            if line.isEmpty || line[line.startIndex] == Parser.comment {
                // Ignore empty lines and comments
                continue
            }
            openTransaction = parse(line, number: lineNumber)
        }

        closeOpenTransaction(onLine: lines.count)
        sortParsedData()
        importParsedData()

        return ledger

    }

    private func sortParsedData() {
        accounts.sort {
            let (_, _, account1) = $0
            let (_, _, account2) = $1
            let date1 = account1.opening != nil ? account1.opening : account1.closing
            let date2 = account2.opening != nil ? account2.opening : account2.closing
            return date1! < date2!
        }

        transactions.sort {
            let (_, transaction1) = $0
            let (_, transaction2) = $1
            return transaction1.metaData.date < transaction2.metaData.date
        }

        balances.sort {
            let (_, balance1) = $0
            let (_, balance2) = $1
            return balance1.date < balance2.date
        }

        commodities.sort {
            let (_, commodity1) = $0
            let (_, commodity2) = $1
            return commodity1.opening! < commodity2.opening!
        }

        prices.sort {
            let (_, price1) = $0
            let (_, price2) = $1
            return price1.date < price2.date
        }
    }

    private func importParsedData() {
        for (lineNumber, commodity) in commodities {
            do {
                try ledger.add(commodity)
            } catch {
                ledger.parsingErrors.append("Error with commodity \(commodity): \(error.localizedDescription) in line \(lineNumber + 1)")
            }
        }
        for (lineNumber, line, account) in accounts {
            addAccount(lineNumber: lineNumber, line: line, account: account)
        }
        for (lineNumber, price) in prices {
            do {
                try ledger.add(price)
            } catch {
                ledger.parsingErrors.append("Error with price \(price): \(error.localizedDescription) in line \(lineNumber + 1)")
            }
        }
        for (lineNumber, balance) in balances {
            do {
                try ledger.add(balance)
            } catch {
                ledger.parsingErrors.append("Error with balance \(balance): \(error.localizedDescription) in line \(lineNumber + 1)")
            }
        }
        for (_, transaction) in transactions {
            _ = ledger.add(transaction)
        }
    }

    private func addAccount(lineNumber: Int, line: String, account: Account) {
        if let ledgerAccount = ledger.accounts.first(where: { $0.name == account.name }) {
            if account.closing != nil {
                if ledgerAccount.closing == nil {
                    ledgerAccount.closing = account.closing
                } else {
                    ledger.parsingErrors.append("Second closing for account \(account.name) in line \(lineNumber + 1): \(line)")
                }
            } else {
                ledger.parsingErrors.append("Second open for account \(account.name) in line \(lineNumber + 1): \(line)")
            }
        } else {
            do {
                try ledger.add(account)
            } catch {
                ledger.parsingErrors.append("Error with account \(account.name): \(error.localizedDescription) in line \(lineNumber + 1): \(line)")
            }
        }
    }

    /// Parses a single line
    ///
    /// - Parameters:
    ///   - line: string of the line
    ///   - lineNumber: number of the line for error messages
    /// - Returns: new open transaction or nil if no transaction open
    private func parse(_ line: String, number lineNumber: Int) -> Transaction? {

        // Posting
        let (shouldReturn, returnValue) = parsePosting(from: line, lineNumber: lineNumber, openTransaction: openTransaction)
        if shouldReturn {
            return returnValue
        }

        // Transaction
        if let transactionMetaData = TransactionMetaDataParser.parseFrom(line: line) {
            return Transaction(metaData: transactionMetaData)
        }

        // Account
        if parseAccount(from: line, lineNumber: lineNumber) {
            return nil
        }

        // Price
        if parsePrice(from: line, lineNumber: lineNumber) {
            return nil
        }

        // Commodity
        if parseCommodity(from: line, lineNumber: lineNumber) {
            return nil
        }

        // Balance
        if parseBalance(from: line, lineNumber: lineNumber) {
            return nil
        }

        // Option
        if parseOption(from: line) {
            return nil
        }

        // Plugin
        if parsePlugin(from: line) {
            return nil
        }

        // Event
        if parseEvent(from: line) {
            return nil
        }

        // Custom
        if parseCustom(from: line) {
            return nil
        }

        ledger.parsingErrors.append("Invalid format in line \(lineNumber + 1): \(line)")
        return nil
    }

    /// Tries to close an open transaction if any
    ///
    /// Adds an error to the ledger if the transaction does not have any postings
    ///
    /// - Parameters:
    ///   - line: line number which should be included in the error if the transaction cannot be closed
    private func closeOpenTransaction(onLine line: Int) {
        if let transaction = openTransaction {
            if !transaction.postings.isEmpty {
                transactions.append((line, transaction))
            } else {
                ledger.parsingErrors.append("Invalid format in line \(line): previous Transaction \(transaction) without postings")
            }
        }
    }

    /// Tries to parse a posting from a line and add it to the open transaction
    ///
    /// Adds an error to the ledger if the posting cannot be added
    /// If the is no posting in the line it closes the open transcation
    ///
    /// - Parameters:
    ///   - line: line to parse from
    ///   - lineNumber: line number which should be included in the error if the transaction cannot be added
    ///   - openTransaction: transaction which is still open
    /// - Returns: a tuple out of bool and an optional transaction. The boolean indicaties if the line was handled. The optional tansaction is the new open transaction.
    private func parsePosting(from line: String, lineNumber: Int, openTransaction: Transaction?) -> (Bool, Transaction?) {
        if let transaction = openTransaction {
           do {
               if let posting = try PostingParser.parseFrom(line: line) {
                   transaction.add(posting)
                   return (true, transaction)
               } else { // No posting, need to close previous transaction
                   closeOpenTransaction(onLine: lineNumber + 1)
               }
           } catch {
               ledger.parsingErrors.append("\(error.localizedDescription) (line \(lineNumber + 1))")
               return (true, nil)
           }
        }
        return (false, nil)
    }

    /// Tries to parse an account from a line and add it to the ledger
    ///
    /// Adds an error to the ledger if the account cannot be added
    ///
    /// - Parameters:
    ///   - line: line to parse from
    ///   - lineNumber: line number which should be included in the error if the account cannot be added
    /// - Returns: true if there was an account in the line (even if it could not be added to the ledger), false otherwise
    private func parseAccount(from line: String, lineNumber: Int) -> Bool {
        guard let account = AccountParser.parseFrom(line: line) else {
            return false
        }
        accounts.append((lineNumber, line, account))
        return true
    }

    /// Tries to parse a price from a line and add it to the ledger
    ///
    /// Adds an error to the ledger if the price cannot be added
    ///
    /// - Parameters:
    ///   - line: line to parse from
    ///   - lineNumber: line number which should be included in the error if the price cannot be added
    /// - Returns: true if there was a price in the line (even if it could not be added to the ledger), false otherwise
    private func parsePrice(from line: String, lineNumber: Int) -> Bool {
        guard let price = PriceParser.parseFrom(line: line) else {
            return false
        }
        prices.append((lineNumber, price))
        return true
    }

    /// Tries to parse a commodity from a line and add it to the ledger
    ///
    /// Adds an error to the ledger if the commodity cannot be added
    ///
    /// - Parameters:
    ///   - line: line to parse from
    ///   - lineNumber: line number which should be included in the error if the commodity cannot be added
    /// - Returns: true if there was a commodity in the line (even if it could not be added to the ledger), false otherwise
    private func parseCommodity(from line: String, lineNumber: Int) -> Bool {
        guard let commodity = CommodityParser.parseFrom(line: line) else {
            return false
        }
        commodities.append((lineNumber, commodity))
        return true
    }

    /// Tries to parse a balance from a line and add it to the ledger
    ///
    /// Adds an error to the ledger if the balance cannot be added
    ///
    /// - Parameters:
    ///   - line: line to parse
    ///   - lineNumber: line number which should be included in the error if the balance cannot be added
    /// - Returns: true if there was a balance in the line (even if it could not be added to the ledger), false otherwise
    private func parseBalance(from line: String, lineNumber: Int) -> Bool {
        guard let balance = BalanceParser.parseFrom(line: line) else {
            return false
        }
        balances.append((lineNumber, balance))
        return true
    }

    /// Tries to parse an option from a line and add it to the ledger
    ///
    /// - Parameters:
    ///   - line: line to parse
    /// - Returns: true if there was a option in the line (even if it could not be added to the ledger), false otherwise
    private func parseOption(from line: String) -> Bool {
        guard let option = OptionParser.parseFrom(line: line) else {
            return false
        }
        ledger.option.append(option)
        return true
    }

    /// Tries to parse a plugin from a line and add it to the ledger
    ///
    /// - Parameters:
    ///   - line: line to parse
    /// - Returns: true if there was a plugin in the line (even if it could not be added to the ledger), false otherwise
    private func parsePlugin(from line: String) -> Bool {
        if let plugin = PluginParser.parseFrom(line: line) {
            ledger.plugins.append(plugin)
            return true
        }
        return false
    }

    /// Tries to parse an event from a line and add it to the ledger
    ///
    /// - Parameters:
    ///   - line: line to parse
    /// - Returns: true if there was a event in the line, false otherwise
    private func parseEvent(from line: String) -> Bool {
        if let event = EventParser.parseFrom(line: line) {
            ledger.events.append(event)
            return true
        }
        return false
    }

    /// Tries to parse a custom directive from a line and add it to the ledger
    ///
    /// - Parameters:
    ///   - line: line to parse
    /// - Returns: true if there was a custom directive in the line, false otherwise
    private func parseCustom(from line: String) -> Bool {
        if let event = CustomsParser.parseFrom(line: line) {
            ledger.custom.append(event)
            return true
        }
        return false
    }

}
