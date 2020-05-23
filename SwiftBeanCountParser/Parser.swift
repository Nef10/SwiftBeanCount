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

    private let lines: [String]
    private let ledger = Ledger()

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
        lines = string.components(separatedBy: .newlines)
    }

    /// Parses the given content into a Ledger
    ///
    /// - Returns: Ledger with parsed content
    public func parse() -> Ledger {
        parseLines()
        sortParsedData()
        importParsedData()
        return ledger
    }

    /// Parses the lines into objects, not all yet added to the ledger
    private func parseLines() {
        var lineNumber = -1

        while lineNumber < lines.count - 1 {
            lineNumber += 1
            let line = lines[lineNumber]
            if shouldSkipLine(line) {
                continue
            }
            let transactionOffset = getTransactionForLine(number: lineNumber)
            if transactionOffset == 0 {
                let (metaData, metaDataOffset) = getMetaDataForLine(number: lineNumber)
                parse(line, number: lineNumber, metaData: metaData)
                lineNumber += metaDataOffset
            }
            lineNumber += transactionOffset
        }
    }

    /// Checks if the line can be skipped because it either is empty or only contains a comment
    /// - Parameter line: string to check
    /// - Returns: if the line should be skipped
    private func shouldSkipLine(_ line: String) -> Bool {
        if line.isEmpty || line[line.startIndex] == Parser.comment {
            return true
        }
        return false
    }

    /// Returns the transaction starting in a given line
    ///
    /// This is archived by first looking for the Transaction header (TransactionMetaData) and then for postings,
    /// respecting meta data for both
    ///
    /// - Parameter lineNumber: line to check
    /// - Returns: lines parsed
    private func getTransactionForLine(number lineNumber: Int) -> Int {
        let (transactionMetaDataMetaData, transactionMetaDataMetaDataOffset) = getMetaDataForLine(number: lineNumber)
        guard let transactionMetaData = TransactionMetaDataParser.parseFrom(line: lines[lineNumber], metaData: transactionMetaDataMetaData) else {
            return 0
        }
        var postings = [Posting]()
        var offset = transactionMetaDataMetaDataOffset
        while lineNumber + offset < lines.count - 1 {
            offset += 1
            if shouldSkipLine(lines[lineNumber + offset]) {
                continue
            }
            let (metaData, metaDataOffset) = getMetaDataForLine(number: lineNumber + offset)
            do {
                if let posting = try PostingParser.parseFrom(line: lines[lineNumber + offset], metaData: metaData) {
                    postings.append(posting)
                } else {
                    offset -= 1
                    break
                }
            } catch {
                ledger.parsingErrors.append("\(error.localizedDescription) (line \(lineNumber + offset + 1))")
                break
            }
            offset += metaDataOffset
        }
        transactions.append(( lineNumber + offset + 1, LedgerTransaction(metaData: transactionMetaData, postings: postings)))
        return offset
    }

    /// Returns the metaData for a directive in the given line
    ///
    /// This is archived by starting one line after the given and parse for metadata till no more is found
    ///
    /// - Parameter lineNumber: line with the directive
    /// - Returns: metaData found and lines used
    private func getMetaDataForLine(number lineNumber: Int) -> ([String: String], Int) {
        var offset = 0
        var metaData = [String: String]()
        while lineNumber + offset < lines.count - 1 {
            offset += 1
            let line = lines[lineNumber + offset]
            if let metaDataParsed = MetaDataParser.parseFrom(line: line) {
                metaData = metaData.merging(metaDataParsed) { _, new in new }
            } else if shouldSkipLine(line) {
                continue
            } else {
                return (metaData, offset - 1)
            }
        }
        return (metaData, offset)
    }

    /// Sorts all the parsed objects which have not yet added to the ledger by date, so they can be added in order later
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

    /// Adds all the parsed objects objects which have not yet added to the ledger to it.
    /// To avoid errors the objects must be sorted by date beforehand.
    private func importParsedData() {
        // commodities do not have dependencies
        for (lineNumber, commodity) in commodities {
            do {
                try ledger.add(commodity)
            } catch {
                ledger.parsingErrors.append("Error with commodity \(commodity): \(error.localizedDescription) in line \(lineNumber + 1)")
            }
        }

        // accounts depend on commodities
        for (lineNumber, line, account) in accounts {
            addAccount(lineNumber: lineNumber, line: line, account: account)
        }

        // prices depend on commodities
        for (lineNumber, price) in prices {
            do {
                try ledger.add(price)
            } catch {
                ledger.parsingErrors.append("Error with price \(price): \(error.localizedDescription) in line \(lineNumber + 1)")
            }
        }

        // balances depend on accounts and commodities
        for (lineNumber, balance) in balances {
            do {
                try ledger.add(balance)
            } catch {
                ledger.parsingErrors.append("Error with balance \(balance): \(error.localizedDescription) in line \(lineNumber + 1)")
            }
        }

        // transactions depend on accounts and commodities
        for (_, transaction) in transactions {
            _ = ledger.add(transaction)
        }
    }

    /// Adds an account opening or closing to the ledger
    /// - Parameters:
    ///   - lineNumber: line number containing the data about the account - used to print out exact errors
    ///   - line: line containing the data about the account - used to print out exact errors
    ///   - account: the account to add
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
    private func parse(_ line: String, number lineNumber: Int, metaData: [String: String]) {

        // Account
        if let account = AccountParser.parseFrom(line: line, metaData: metaData) {
            accounts.append((lineNumber, line, account))
            return
        }

        // Price
        if let price = PriceParser.parseFrom(line: line, metaData: metaData) {
            prices.append((lineNumber, price))
            return
        }

        // Commodity
        if let commodity = CommodityParser.parseFrom(line: line, metaData: metaData) {
            commodities.append((lineNumber, commodity))
            return
        }

        // Balance
        if let balance = BalanceParser.parseFrom(line: line, metaData: metaData) {
            balances.append((lineNumber, balance))
            return
        }

        // Option
        if let option = OptionParser.parseFrom(line: line) {
            ledger.option.append(option)
            return
        }

        // Plugin
        if let plugin = PluginParser.parseFrom(line: line) {
            ledger.plugins.append(plugin)
            return
        }

        // Event
        if let event = EventParser.parseFrom(line: line, metaData: metaData) {
            ledger.events.append(event)
            return
        }

        // Custom
        if let custom = CustomsParser.parseFrom(line: line, metaData: metaData) {
            ledger.custom.append(custom)
            return
        }

        ledger.parsingErrors.append("Invalid format in line \(lineNumber + 1): \(line)")
    }

}
