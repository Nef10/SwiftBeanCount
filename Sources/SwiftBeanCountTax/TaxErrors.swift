import Foundation

/// Errors which can occur when using the TaxCalulator
public enum TaxErrors: Error {
    /// One tax slip has entries without and with symbols at the same time
    ///
    /// values are tax slip name, tax year and issuer
    case entriesWithAndWithoutSymbol(String, Int, String?)
    /// When no tax slip was configured in the ledger meta data (value is the year)
    case noTaxSlipConfigured(Int)
    /// When a tax slip has no currency defined (values are tax slip name and tax year)
    case noCurrencyDefined(String, Int)
    /// When a transaction has a split account and more then one other tax split relevant account, and these accounts have different symbols
    case splitAccountDifferentSymbols(String, String, String)
}

extension TaxErrors: LocalizedError {
    public var errorDescription: String? { // swiftlint:disable line_length
        switch self {
        case let .entriesWithAndWithoutSymbol(slip, year, issuer):
            return "The \(year) tax slip \(slip)\(issuer != nil ? " for \(issuer!)" : "") has postings with and without symbol. A tax slip can either be split by symbol or not, but not both.\nPlease ensure all accounts have either have one or all have no symbol configured. If your accounts last or second last leg is a commodity symbol, this will be used as fallback in case no explicit symbol is configured. To override it to no symbol in such case, add the \(MetaDataKeys.symbol) meta data with an empty string to your account"
        case let .noTaxSlipConfigured(year):
            return "There was no configured tax slip found for year \(year).\n\nMake sure your ledger contains a custom directive like this: YYYY-MM-DD custom \"\(MetaDataKeys.settings)\" \"\(MetaDataKeys.slipNames)\" \"tax-slip-name1\" \"tax-slip-name2\"\n\nAdditionally, check that the date is in or before the tax year you are tring to generate slips for."
        case let .noCurrencyDefined(slip, year):
            return "There was no currency for tax slip \(slip) in year \(year) found.\n\nMake sure your ledger contains a custom directive like this: YYYY-MM-DD custom \"\(MetaDataKeys.settings)\" \"\(MetaDataKeys.slipCurrency)\" \"tax-slip-name\" \"currencySymbol\"\n\nAdditionally, check that the date is in or before the tax year you are tring to generate slips for."
        case let .splitAccountDifferentSymbols(transaction, symbols, descriptions):
            return "The transaction \(transaction) has a split account plus multiple other tax slip relevant accounts. These accounts have different symbols or descriptions. This does not work, as it is unclear to which symbol the amount booked to the split account should be counted for. Symbols: \(symbols) Descriptions: \(descriptions)"

        }
    } // swiftlint:enable line_length
}
