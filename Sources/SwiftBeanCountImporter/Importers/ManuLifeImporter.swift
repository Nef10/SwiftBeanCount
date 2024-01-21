//
//  ManuLifeImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2019-09-08.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParserUtils

class ManuLifeImporter: BaseImporter, TransactionBalanceTextImporter {

    private struct ManuLifeBalance {
        let commodity: String
        let unitValue: String
        let employeeBasic: String?
        let employeeVoluntary: String?
        let employerMatch: String?
        let employerBasic: String?
    }

    private struct ManuLifeBuy {
        let commodity: String
        let units: String
        let price: String
        let total: String
    }

    override class var importerName: String { "ManuLife" }
    override class var importerType: String { "manulife" }
    override class var helpText: String {
        """
        Enables importing of transactions and balances from ManuLife Group Retirement Accounts.

        This text-based importer requires you to copy two texts from the website. After logging in:
        - For the transaction text, go to My Account -> Transaction Summary and select the correct Contribution from the table. In the popup select all text.
        - For the balance text, go to My Account -> View My Account Balance and select Investment details at the bottom. Select all text starting from Investment details.

        Each group account must have seperate sub-accounts for each contribution category plus cash. Within each category it must have sub-accounts for each fund:
        E.g. Assets:ManuLife:RRSP:Cash, Assets:ManuLife:RRSP:Employer:Match:MLLPR2060, Assets:ManuLife:RRSP:Employee:Basic:MLLPR2060, Assets:ManuLife:Employer:Match:Fund2, ...
        The different categories are Employee:Basic, Employee:Voluntary, Employer:Basic and Employer:Match.

        You also must create a commodity entry for every fund like this:
        YYYY-MM-DD commodity MLLPR2060
            name: "2690 MLI MFS LifePlan Ret 2060 q4"
        The symbol (MLLPR2060) of your commodity will be used as the sub-account name (see above), and the name must match the one on the ManuLife website.

        To use this importer, add the following meta data to your cash account, providing the percentages you and your employer contribute to the different categories:
        \(Settings.importerTypeKey): "\(importerType)"
        employee-basic-fraction: "2.5"
        employer-basic-fraction: "2.5"
        employer-match-fraction: "2.5"
        employee-voluntary-fraction: "0"

        Note: Due to rounding and the split in the different categories some balance errors can occur. In this case please adjust the transaction to match the balance.
        """
    }

