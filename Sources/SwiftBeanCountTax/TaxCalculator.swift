import Foundation
import SwiftBeanCountModel

/// Constants of all keys used to look up meta data from the ledger
enum MetaDataKeys {
    /// name of the custom settings directives
    static let settings = "tax-slip-settings"
    /// settings value to configure the list of tax slips
    static let slipNames = "slip-names"
    /// settings value to configure the currency of a specific tax slip
    static let slipCurrency = "slip-currency"
    /// settings value to specify a split account
    static let account = "account"

    /// meta data on an account the specific the symbol to use
    static let symbol = "tax-symbol"
    /// meta data on an account the specific the description to use
    static let description = "tax-description"
    /// meta data on an account the specific the tax slip issuer
    static let issuer = "tax-slip-issuer"

    /// meta data on a transaction to modify the tax year that it should be counted towards
    static let year = "tax-year"

    /// meta data on a commodity to specifc the description to use if the accounts has this symbol
    static let commodityName = "name"
}

/// Utility to generate tax slips from a `Ledger`
///
/// It relies heavily on meta data in the leadger.
public enum TaxCalculator {

    /// Generates all tax slips based on the meta data in the ledger for a specifc tax year
    /// - Parameters:
    ///   - ledger: `Ledger`
    ///   - year: tax year to get the slips for
    /// - Returns: Array of `TaxSlip`s
    public static func generateTaxSlips(from ledger: Ledger, for year: Int) throws -> [TaxSlip] {
        // Only get setting in effect during the tax year or earlier years
        let settings = ledger.custom.filter { $0.name == MetaDataKeys.settings && $0.date < Calendar.current.date(from: DateComponents(year: year + 1, month: 1, day: 1))! }
        let taxSlipCurrencySettings = settings.filter { $0.values.count == 3 && $0.values[0] == MetaDataKeys.slipCurrency }
        let taxSlipAccountSettings = settings.filter { $0.values.count == 4 && $0.values[0] == MetaDataKeys.account }
        let taxSlipNameSettings = settings.filter { $0.values.count > 1 && $0.values[0] == MetaDataKeys.slipNames }
        guard let slips = taxSlipNameSettings.min(by: { $0.date > $1.date })?.values.dropFirst(1), !slips.isEmpty else {
            throw TaxErrors.noTaxSlipConfigured(year)
        }
        let taxYearTransactions = ledger.transactions.filter {
            (Calendar.current.component(.year, from: $0.metaData.date) == year && Int($0.metaData.metaData[MetaDataKeys.year] ?? String(year)) == year)
                || Int($0.metaData.metaData[MetaDataKeys.year] ?? "") == year
        }
        return try slips.flatMap { slip throws in
            guard let commodity = taxSlipCurrencySettings.filter({ $0.values[1] == slip }).min(by: { $0.date > $1.date })?.values[2] else {
                throw TaxErrors.noCurrencyDefined(slip, year)
            }
            let splitAccounts = taxSlipAccountSettings.filter { $0.values[1] == slip }.map { ($0.values[3], $0.values[2]) }
            return try getTaxSlips(slip, year: year, commodity: commodity, splitAccounts: splitAccounts, taxYearTransactions: taxYearTransactions, ledger: ledger)
        }
        .sorted { "\($0.name)\($0.issuer ?? "")" < "\($1.name)\($1.issuer ?? "")" }
    }

    /// Gets a specifc tax slip from all issuers
    /// - Parameters:
    ///   - slip: name of the tax slip to get
    ///   - year: tax year to get the slip for
    ///   - commodity: commodity to use
    ///   - splitAccounts: tuple of account name and tax slip box for split accounts
    ///   - taxYearTransactions: all transactions to go through, already filtered by tax year (for performance reasons)
    ///   - ledger: ledger
    /// - Returns: Array of `TaxSlip`s
    private static func getTaxSlips( // swiftlint:disable:this function_parameter_count
        _ slip: String,
        year: Int,
        commodity: String,
        splitAccounts: [(String, String)],
        taxYearTransactions: [Transaction],
        ledger: Ledger
    ) throws -> [TaxSlip] {
        let taxSlipRelevantAccounts = ledger.accounts.filter { $0.metaData.keys.contains(slip) }
        let issuers = Array(Set(taxSlipRelevantAccounts.map { $0.metaData[MetaDataKeys.issuer] ?? "" }))
        return try issuers.compactMap { issuer throws -> TaxSlip? in
            let issuerTaxSlipRelevantAccounts = taxSlipRelevantAccounts.filter { $0.metaData[MetaDataKeys.issuer] ?? "" == issuer }
            // collect all transactions which have a posting to a split account AND an account for this issuer
            var splitTransactions = taxYearTransactions.filter { $0.postings.contains { issuerTaxSlipRelevantAccounts.map { $0.name }.contains($0.accountName) }
              && $0.postings.contains { splitAccounts.map { $0.0 }.contains($0.accountName.fullName) }
            }
            let entries = issuerTaxSlipRelevantAccounts.flatMap { account -> [TaxSlipEntry] in
                let postings = taxYearTransactions.flatMap { $0.postings.filter { $0.accountName == account.name } }
                let symbol = taxSymbol(for: account, in: ledger), name = taxDescription(for: account, in: ledger)
                var entries = [TaxSlipEntry]()

                if let (value, originalValue) = getValues(commodity: commodity, postings: postings) {
                    entries.append(TaxSlipEntry(symbol: symbol, name: name, box: account.metaData[slip]!, value: value, originalValue: originalValue))
                }

                // split accounts
                entries.append(contentsOf: splitAccounts.compactMap { splitAccount -> TaxSlipEntry? in
                    // filter splitTransactions for transactions for the current account, and get the posting to the split account
                    let splitPostings = splitTransactions.filter { [account.name.fullName, splitAccount.0].allSatisfy($0.postings.map { $0.accountName.fullName }.contains) }
                        .flatMap { $0.postings.filter { $0.accountName.fullName == splitAccount.0 } }
                    // rmove the processed transactions - otherwise when a transaction has multiple accounts and a split account, it would be counted multiple times
                    splitTransactions.removeAll { [account.name.fullName, splitAccount.0].allSatisfy($0.postings.map { $0.accountName.fullName }.contains) }
                    if let (value, originalValue) = getValues(commodity: commodity, postings: splitPostings) {
                        return TaxSlipEntry(symbol: symbol, name: name, box: splitAccount.1, value: value, originalValue: originalValue)
                    }
                    return nil
                })
                return entries
            }
            guard !entries.isEmpty else {
                return nil
            }
            return try TaxSlip(name: slip.capitalized, year: year, issuer: issuer.isEmpty ? nil : issuer, entries: entries)
        }
    }

