//
//  EquatePlusImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2024-01-21.
//  Copyright © 2024 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParserUtils

/// Errors which can happen when importing
enum EquatePlusImporterError: Error {
    case balanceImportNotSupported(String)
    case failedToParseDate(String)
    case unknownContributionType(String)
    case unknownTransactionType(String)
    case invalidContributionMapping(String, String)
    case invalidTransactionMapping(String, String)

}

// swiftlint:disable:next type_body_length
class EquatePlusImporter: BaseImporter, TransactionBalanceTextImporter {

    struct Contribution {
        var date: Date
        var type: ContributionType
        var amount: Amount
        var amountAvailable: Amount
        var purchaseDate: Date
        var purchasedShares: Amount
    }

    enum ContributionType: String {
        case you
        case employer
    }

    struct GroupedContribution {
        let date: Date
        let purchaseDate: Date
        var amountYou: Amount?
        var amountEmployer: Amount?
        var amountAvailableYou: Amount?
        var amountAvailableEmployer: Amount?
        var purchasedSharesYou: Amount?
        var purchasedSharesEmployer: Amount?
    }

    struct EquatePlusTransaction {
        var date: Date
        var type: TransactionType
        var price: Amount
        var amount: Amount
    }

    enum TransactionType: String {
        case match = "Match"
        case purchase = "Purchase"
        case sell = "Sell"
    }

    struct GroupedTransaction {
        let date: Date
        let price: Amount
        var matchAmount: Amount?
        var purchaseAmount: Amount?
    }

    struct MatchedTransaction {
        let date: Date
        let price: Amount
        let amount: Amount
        let purchaseAmount: Amount
        let contribution: Amount
    }

    override class var importerName: String { "EquatePlus" }
    override class var importerType: String { "equateplus" }
    override class var helpText: String {
        """
        Enables importing of transactions and from EquatePlus accounts with employer share matching. (It does not support importing RSUs / Options)

        This text-based imported requires you to copy text from the website. After logging in:
        1. Click on "Plan details" for the share purchase program
        2. Expand both sections ("Show purchase history" and "See more")
        3. Select all text (Ctrl / Cmd + A) and copy it
        4. Paste this text in the importer under transaction (importing balances is not supported for this importer)

        To use this importer, add the following meta data to your cash account:
        \(Settings.importerTypeKey): "\(importerType)"
        stock: SYMBOL
        contribution-currency: SYMBOL
        purchase-currency: SYMBOL

        The stock account will be automatically inferred by replacing the last part of your cash account with the stock symbol.
        """
    }

