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
        var lineNumber = 0

        while lineNumber < lines.count {
            let line = lines[lineNumber]
            if line.isEmpty || line[line.startIndex] == Parser.comment {
                // Ignore empty lines and comments
                lineNumber += 1
                continue
            }
            var metaData = [String: String]()
            while lineNumber < lines.count - 1, let metaDataParsed = MetaDataParser.parseFrom(line: lines[lineNumber + 1]) {
                metaData = metaData.merging(metaDataParsed) { _, new in new }
                lineNumber += 1
            }
            openTransaction = parse(line, number: lineNumber, metaData: metaData)
            lineNumber += 1
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
    private func parse(_ line: String, number lineNumber: Int, metaData: [String: String]) -> Transaction? {

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
        if let account = AccountParser.parseFrom(line: line) {
            accounts.append((lineNumber, line, account))
            return nil
        }

        // Price
        if let price = PriceParser.parseFrom(line: line) {
            prices.append((lineNumber, price))
            return nil
        }

        // Commodity
        if let commodity = CommodityParser.parseFrom(line: line) {
            commodities.append((lineNumber, commodity))
            return nil
        }

        // Balance
        if let balance = BalanceParser.parseFrom(line: line) {
            balances.append((lineNumber, balance))
            return nil
        }

        // Option
        if let option = OptionParser.parseFrom(line: line) {
            ledger.option.append(option)
            return nil
        }

        // Plugin
        if let plugin = PluginParser.parseFrom(line: line) {
            ledger.plugins.append(plugin)
            return nil
        }

        // Event
        if let event = EventParser.parseFrom(line: line) {
            ledger.events.append(event)
            return nil
        }

        // Custom
        if let custom = CustomsParser.parseFrom(line: line) {
            ledger.custom.append(custom)
            return nil
        }

        return addParsingError(lineNumber: lineNumber, line: line)
    }

    private func addParsingError(lineNumber: Int, line: String) -> Transaction? {
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

}
