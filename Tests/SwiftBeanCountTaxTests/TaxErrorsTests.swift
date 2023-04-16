@testable import SwiftBeanCountTax
import XCTest

final class TaxErrorsTests: XCTestCase { // swiftlint:disable line_length

    func testEntriesWithAndWithoutSymbolErrorDescription() {
        let error = TaxErrors.entriesWithAndWithoutSymbol("T4", 2_022, "CRA")
        let expectedDescription = "The 2022 tax slip T4 for CRA has postings with and without symbol. A tax slip can either be split by symbol or not, but not both.\nPlease ensure all accounts have either have one or all have no symbol configured. If your accounts last or second last leg is a commodity symbol, this will be used as fallback in case no explicit symbol is configured. To override it to no symbol in such case, add the tax-symbol meta data with an empty string to your account"
        XCTAssertEqual(error.localizedDescription, expectedDescription)
    }

    func testNoTaxSlipConfiguredErrorDescription() {
        let error = TaxErrors.noTaxSlipConfigured(2_022)
        let expectedDescription = "There was no configured tax slip found for year 2022.\n\nMake sure your ledger contains a custom directive like this: YYYY-MM-DD custom \"tax-slip-settings\" \"slip-names\" \"tax-slip-name1\" \"tax-slip-name2\"\n\nAdditionally, check that the date is in or before the tax year you are tring to generate slips for."
        XCTAssertEqual(error.localizedDescription, expectedDescription)
    }

    func testNoCurrencyDefinedErrorDescription() {
        let error = TaxErrors.noCurrencyDefined("T5", 2_022)
        let expectedDescription = "There was no currency for tax slip T5 in year 2022 found.\n\nMake sure your ledger contains a custom directive like this: YYYY-MM-DD custom \"tax-slip-settings\" \"slip-currency\" \"tax-slip-name\" \"currencySymbol\"\n\nAdditionally, check that the date is in or before the tax year you are tring to generate slips for."
        XCTAssertEqual(error.localizedDescription, expectedDescription)
    }

} // swiftlint:enable line_length
