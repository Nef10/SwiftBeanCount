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
public enum Parser {

    class ParsingResult {
        var accounts = [(Int, String, Account)]()
        var transactions = [(Int, Transaction)]()
        var balances = [(Int, Balance)]()
        var commodities = [(Int, Commodity)]()
        var prices = [(Int, Price)]()
        var options = [Option]()
        var events = [Event]()
        var plugins = [String]()
        var customs = [Custom]()
        var parsingErrors = [String]()
    }

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
        let lines = string.components(separatedBy: .newlines)
        let result = parse(lines: lines)
        sortParsedData(result)
        return importParsedData(result)
    }

    /// Parses the lines into objects, not added to the ledger
    /// - Parameter lines: lines to parse
    /// - Returns: ParsingResult with the parsed data as well as error
    private static func parse(lines: [String]) -> ParsingResult {
        let result = ParsingResult()
        var lineIndex = -1

        while lineIndex < lines.count - 1 {
            lineIndex += 1
            let line = lines[lineIndex]
            if shouldSkipLine(line) {
                continue
            }
            let transactionOffset = parseTransaction(at: lineIndex, in: lines, into: result)
            if transactionOffset == 0 {
                let (metaData, metaDataOffset) = getMetaDataForLine(at: lineIndex, in: lines)
                parse(line, index: lineIndex, metaData: metaData, into: result)
                lineIndex += metaDataOffset
            }
            lineIndex += transactionOffset
        }
        return result
    }

    /// Checks if the line can be skipped because it either is empty or only contains a comment
    /// - Parameter line: string to check
    /// - Returns: if the line should be skipped
    private static func shouldSkipLine(_ line: String) -> Bool {
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
    /// - Parameter lineIndex: line to check
    /// - Parameter lines: all lines which are to be parsed
    /// - Parameter result: ParsingResult into which the results should be writter
    /// - Returns: number of lines parsed, which need to be skipped for the next parsing
    private static func parseTransaction(at lineIndex: Int, in lines: [String], into result: ParsingResult) -> Int {
        let (transactionMetaDataMetaData, transactionMetaDataMetaDataOffset) = getMetaDataForLine(at: lineIndex, in: lines)
        guard let transactionMetaData = TransactionMetaDataParser.parseFrom(line: lines[lineIndex], metaData: transactionMetaDataMetaData) else {
            return 0
        }
        var postings = [Posting]()
        var offset = transactionMetaDataMetaDataOffset
        while lineIndex + offset < lines.count - 1 {
            offset += 1
            if shouldSkipLine(lines[lineIndex + offset]) {
                continue
            }
            let (metaData, metaDataOffset) = getMetaDataForLine(at: lineIndex + offset, in: lines)
            do {
                if let posting = try PostingParser.parseFrom(line: lines[lineIndex + offset], metaData: metaData) {
                    postings.append(posting)
                } else {
                    offset -= 1
                    break
                }
            } catch {
                result.parsingErrors.append("\(error.localizedDescription) (line \(lineIndex + offset + 1))")
                break
            }
            offset += metaDataOffset
        }
        result.transactions.append(( lineIndex + offset + 1, LedgerTransaction(metaData: transactionMetaData, postings: postings)))
        return offset
    }

    /// Returns the metaData for a directive in the given line
    ///
    /// This is archived by starting one line after the given and parse for metadata till no more is found
    ///
    /// - Parameter lineIndex: line with the directive
    /// - Parameter lines: all lines which are to be parsed
    /// - Returns: metaData found and lines used
    private static func getMetaDataForLine(at lineIndex: Int, in lines: [String]) -> ([String: String], Int) {
        var offset = 0
        var metaData = [String: String]()
        while lineIndex + offset < lines.count - 1 {
            offset += 1
            let line = lines[lineIndex + offset]
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
    /// - Parameter result: data to sort
    private static func sortParsedData(_ result: ParsingResult) {
        result.accounts.sort {
            let (_, _, account1) = $0
            let (_, _, account2) = $1
            let date1 = account1.opening != nil ? account1.opening : account1.closing
            let date2 = account2.opening != nil ? account2.opening : account2.closing
            return date1! < date2!
        }

        result.transactions.sort {
            let (_, transaction1) = $0
            let (_, transaction2) = $1
            return transaction1.metaData.date < transaction2.metaData.date
        }

        result.balances.sort {
            let (_, balance1) = $0
            let (_, balance2) = $1
            return balance1.date < balance2.date
        }

        result.commodities.sort {
            let (_, commodity1) = $0
            let (_, commodity2) = $1
            return commodity1.opening! < commodity2.opening!
        }

        result.prices.sort {
            let (_, price1) = $0
            let (_, price2) = $1
            return price1.date < price2.date
        }
    }

    /// Adds all the parsed objects objects to the ledger.
    /// To avoid errors the objects must be sorted by date beforehand.
    /// - Parameter result: parsed data which should be added to the ledger
    /// - Returns: Ledger
    private static func importParsedData(_ result: ParsingResult) -> Ledger {
        let ledger = Ledger()

        // no dependencies
        ledger.parsingErrors.append(contentsOf: result.parsingErrors)
        ledger.option.append(contentsOf: result.options)
        ledger.plugins.append(contentsOf: result.plugins)
        ledger.custom.append(contentsOf: result.customs)
        ledger.events.append(contentsOf: result.events)

        // commodities do not have dependencies
        for (lineIndex, commodity) in result.commodities {
            do {
                try ledger.add(commodity)
            } catch {
                ledger.parsingErrors.append("Error with commodity \(commodity): \(error.localizedDescription) in line \(lineIndex + 1)")
            }
        }

        // accounts depend on commodities
        for (lineIndex, line, account) in result.accounts {
            addAccount(lineIndex: lineIndex, line: line, account: account, to: ledger)
        }

        // prices depend on commodities
        for (lineIndex, price) in result.prices {
            do {
                try ledger.add(price)
            } catch {
                ledger.parsingErrors.append("Error with price \(price): \(error.localizedDescription) in line \(lineIndex + 1)")
            }
        }

        // balances depend on accounts and commodities
        for (lineIndex, balance) in result.balances {
            do {
                try ledger.add(balance)
            } catch {
                ledger.parsingErrors.append("Error with balance \(balance): \(error.localizedDescription) in line \(lineIndex + 1)")
            }
        }

        // transactions depend on accounts and commodities
        for (_, transaction) in result.transactions {
            _ = ledger.add(transaction)
        }

        return ledger
    }

    /// Adds an account opening or closing to the ledger
    /// - Parameters:
    ///   - lineIndex: line index containing the data about the account - used to print out exact errors
    ///   - line: line containing the data about the account - used to print out exact errors
    ///   - account: the account to add
    ///   - ledger: ledger to add the accounts to
    private static func addAccount(lineIndex: Int, line: String, account: Account, to ledger: Ledger) {
        if let ledgerAccount = ledger.accounts.first(where: { $0.name == account.name }) {
            if account.closing != nil {
                if ledgerAccount.closing == nil {
                    ledgerAccount.closing = account.closing
                } else {
                    ledger.parsingErrors.append("Second closing for account \(account.name) in line \(lineIndex + 1): \(line)")
                }
            } else {
                ledger.parsingErrors.append("Second open for account \(account.name) in line \(lineIndex + 1): \(line)")
            }
        } else {
            do {
                try ledger.add(account)
            } catch {
                ledger.parsingErrors.append("Error with account \(account.name): \(error.localizedDescription) in line \(lineIndex + 1): \(line)")
            }
        }
    }

    /// Parses a single line
    ///
    /// - Parameters:
    ///   - line: string of the line
    ///   - lineIndex: index of the line for error messages
    ///   - metaData: metaData for this directive
    ///   - result: ParsingResult where the parsed data or errors should be saved
    /// - Returns: new open transaction or nil if no transaction open
    private static func parse(_ line: String, index lineIndex: Int, metaData: [String: String], into result: ParsingResult) {

        // Account
        if let account = AccountParser.parseFrom(line: line, metaData: metaData) {
            result.accounts.append((lineIndex, line, account))
            return
        }

        // Price
        if let price = PriceParser.parseFrom(line: line, metaData: metaData) {
            result.prices.append((lineIndex, price))
            return
        }

        // Commodity
        if let commodity = CommodityParser.parseFrom(line: line, metaData: metaData) {
            result.commodities.append((lineIndex, commodity))
            return
        }

        // Balance
        if let balance = BalanceParser.parseFrom(line: line, metaData: metaData) {
            result.balances.append((lineIndex, balance))
            return
        }

        // Option
        if let option = OptionParser.parseFrom(line: line) {
            result.options.append(option)
            return
        }

        // Plugin
        if let plugin = PluginParser.parseFrom(line: line) {
            result.plugins.append(plugin)
            return
        }

        // Event
        if let event = EventParser.parseFrom(line: line, metaData: metaData) {
            result.events.append(event)
            return
        }

        // Custom
        if let custom = CustomsParser.parseFrom(line: line, metaData: metaData) {
            result.customs.append(custom)
            return
        }

        result.parsingErrors.append("Invalid format in line \(lineIndex + 1): \(line)")
    }

}
