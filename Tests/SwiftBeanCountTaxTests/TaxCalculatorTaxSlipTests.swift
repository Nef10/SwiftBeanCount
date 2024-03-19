import SwiftBeanCountModel
@testable import SwiftBeanCountTax
import XCTest

final class TaxCalculatorTaxSlipTests: XCTestCase {

    func testGenerateTaxSlips() throws {
        let ledger = try basicLedger()

        // Calculate tax slips
        let taxSlips = try TaxCalculator.generateTaxSlips(from: ledger, for: 2_022)

        // Check the generated tax slips
        XCTAssertEqual(taxSlips.count, 2)

        // Check tax slip 1
        let taxSlip1 = taxSlips[0]
        XCTAssertEqual(taxSlip1.name, "Taxslip1")
        XCTAssertEqual(taxSlip1.issuer, "Issuer 1")
        XCTAssertEqual(taxSlip1.year, 2_022)
        XCTAssertEqual(taxSlip1.boxes.count, 2)
        XCTAssertEqual(taxSlip1.rows.count, 1)

        // Check row in tax slip 1
        let row1 = taxSlip1.rows[0]
        XCTAssertNil(row1.symbol)
        XCTAssertNil(row1.name)

        // Check tax box 1 in tax slip 1
        XCTAssertEqual(row1.values[0].box, "TaxBox1")
        XCTAssertEqual(row1.values[0].value, Amount(number: 100, commoditySymbol: "USD").multiCurrencyAmount)

        // Check tax box 2 in tax slip 1
        XCTAssertEqual(row1.values[1].box, "TaxBox2")
        XCTAssertEqual(row1.values[1].value, Amount(number: 50, commoditySymbol: "USD").multiCurrencyAmount)

        // Check tax slip 2
        let taxSlip2 = taxSlips[1]
        XCTAssertEqual(taxSlip2.name, "Taxslip2")
        XCTAssertNil(taxSlip2.issuer)
        XCTAssertEqual(taxSlip2.year, 2_022)
        XCTAssertEqual(taxSlip2.boxes.count, 1)
        XCTAssertEqual(taxSlip2.rows.count, 1)

        // Check row in tax slip 2
        let row2 = taxSlip2.rows[0]
        XCTAssertNil(row2.symbol)
        XCTAssertNil(row2.name)

        // Check tax box 1 in tax slip 2
        XCTAssertEqual(row2.values[0].box, "TaxBox1")
        XCTAssertEqual(row2.values[0].value, Amount(number: 150, commoditySymbol: "EUR").multiCurrencyAmount)

        // No tax slips
        XCTAssertThrowsError(try TaxCalculator.generateTaxSlips(from: ledger, for: 2_020))

        // No tax slip currency
        XCTAssertThrowsError(try TaxCalculator.generateTaxSlips(from: ledger, for: 2_021))
    }

    func testGenerateTaxSlipsWithSymbol() throws {
        let taxSlips = try TaxCalculator.generateTaxSlips(from: try symbolLedger(), for: 2_022)
        XCTAssertEqual(taxSlips.count, 2)

        // Check tax slip 1
        let taxSlip1 = taxSlips[0]
        XCTAssertEqual(taxSlip1.name, "Taxslip1")
        XCTAssertEqual(taxSlip1.boxes.count, 2)
        XCTAssertEqual(taxSlip1.rows.count, 2)

        // Check row 1 in tax slip 1
        let row1 = taxSlip1.rows[0]
        XCTAssertEqual(row1.symbol, "SYM")
        XCTAssertNil(row1.name)

        // Check tax box 1 in row 1 in tax slip 1
        XCTAssertEqual(row1.values[0].box, "TaxBox1")
        XCTAssertEqual(row1.values[0].value, Amount(number: 100, commoditySymbol: "USD").multiCurrencyAmount)

        // Check tax box 2 in row 1 in tax slip 1
        XCTAssertEqual(row1.values[1].box, "TaxBox2")
        XCTAssertEqual(row1.values[1].value, MultiCurrencyAmount())

        // Check row 2 in tax slip 1
        let row2 = taxSlip1.rows[1]
        XCTAssertEqual(row2.symbol, "SYMB")
        XCTAssertEqual(row2.name, "DescB")

        // Check tax box 1 in row 2 tax slip 1
        XCTAssertEqual(row2.values[0].box, "TaxBox1")
        XCTAssertEqual(row2.values[0].value, MultiCurrencyAmount())

        // Check tax box 2 in row 2 tax slip 1
        XCTAssertEqual(row2.values[1].box, "TaxBox2")
        XCTAssertEqual(row2.values[1].value, Amount(number: 50, commoditySymbol: "USD").multiCurrencyAmount)

        // Check tax slip 2
        let taxSlip2 = taxSlips[1]
        XCTAssertEqual(taxSlip2.name, "Taxslip2")
        XCTAssertEqual(taxSlip2.boxes.count, 1)
        XCTAssertEqual(taxSlip2.rows.count, 1)

        // Check row 1 in tax slip 2
        let row3 = taxSlip2.rows[0]
        XCTAssertEqual(row3.symbol, "SYMBO")
        XCTAssertEqual(row3.name, "Desc")

        // Check tax box 1 in tax slip 2
        XCTAssertEqual(row3.values[0].box, "TaxBox1")
        XCTAssertEqual(row3.values[0].value, Amount(number: 150, commoditySymbol: "EUR").multiCurrencyAmount)
    }

