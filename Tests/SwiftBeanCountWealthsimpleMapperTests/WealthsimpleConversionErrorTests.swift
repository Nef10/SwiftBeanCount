@testable import SwiftBeanCountWealthsimpleMapper
import XCTest

final class WealthsimpleConversionErrorTests: XCTestCase {

    func testWealthsimpleConversionErrorString() {
        XCTAssertEqual(
            "\(WealthsimpleConversionError.missingCommodity("CAD").localizedDescription)",
            "The Commodity CAD was not found in your ledger. Please make sure you add the metadata \"wealthsimple-symbol: \"CAD\"\" to it."
        )
        XCTAssertEqual(
            "\(WealthsimpleConversionError.missingAccount("key-name", "number123", "categoryName").localizedDescription)",
            """
            The categoryName account for account number number123 and key key-name was not found in your ledger. \
            Please make sure you add the metadata \"key-name: \"number123\"\" to it.
            """
        )
        XCTAssertEqual(
            "\(WealthsimpleConversionError.missingWealthsimpleAccount("123ABC").localizedDescription)",
            """
            The account for the wealthsimple account with the number 123ABC was not found in your ledger. \
            Please make sure you add the metadata \"importer-type: \"wealthsimple\" number: \"123ABC\"\" to it.
            """
        )
        XCTAssertEqual(
            "\(WealthsimpleConversionError.unsupportedTransactionType("unsupportedTransactionTypeName").localizedDescription)",
            "Transactions of Type unsupportedTransactionTypeName are currently not yet supported"
        )
        XCTAssertEqual(
            "\(WealthsimpleConversionError.unexpectedDescription("descriptionText").localizedDescription)",
            "Wealthsimple returned an unexpected description for a transaction: descriptionText"
        )
        XCTAssertEqual(
            "\(WealthsimpleConversionError.accountNotFound("123ABCID").localizedDescription)",
            "Wealthsimple returned an element from an account with id 123ABCID which was not found."
        )
        XCTAssertEqual(
            "\(WealthsimpleConversionError.invalidCommoditySymbol("InvalidSymbol:").localizedDescription)",
            "Could not generate account for commodity InvalidSymbol:. For the mapping to work commodity symbols must only contain charaters allowed in account names."
        )
        XCTAssertEqual(
            "\(WealthsimpleConversionError.unexpectedStockSplit("Split ABC on 2022-03-11").localizedDescription)",
            "A stock split happened, but two matching transaction could not be found: Split ABC on 2022-03-11"
        )
    }

}
