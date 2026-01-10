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
        let text: String
        if #available(macOS 15, iOS 18, *) {
            text = try String(contentsOf: path, encoding: .utf8)
        } else {
            text = try String(contentsOf: path)
        }
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
        if line.isEmpty || line[line.startIndex] == Self.comment {
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
            }
            offset += metaDataOffset
        }
        result.transactions.append(( lineIndex + offset + 1, Transaction(metaData: transactionMetaData, postings: postings)))
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
        addSimpleContent(result, to: ledger)

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
            do {
                try ledger.add(account)
            } catch {
                ledger.parsingErrors.append("Error with account \(account.name): \(error.localizedDescription) in line \(lineIndex + 1): \(line)")
            }
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
        for (_, balance) in result.balances {
            ledger.add(balance)
        }

        // transactions depend on accounts and commodities
        for (_, transaction) in result.transactions {
            ledger.add(transaction)
        }

        return ledger
    }

    /// Adds all the parsed objects objects which do not have dependencies to the ledger.
    /// This means parsing errors, options, plugins, custom and events
    /// To avoid errors the objects must be sorted by date beforehand.
    /// - Parameters
    ///   - result: parsed data which should be added to the ledger
    ///   - ledger: ledger to add the parsed data to
    private static func addSimpleContent(_ result: ParsingResult, to ledger: Ledger) {
        ledger.parsingErrors.append(contentsOf: result.parsingErrors)
        ledger.option.append(contentsOf: result.options)
        ledger.plugins.append(contentsOf: result.plugins)
        ledger.custom.append(contentsOf: result.customs)
        ledger.events.append(contentsOf: result.events)
    }

    /// Parses a single line
    ///
    /// - Parameters:
    ///   - line: string of the line
    ///   - lineIndex: index of the line for error messages
    ///   - metaData: metaData for this directive
    ///   - result: ParsingResult where the parsed data or errors should be saved
    /// - Returns: new open transaction or nil if no transaction open
    private static func parse(_ line: String, index lineIndex: Int, metaData: [String: String], into result: ParsingResult) { // swiftlint:disable:this function_body_length

        // Account
        if parseAccount(line, index: lineIndex, metaData: metaData, into: result) {
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

    /// Parses an account from a line into a result
    /// - Parameters:
    ///   - line: line to parse
    ///   - lineIndex: index of the line, used in error messages
    ///   - metaData: metaData of the account
    ///   - result: ParsingResult where the account or errors should be saved to
    /// - Returns: if the line contained an account
    private static func parseAccount(_ line: String, index lineIndex: Int, metaData: [String: String], into result: Self.ParsingResult) -> Bool {
        guard let parsedAccount = AccountParser.parseFrom(line: line, metaData: metaData) else {
            return false
        }
        if let existingAccount = result.accounts.first(where: { _, _, account in account.name == parsedAccount.name }).map({ _, _, account in account }) {
            if parsedAccount.closing != nil {
                if existingAccount.closing == nil {
                    result.accounts.removeAll { _, _, account in account.name == parsedAccount.name }
                    let newAccount = accountFromTemplate(account: existingAccount, closing: parsedAccount.closing)
                    result.accounts.append((lineIndex, line, newAccount))
                } else {
                    result.parsingErrors.append("Second closing for account \(parsedAccount.name) in line \(lineIndex + 1): \(line)")
                }
            } else if parsedAccount.opening != nil {
                if existingAccount.opening == nil {
                    result.accounts.removeAll { _, _, account in account.name == parsedAccount.name }
                    let newAccount = accountFromTemplate(account: existingAccount, opening: parsedAccount.opening)
                    result.accounts.append((lineIndex, line, newAccount))
                } else {
                    result.parsingErrors.append("Second open for account \(parsedAccount.name) in line \(lineIndex + 1): \(line)")
                }
            }
        } else {
            result.accounts.append((lineIndex, line, parsedAccount))
        }
        return true
    }

    /// Creates a new accounts based on an old account while overriding specified properties
    /// It copies the name, bookingMEthod, commoditySymbol, opening, closing and metaData from the old account.
    /// - Parameters:
    ///   - account: to use as baseline
    ///   - opening: optional opening if you want to override it
    ///   - closing: optional closing if you want to override it
    /// - Returns: a new account
    private static func accountFromTemplate(account: Account, opening: Date? = nil, closing: Date? = nil) -> Account {
        Account(name: account.name,
                bookingMethod: account.bookingMethod,
                commoditySymbol: account.commoditySymbol,
                opening: opening ?? account.opening,
                closing: closing ?? account.closing,
                metaData: account.metaData)
    }

}