    /// DateFormatter to parse the date from the input
    private static let importDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "MMMM d, yyyy"
        return dateFormatter
    }()

    override var importName: String { "ManuLife Text" }

    private var date: Date { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: Date()))! }

    private let defaultContribution = 1.0
    private let unitFormat = "%.5f"

    // Input
    private let transactionInputString: String
    private let balanceInputString: String

    private var accountString: String { configuredAccountName.fullName.split(separator: ":").dropLast(1).joined(separator: ":") }
    private var account: Account? { ledger?.accounts.first { $0.name == configuredAccountName } }
    private var employeeBasicFraction: Double { Double(account?.metaData["employee-basic-fraction"] ?? "") ?? defaultContribution }
    private var employerBasicFraction: Double { Double(account?.metaData["employer-basic-fraction"] ?? "") ?? defaultContribution }
    private var employerMatchFraction: Double { Double(account?.metaData["employer-match-fraction"] ?? "") ?? defaultContribution }
    private var employeeVoluntaryFraction: Double { Double(account?.metaData["employee-voluntary-fraction"] ?? "") ?? defaultContribution }

    // Results from parsing
    private var parsedManuLifeBalances = [ManuLifeBalance]()
    private var parsedManuLifeBuys = [ManuLifeBuy]()
    private var parsedTransactionDate: Date?

    // Results to return
    private var balances = [Balance]()
    private var prices = [Price]()

    private var didReturnTransaction = false

    required init(ledger: Ledger?, transaction: String, balance: String) {
        transactionInputString = transaction
        balanceInputString = balance
        super.init(ledger: ledger)
    }

    override func load() {
        let commodities = ledger?.commodities.reduce(into: [String: String]()) {
            if let name = $1.metaData["name"] {
                $0[name] = $1.symbol
            }
        } ?? [:]
        if !transactionInputString.isEmpty {
            let (buys, date) = parsePurchase(string: transactionInputString, commodities: commodities)
            parsedManuLifeBuys = buys
            parsedTransactionDate = date
        }
        if !balanceInputString.isEmpty {
            parsedManuLifeBalances = parseBalances(string: balanceInputString, commodities: commodities)
        }
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard !didReturnTransaction else {
            return nil
        }
        var (transaction, prices) = convertPurchase(parsedManuLifeBuys, on: parsedTransactionDate)
        let (balances, balancePrices) = convertBalances(parsedManuLifeBalances)
        prices.append(contentsOf: balancePrices)

        for balance in balances where !(ledger?.accounts.flatMap { $0.balances }.contains(balance) ?? false) {
            self.balances.append(balance)
        }
        for price in prices where !(ledger?.prices.contains(price) ?? false) {
            self.prices.append(price)
        }

        didReturnTransaction = true
        return transaction
    }

    override func balancesToImport() -> [Balance] {
        balances
    }
    override func pricesToImport() -> [Price] {
        prices
    }

    /// Parses a string into ManuLifeBalances
    ///
    /// - Parameters:
    ///   - string: input from website
    ///   - commodities: dictionary of name to account for commodities
    /// - Returns: ManuLifeBalances
    private func parseBalances(string: String, commodities: [String: String]) -> [ManuLifeBalance] {
        let unitValuePattern = #"\s*?(?:Employer Basic|Member Voluntary|Employee voluntary)\s*[0-9.,]*\s*([0-9.,]*)\s*[0-9.,]*"#

        // swiftlint:disable force_try
        let commodityRegex = try! NSRegularExpression(pattern: #"\s*?(\d{4}\s*?-\s*?.*?[a-z]\d)\s*?$"#, options: [.anchorsMatchLines])
        let employeeBasicRegex = try! NSRegularExpression(pattern: #"\s*?Employee Basic\s*([0-9.,]*)"#, options: [.anchorsMatchLines])
        let employeeVoluntaryRegex = try! NSRegularExpression(pattern: #"\s*?Employee voluntary\s*([0-9.,]*)"#, options: [.anchorsMatchLines])
        let employerBasicRegex = try! NSRegularExpression(pattern: #"\s*?Employer Basic\s*([0-9.,]*)"#, options: [.anchorsMatchLines])
        let employerMatchRegex = try! NSRegularExpression(pattern: #"\s*?Employer Match\s*([0-9.,]*)"#, options: [.anchorsMatchLines])
        let unitValueRegex = try! NSRegularExpression(pattern: unitValuePattern, options: [.anchorsMatchLines])
        // swiftlint:enable force_try

        // Split by different Commodities
        let splittedInput = string.components(separatedBy: "TOTAL")

        // Get different Accounts for each Commodity
        var results = [ManuLifeBalance]()
        for input in splittedInput {
            guard var commodity = firstMatch(in: input, regex: commodityRegex), let unitValue = firstMatch(in: input, regex: unitValueRegex) else {
                continue
            }
            commodity = commodity.replacingOccurrences(of: " -", with: "")
            results.append(ManuLifeBalance(commodity: commodities[commodity] ?? commodity,
                                           unitValue: unitValue,
                                           employeeBasic: firstMatch(in: input, regex: employeeBasicRegex),
                                           employeeVoluntary: firstMatch(in: input, regex: employeeVoluntaryRegex),
                                           employerMatch: firstMatch(in: input, regex: employerMatchRegex),
                                           employerBasic: firstMatch(in: input, regex: employerBasicRegex)))
        }

        return results
    }

    /// Converts ManuLifeBalance to SwiftBeanCountModel Balances and Prices
    private func convertBalances(_ manuLifeBalances: [ManuLifeBalance]) -> ([Balance], [Price]) {
        let balances: [Balance] = manuLifeBalances.flatMap { manuLifeBalance -> [Balance] in
            var tempBalances = [Balance]()
            if let amountString = manuLifeBalance.employeeBasic, let accountName = try? AccountName("\(accountString):Employee:Basic:\(manuLifeBalance.commodity)") {
                let (amountDecimal, decimalDigits) = amountString.amountDecimal()
                let amount = Amount(number: amountDecimal, commoditySymbol: manuLifeBalance.commodity, decimalDigits: decimalDigits)
                tempBalances.append(Balance(date: date, accountName: accountName, amount: amount))
            }
            if let amountString = manuLifeBalance.employerBasic, let accountName = try? AccountName("\(accountString):Employer:Basic:\(manuLifeBalance.commodity)") {
                let (amountDecimal, decimalDigits) = amountString.amountDecimal()
                let amount = Amount(number: amountDecimal, commoditySymbol: manuLifeBalance.commodity, decimalDigits: decimalDigits)
                tempBalances.append(Balance(date: date, accountName: accountName, amount: amount))
            }
            if let amountString = manuLifeBalance.employerMatch, let accountName = try? AccountName("\(accountString):Employer:Match:\(manuLifeBalance.commodity)") {
                let (amountDecimal, decimalDigits) = amountString.amountDecimal()
                let amount = Amount(number: amountDecimal, commoditySymbol: manuLifeBalance.commodity, decimalDigits: decimalDigits)
                tempBalances.append(Balance(date: date, accountName: accountName, amount: amount))
            }
            if let amountString = manuLifeBalance.employeeVoluntary, let accountName = try? AccountName("\(accountString):Employee:Voluntary:\(manuLifeBalance.commodity)") {
                let (amountDecimal, decimalDigits) = amountString.amountDecimal()
                let amount = Amount(number: amountDecimal, commoditySymbol: manuLifeBalance.commodity, decimalDigits: decimalDigits)
                tempBalances.append(Balance(date: date, accountName: accountName, amount: amount))
            }
            return tempBalances
        }

        let prices: [Price] = manuLifeBalances.compactMap { manuLifeBalance -> Price? in
            let (amountDecimal, decimalDigits) = manuLifeBalance.unitValue.amountDecimal()
            let amount = Amount(number: amountDecimal, commoditySymbol: commoditySymbol, decimalDigits: decimalDigits)
            return try? Price(date: date, commoditySymbol: manuLifeBalance.commodity, amount: amount)
        }

        return (balances, prices)
    }

    /// Parses a string into ManuLifeBuys
    ///
    /// - Parameters:
    ///   - string: input from website
    ///   - commodities: dictionary of name to account for commodities
    /// - Returns: Tupel with ManuLifeBuys and the purchase date
    private func parsePurchase(string input: String, commodities: [String: String]) -> ([ManuLifeBuy], Date?) {
        let pattern = #"\s*.*?\.gif\s*(\d{4}.*?[a-z]\d)\s*$\s*[a-zA-z]*[ ]?(?:Contribution|Fund Transfer)\s*([0-9.,]*)\s*units\s*@\s*\$([0-9.,]*)/unit\s*(-?[0-9.,]*)\s*$"#

        // swiftlint:disable force_try
        let dateRegex = try! NSRegularExpression(pattern: #"^(.*?) [a-zA-z]*[ ]?(?:Contribution|Fund Transfer) \(Ref."#, options: [.anchorsMatchLines])
        let regex = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        // swiftlint:enable force_try

        // Parse purchase date
        let parsedDate = firstMatch(in: input, regex: dateRegex) ?? ""
        let date = Self.importDateFormatter.date(from: parsedDate)

        // Parse purchased units
        let fullRange = NSRange(input.startIndex..<input.endIndex, in: input)
        return (regex.matches(in: input, options: [], range: fullRange).compactMap { result -> ManuLifeBuy? in
            guard result.numberOfRanges == 5 else {
                return nil
            }
            var strings = [String]()
            for rangeNumber in 1..<result.numberOfRanges {
                let matchRange = result.range(at: rangeNumber)
                guard matchRange.location != NSNotFound, let range = Range(matchRange, in: input) else {
                    return nil
                }
                strings.append("\(input[range])")
            }
            let commodity = commodities[strings[0]] ?? strings[0]
            return ManuLifeBuy(commodity: commodity, units: strings[1].replacingOccurrences(of: ",", with: ""), price: strings[2], total: strings[3])
        }, date)
    }

    /// Converts ManuLifeBuys to ImportedTransactions and SwiftBeanCountModel Prices
    private func convertPurchase(_ buys: [ManuLifeBuy], on date: Date?) -> (ImportedTransaction?, [Price]) {
        guard !buys.isEmpty, let date else {
            return (nil, [])
        }

        var totalAmount = Decimal(), postings = [Posting]()

        buys.forEach {
            let (buyPostings, buyAmount) = generatePostings(from: $0)
            totalAmount += buyAmount
            postings.append(contentsOf: buyPostings)
        }

        if !totalAmount.isZero {
            postings.insert(Posting(accountName: configuredAccountName, amount: Amount(number: -totalAmount, commoditySymbol: commoditySymbol, decimalDigits: 2)), at: 0)
        }

        let prices: [Price] = buys.compactMap { manuLifeBuy -> Price? in
            try? Price(date: date, commoditySymbol: manuLifeBuy.commodity, amount: parseAmountFrom(string: manuLifeBuy.price, commoditySymbol: commoditySymbol))
        }

        let transaction = Transaction(metaData: TransactionMetaData(date: date, payee: "", narration: "", flag: .complete, tags: []), postings: postings)
        return (ImportedTransaction(transaction, possibleDuplicate: getPossibleDuplicateFor(transaction)), prices)
    }

    private func generatePostings(from buy: ManuLifeBuy) -> ([Posting], Decimal) {
        var postings = [Posting]()
        let unitFraction = Double(buy.units)! / (employeeBasicFraction + employerBasicFraction + employerMatchFraction + employeeVoluntaryFraction)
        let (buyAmount, _) = buy.total.amountDecimal()
        let sign = buyAmount.sign == .minus ? -1.0 : 1.0
        let price = parseAmountFrom(string: buy.price, commoditySymbol: commoditySymbol)
        guard let cost = try? Cost(amount: buyAmount.sign == .minus ? nil : price, date: nil, label: nil) else {
            return([], 0)
        }

        if employeeBasicFraction != 0, let accountName = try? AccountName("\(accountString):Employee:Basic:\(buy.commodity)") {
            let amount = parseAmountFrom(string: String(format: unitFormat, sign * unitFraction * employeeBasicFraction), commoditySymbol: buy.commodity)
            postings.append(Posting(accountName: accountName, amount: amount, price: buyAmount.sign == .minus ? price : nil, cost: cost))
        }
        if employerBasicFraction != 0, let accountName = try? AccountName("\(accountString):Employer:Basic:\(buy.commodity)") {
            let amount = parseAmountFrom(string: String(format: unitFormat, sign * unitFraction * employerBasicFraction), commoditySymbol: buy.commodity)
            postings.append(Posting(accountName: accountName, amount: amount, price: buyAmount.sign == .minus ? price : nil, cost: cost))
        }
        if employerMatchFraction != 0, let accountName = try? AccountName("\(accountString):Employer:Match:\(buy.commodity)") {
            let amount = parseAmountFrom(string: String(format: unitFormat, sign * unitFraction * employerMatchFraction), commoditySymbol: buy.commodity)
            postings.append(Posting(accountName: accountName, amount: amount, price: buyAmount.sign == .minus ? price : nil, cost: cost))
        }
        if employeeVoluntaryFraction != 0, let accountName = try? AccountName("\(accountString):Employee:Voluntary:\(buy.commodity)") {
            let amount = parseAmountFrom(string: String(format: unitFormat, sign * unitFraction * employeeVoluntaryFraction), commoditySymbol: buy.commodity)
            postings.append(Posting(accountName: accountName, amount: amount, price: buyAmount.sign == .minus ? price : nil, cost: cost))
        }
        return (postings, buyAmount)
    }

    /// Returns the first match of the capture group regex in the input string
    ///
    /// Checks that there is exactly one capture group.
    ///
    /// - Parameters:
    ///   - input: string to run regex on
    ///   - regex: regex
    /// - Returns: result of the capture group if found, nil otherwise
    private func firstMatch(in input: String, regex: NSRegularExpression) -> String? {
        let result = input.matchingStrings(regex: regex)
        guard !result.isEmpty && result[0].count == 2 else {
            return nil
        }
        return result[0][1]
    }

    private func parseAmountFrom(string: String, commoditySymbol: String) -> Amount {
        let (number, decimalDigits) = string.amountDecimal()
        return Amount(number: number, commoditySymbol: commoditySymbol, decimalDigits: decimalDigits)
    }

}