    /// Calculates the values of postings in a certain commodity
    ///
    /// This function adds up the amount of all postings. If a posting is not in the requested commodity, it tried to convert it via the postings price. If there is no price,
    /// it tires ot use the exchange rate from a price on a different posting within the same transaction. If neither one works, it will keep the postings commodity.
    ///
    /// If not all postings were already in the requested commodity, the second value in the tuple will be the `MultiCurrencyAmount` of the the
    /// postings in their original commodity
    ///
    /// - Parameters:
    ///   - commodity: commodity to calculate in
    ///   - postings: postings to add up
    /// - Returns: optional tuple of (MultiCurrencyAmount, MultiCurrencyAmount?) - the first one is the value in the requested commodity (if possible)
    ///            and the last one in the postings commodity
    private static func getValues(commodity: String, postings: [TransactionPosting]) -> (MultiCurrencyAmount, MultiCurrencyAmount?)? {
        let originalValue = postings.reduce(MultiCurrencyAmount()) { $0 + $1.amount }
        guard !originalValue.amounts.isEmpty else {
            return nil
        }
        if originalValue.amounts.count > 1 || !originalValue.amounts.keys.contains(commodity) { // Not all amounts in specified commodity
            let value = postings.map {
                if $0.amount.commoditySymbol == commodity { // Posting in correct commodity
                    return $0.amount
                }
                if $0.price?.commoditySymbol == commodity { // Posting has price in correct commidity
                    return Amount(number: $0.amount.number * $0.price!.number, commoditySymbol: commodity, decimalDigits: $0.amount.decimalDigits)
                }
                let existingCommodity = $0.amount.commoditySymbol
                // See if we can use exchange rate from another posting on this transaction
                if let price = $0.transaction.postings.first(where: { $0.amount.commoditySymbol == commodity && $0.price?.commoditySymbol == existingCommodity })?.price {
                    return Amount(number: $0.amount.number / price.number, commoditySymbol: commodity, decimalDigits: $0.amount.decimalDigits)
                }
                return $0.amount // No conversion found
            }
            .reduce(MultiCurrencyAmount()) { $0 + $1 }
            return (value, originalValue)
        }
        // All amounts in specified commodity
        return (originalValue, nil)
    }

    /// Gets the symbol for an account which should be used on the slip
    ///
    /// This uses the meta data on the account (`MetaDataKeys.symbol`), and if not set, it will check if there is a commodity
    /// with the same symbol as the the last or second last leg of the account. If there is a commodity, it will use its symbol.
    ///
    /// - Parameters:
    ///   - account: account to get symbol for
    ///   - ledger: ledger to look up commodities in
    /// - Returns: symbol, or nil if non found
    private static func taxSymbol(for account: Account, in ledger: Ledger) -> String? {
        if let symbol = account.metaData[MetaDataKeys.symbol] {
            return symbol
        }
        if let commodity = ledger.commodities.first(where: { $0.symbol == account.name.nameItem }) {
            return commodity.symbol
        }
        let secondLastNameItem = try? AccountName(String(account.name.fullName.dropLast(account.name.nameItem.count + ":".count))).nameItem
        if let commodity = ledger.commodities.first(where: { $0.symbol == secondLastNameItem }) {
            return commodity.symbol
        }
        return nil
    }

    /// Gets the description for an account which should be used on the slip
    ///
    /// This uses the meta data on the account (`MetaDataKeys.description`), and if not set, it will check if there is a commodity with the same name as the taxSymbol.
    /// If there is a commodity, it will use its name meta data (`MetaDataKeys.commodityName`)
    ///
    /// - Parameters:
    ///   - account: account to get description for
    ///   - ledger: ledger to look up commodities in
    /// - Returns: description, or nil if non found
    private static func taxDescription(for account: Account, in ledger: Ledger) -> String? {
        if let description = account.metaData[MetaDataKeys.description] {
            return description
        }
        if let commodity = ledger.commodities.first(where: { $0.symbol == taxSymbol(for: account, in: ledger) ?? "" }) {
            return commodity.metaData[MetaDataKeys.commodityName] ?? ""
        }
        return nil
    }

}