    /// DateFormatter to parse the date from the input
    private static let importDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "MMM. d, yyyy"
        return dateFormatter
    }()

    override var importName: String { "EquatePlus Text" }

    // Input
    private let transactionInputString: String
    private let balanceInputString: String

    private var account: Account? { ledger?.accounts.first { $0.name == configuredAccountName } }
    private var stockAccountName: AccountName? {
        try? AccountName(String("\(configuredAccountName.fullName.dropLast(configuredAccountName.nameItem.utf16.count))\(stockCommodity)"))
    }
    private var stockCommodity: String { account?.metaData["stock"] ?? "UNKNOWN" }
    private var contributionCommodity: String { account?.metaData["contribution-currency"] ?? "UNKNOWN" }
    private var purchaseCommodity: String { account?.metaData["purchase-currency"] ?? "UNKNOWN" }

    // Results to return
    private var prices = [Price]()
    private var transactions = [ImportedTransaction]()

    required init(ledger: Ledger?, transaction: String, balance: String) {
        transactionInputString = transaction
        balanceInputString = balance
        super.init(ledger: ledger)
    }

    override func load() {
        if !balanceInputString.isEmpty {
            let group = DispatchGroup()
            group.enter()
            self.delegate?.error(EquatePlusImporterError.balanceImportNotSupported(balanceInputString)) {
                group.leave()
            }
            group.wait()
        }
        if !transactionInputString.isEmpty {
            do {
                let (parsedTransactions, parsedPrices) = try parseTransactions(string: transactionInputString)
                transactions = parsedTransactions
                prices = parsedPrices
            } catch {
                let group = DispatchGroup()
                group.enter()
                self.delegate?.error(error) {
                    group.leave()
                }
                group.wait()
            }
        }
    }

    override func nextTransaction() -> ImportedTransaction? {
        transactions.popLast()
    }

    override func balancesToImport() -> [Balance] {
        []
    }
    override func pricesToImport() -> [Price] {
        prices
    }

    private func parseTransactions(string input: String) throws -> ([ImportedTransaction], [Price]) {
        // Split input into contribution and transaction part
        let contributionsString, transactionsString: String
        if #available(macOS 13.0, *) {
            let splitInput = input.split(separator: "Market price")
            contributionsString = String(splitInput[0])
            transactionsString = String(String(splitInput[1]).split(separator: "flatexDEGIRO").last!)
        } else {
            let splitInput = input.components(separatedBy: "Market price")
            contributionsString = String(splitInput[0])
            transactionsString = String(String(splitInput[1]).components(separatedBy: "flatexDEGIRO").last!)
        }

        let contributions = try parseContributions(contributionsString)
        let groupedContributions = try groupContributions(contributions)

        let transactions = try parseTransactions(transactionsString)
        let groupedTransactions = try groupTransactions(transactions)

        let matchedTransactions = matchTransactions(groupedTransactions, to: groupedContributions)

        return try getTransactionsAndPrices(matchedTransactions)
    }

    private func parseContributions(_ input: String) throws -> [Contribution] {
        var result = [Contribution]()
        // swiftlint:disable:next line_length
        let pattern = #"((Jan\.|Feb\.|Mar\.|Apr\.|May|Jun\.|Jul\.|Aug\.|Sep\.|Oct\.|Nov\.|Dec\.) \d{1,2}, \d{4})([^$\d]*)\$ ([\d,]+\.\d+)[^€\d]*€ ([\d,]+\.\d+)((Jan\.|Feb\.|Mar\.|Apr\.|May|Jun\.|Jul\.|Aug\.|Sep\.|Oct\.|Nov\.|Dec\.) \d{1,2}, \d{4})(\d*.\d*)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: []) // swiftlint:disable:this force_try
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))

        for match in matches {
            let dateString = String(input[Range(match.range(at: 1), in: input)!])
            guard let date = Self.importDateFormatter.date(from: dateString) else {
                throw EquatePlusImporterError.failedToParseDate(dateString)
            }

            let purchaseDateString = String(input[Range(match.range(at: 6), in: input)!])
            guard let purchaseDate = Self.importDateFormatter.date(from: purchaseDateString) else {
                throw EquatePlusImporterError.failedToParseDate(purchaseDateString)
            }

            let typeString = String(input[Range(match.range(at: 3), in: input)!])
            var type: ContributionType
            if typeString.contains("Your") {
                type = .you
            } else if typeString.contains("Matching") {
                type = .employer
            } else {
                throw EquatePlusImporterError.unknownContributionType(typeString)
            }

            result.append(Contribution(date: date,
                                       type: type,
                                       amount: parseAmountFrom(string: String(input[ Range(match.range(at: 4), in: input)!]), commoditySymbol: contributionCommodity),
                                       amountAvailable: parseAmountFrom(string: String(input[ Range(match.range(at: 5), in: input)!]), commoditySymbol: purchaseCommodity),
                                       purchaseDate: purchaseDate,
                                       purchasedShares: parseAmountFrom(string: String(input[Range(match.range(at: 8), in: input)!]), commoditySymbol: stockCommodity)))
        }
        return result
    }

    func groupContributions(_ contributions: [Contribution]) throws -> [GroupedContribution] {
        var groupedContributions: [String: GroupedContribution] = [:]

        for contribution in contributions {
            let key = "\(contribution.date)-\(contribution.purchaseDate)"

            var groupedTransaction = groupedContributions[key] ?? GroupedContribution(date: contribution.date, purchaseDate: contribution.purchaseDate)

            if contribution.type == .you {
                if groupedTransaction.amountYou == nil && groupedTransaction.amountAvailableYou == nil && groupedTransaction.purchasedSharesYou == nil {
                    groupedTransaction.amountYou = contribution.amount
                    groupedTransaction.amountAvailableYou = contribution.amountAvailable
                    groupedTransaction.purchasedSharesYou = contribution.purchasedShares
                } else {
                    throw EquatePlusImporterError.invalidContributionMapping(ContributionType.you.rawValue, String(describing: contribution))
                }
            } else if contribution.type == .employer {
                if groupedTransaction.amountEmployer == nil && groupedTransaction.amountAvailableEmployer == nil && groupedTransaction.purchasedSharesEmployer == nil {
                    groupedTransaction.amountEmployer = contribution.amount
                    groupedTransaction.amountAvailableEmployer = contribution.amountAvailable
                    groupedTransaction.purchasedSharesEmployer = contribution.purchasedShares
                } else {
                    throw EquatePlusImporterError.invalidContributionMapping(ContributionType.employer.rawValue, String(describing: contribution))
                }
            }

            groupedContributions[key] = groupedTransaction
        }

        // Filter out contributions which were not mapped, e.g. either you or employer part is missing
        return Array(groupedContributions.values).filter { $0.amountEmployer != nil && $0.amountYou != nil }
    }

    func parseTransactions(_ input: String) throws -> [EquatePlusTransaction] {
        var result = [EquatePlusTransaction]()
        let regexPattern = #"((Jan\.|Feb\.|Mar\.|Apr\.|May|Jun\.|Jul\.|Aug\.|Sep\.|Oct\.|Nov\.|Dec\.) \d{1,2}, \d{4})([^€]*)€ ([\d-]+.\d{5})([\d-]+.\d{6})"#
        let regex = try! NSRegularExpression(pattern: regexPattern, options: []) // swiftlint:disable:this force_try
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))

        for match in matches {
            let dateString = String(input[Range(match.range(at: 1), in: input)!])
            guard let date = Self.importDateFormatter.date(from: dateString) else {
                throw EquatePlusImporterError.failedToParseDate(dateString)
            }

            let typeString = String(input[Range(match.range(at: 3), in: input)!])
            let type: TransactionType
            if typeString.contains("Match") {
                type = .match
            } else if typeString.contains("Purchase") {
                type = .purchase
            } else if typeString.contains("Sell") {
                type = .sell
            } else {
                throw EquatePlusImporterError.unknownTransactionType(typeString)
            }

            let price = parseAmountFrom(string: String(input[Range(match.range(at: 4), in: input)!]), commoditySymbol: purchaseCommodity)
            let quanity = parseAmountFrom(string: String(input[Range(match.range(at: 5), in: input)!]), commoditySymbol: stockCommodity)

            result.append(EquatePlusTransaction(date: date, type: type, price: price, amount: quanity))
        }
        return result
    }

    func groupTransactions(_ transactions: [EquatePlusTransaction]) throws -> [GroupedTransaction] {
        var groupedTransactions: [String: GroupedTransaction] = [:]

        for transaction in transactions {
            let key = "\(transaction.date)-\(transaction.price)"

            var groupedTransaction = groupedTransactions[key] ?? GroupedTransaction(date: transaction.date, price: transaction.price)

            if transaction.type == .match {
                if groupedTransaction.matchAmount == nil {
                    groupedTransaction.matchAmount = transaction.amount
                } else {
                    throw EquatePlusImporterError.invalidTransactionMapping(TransactionType.match.rawValue, String(describing: transaction))
                }
            } else if transaction.type == .purchase {
                if groupedTransaction.purchaseAmount == nil {
                    groupedTransaction.purchaseAmount = transaction.amount
                } else {
                    throw EquatePlusImporterError.invalidTransactionMapping(TransactionType.purchase.rawValue, String(describing: transaction))
                }
            }

            groupedTransactions[key] = groupedTransaction
        }

        // Filter out transactions which could not be mapped, e.g. which did not have a purchase and match component
        return Array(groupedTransactions.values).filter { $0.matchAmount != nil && $0.purchaseAmount != nil }
    }

    func matchTransactions(_ transactions: [GroupedTransaction], to contributions: [GroupedContribution]) -> [MatchedTransaction] {
        var result = [MatchedTransaction]()

        for transaction in transactions {
            if let matchingContribution = contributions.first(where: {
                let range = Calendar.current.date(byAdding: .day, value: -1, to: $0.purchaseDate)! ... Calendar.current.date(byAdding: .day, value: 1, to: $0.purchaseDate)!
                return range.contains(transaction.date) && $0.purchasedSharesEmployer == transaction.matchAmount && $0.purchasedSharesYou == transaction.purchaseAmount
            }) {
                result.append(MatchedTransaction(
                    date: transaction.date,
                    price: transaction.price,
                    amount: (transaction.purchaseAmount! + transaction.matchAmount!).amountFor(symbol: stockCommodity),
                    purchaseAmount: (matchingContribution.amountAvailableYou! + matchingContribution.amountAvailableEmployer!).amountFor(symbol: purchaseCommodity),
                    contribution: (matchingContribution.amountYou! + matchingContribution.amountEmployer!).amountFor(symbol: contributionCommodity))
                    )
            }
        }

        return result
    }

    private func getTransactionsAndPrices(_ matchedTransactions: [MatchedTransaction]) throws -> ([ImportedTransaction], [Price]) {
        let prices: [Price] = matchedTransactions.compactMap { try? Price(date: $0.date, commoditySymbol: stockCommodity, amount: $0.price) }
        let transactions = try matchedTransactions.map {
            var postings = [Posting]()

            let amount = Amount(number: -$0.contribution.number, commoditySymbol: $0.contribution.commoditySymbol, decimalDigits: $0.contribution.decimalDigits)
            // swiftlint:disable:next todo
            postings.append(Posting(accountName: configuredAccountName, amount: amount, price: $0.purchaseAmount)) // TODO: price needs to be full instead of per unit

            let cost = try? Cost(amount: $0.price, date: nil, label: nil)
            postings.append(Posting(accountName: try stockAccountName ?? (try AccountName("Assets:\(stockCommodity)")), amount: $0.amount, cost: cost))

            let transaction = Transaction(metaData: TransactionMetaData(date: $0.date, payee: "", narration: "", flag: .complete, tags: []), postings: postings)
            return ImportedTransaction(transaction, possibleDuplicate: getPossibleDuplicateFor(transaction))
        }

        return (transactions, prices)
    }

    private func parseAmountFrom(string: String, commoditySymbol: String) -> Amount {
        let (number, decimalDigits) = string.amountDecimal()
        return Amount(number: number, commoditySymbol: commoditySymbol, decimalDigits: decimalDigits)
    }
}

extension EquatePlusImporterError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .balanceImportNotSupported(string):
            return "This importer does not support importing balances. Trying to import: \(string)"
        case let .failedToParseDate(string):
            return "Failed to parse date: \(string)"
        case let .unknownContributionType(string):
            return "Unknow contribution type: \(string)"
        case let .unknownTransactionType(string):
            return "Unknow transaction type: \(string)"
        case let .invalidContributionMapping(type, contribution):
            return "Unable to map contributions correctly. Found second contribtuion for type \(type): \(contribution)"
        case let .invalidTransactionMapping(type, transaction):
            return "Unable to map transactions correctly. Found second transaction for type \(type): \(transaction)"
        }
    }
}