    func testGenerateTaxSlipWithDifferentCurrencies() throws {

        let ledger = try currencyLedger()

        // Calculate tax slips
        let taxSlips = try TaxCalculator.generateTaxSlips(from: ledger, for: 2_022)

        // Check the generated tax slip
        XCTAssertEqual(taxSlips.count, 1)

        // Check tax slip 1
        let taxSlip = taxSlips[0]
        XCTAssertEqual(taxSlip.name, "Taxslip1")
        XCTAssertEqual(taxSlip.year, 2_022)
        XCTAssertEqual(taxSlip.boxes.count, 1)
        XCTAssertEqual(taxSlip.rows.count, 1)

        // Check row in tax slip 1
        let row1 = taxSlip.rows[0]
        XCTAssertNil(row1.symbol)
        XCTAssertNil(row1.name)

        // Check tax box 1 in tax slip 1
        XCTAssertEqual(row1.values[0].box, "TaxBox1")
        XCTAssertEqual(
            row1.values[0].value,
            (Amount(number: 637.50, commoditySymbol: "USD").multiCurrencyAmount +
            Amount(number: 50, commoditySymbol: "JPY").multiCurrencyAmount)
        )
        XCTAssertEqual(
            row1.values[0].originalValue,
            (Amount(number: 100, commoditySymbol: "USD").multiCurrencyAmount +
            Amount(number: 50, commoditySymbol: "JPY").multiCurrencyAmount +
            Amount(number: 200, commoditySymbol: "EUR").multiCurrencyAmount +
            Amount(number: 150, commoditySymbol: "CAD").multiCurrencyAmount)
        )
    }

    func testGenerateTaxSlipsWithSplitAccounts() throws {
        let taxSlips = try TaxCalculator.generateTaxSlips(from: splitAccountLedger(), for: 2_022)

        // Check the generated tax slips
        XCTAssertEqual(taxSlips.count, 2)

        // Check tax slip 1
        let taxSlip1 = taxSlips[0]
        XCTAssertEqual(taxSlip1.name, "Taxslip1")
        XCTAssertEqual(taxSlip1.issuer, "Issuer 1")
        XCTAssertEqual(taxSlip1.year, 2_022)
        XCTAssertEqual(taxSlip1.boxes.count, 3)
        XCTAssertEqual(taxSlip1.rows.count, 1)

        // Check row in tax slip 1
        let row1 = taxSlip1.rows[0]
        XCTAssertNil(row1.symbol)
        XCTAssertNil(row1.name)

        // Check tax box 1 in tax slip 1
        XCTAssertEqual(row1.values[0].box, "TaxBox1")
        XCTAssertEqual(row1.values[0].value, Amount(number: 128, commoditySymbol: "USD").multiCurrencyAmount)

        // Check tax box 2 in tax slip 1
        XCTAssertEqual(row1.values[1].box, "TaxBox2")
        XCTAssertEqual(row1.values[1].value, Amount(number: 50, commoditySymbol: "USD").multiCurrencyAmount)

        // Check tax box 3 in tax slip 1
        XCTAssertEqual(row1.values[2].box, "SplitBox3")
        XCTAssertEqual(row1.values[2].value, Amount(number: -112, commoditySymbol: "USD").multiCurrencyAmount)

        // Check tax slip 2
        let taxSlip2 = taxSlips[1]
        XCTAssertEqual(taxSlip2.name, "Taxslip2")
        XCTAssertNil(taxSlip2.issuer)
        XCTAssertEqual(taxSlip2.year, 2_022)
        XCTAssertEqual(taxSlip2.boxes.count, 1)
        XCTAssertEqual(taxSlip2.rows.count, 1)

        // Check row in tax slip 2
        let row2 = taxSlip2.rows[0]
        XCTAssertNil(row2.symbol)
        XCTAssertNil(row2.name)

        // Check tax box 1 in tax slip 2
        XCTAssertEqual(row2.values[0].box, "TaxBox1")
        XCTAssertEqual(row2.values[0].value, Amount(number: 150, commoditySymbol: "EUR").multiCurrencyAmount)
    }
}
