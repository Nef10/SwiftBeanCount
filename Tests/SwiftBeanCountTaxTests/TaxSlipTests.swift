import SwiftBeanCountModel
@testable import SwiftBeanCountTax
import XCTest

final class TaxSlipTests: XCTestCase {

    func testExtractInt() {
        XCTAssertEqual(extractInt(from: "123"), 123)
        XCTAssertEqual(extractInt(from: "123abc456"), 123_456)
        XCTAssertEqual(extractInt(from: "abc123def"), 123)
        XCTAssertNil(extractInt(from: ""))
        XCTAssertNil(extractInt(from: "abc"))
    }

    func testBoxNumberSort() {
        XCTAssertTrue(boxNumberSort("1", "2"))
        XCTAssertFalse(boxNumberSort("2", "1"))
        XCTAssertTrue(boxNumberSort("A1", "A2"))
        XCTAssertFalse(boxNumberSort("A2", "A1"))
        XCTAssertTrue(boxNumberSort("A1B", "A2B"))
        XCTAssertFalse(boxNumberSort("A2B", "A1B"))
        XCTAssertTrue(boxNumberSort("A10", "A20"))
        XCTAssertFalse(boxNumberSort("A20", "A10"))
        XCTAssertTrue(boxNumberSort("A10B", "A20B"))
        XCTAssertFalse(boxNumberSort("A20B", "A10B"))
        XCTAssertTrue(boxNumberSort("A", "B"))
        XCTAssertFalse(boxNumberSort("B", "A"))
        XCTAssertTrue(boxNumberSort("a", "b"))
        XCTAssertFalse(boxNumberSort("b", "a"))
    }

    func testAddOriginalValues() {
        let amount = Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount
        let entry1 = TaxSlipEntry(symbol: nil, name: nil, box: "1", value: amount, originalValue: nil)
        let entry2 = TaxSlipEntry(symbol: nil, name: nil, box: "2", value: amount, originalValue: Amount(number: Decimal(20), commoditySymbol: "CAD").multiCurrencyAmount)

        // Test case where sum and entry original values are nil
        XCTAssertNil(addOriginalValues(nil, entry1))

        // Test case where entry original value is nil but sum has value
        XCTAssertEqual(addOriginalValues(amount, entry1), amount)

        // Test case where entry original value is not nil and sum is nil
        XCTAssertEqual(addOriginalValues(nil, entry2), entry2.originalValue)

        // Test case where entry and sum original values are not nil
        XCTAssertEqual(addOriginalValues(amount, entry2), (amount + entry2.originalValue!))
    }

    func testRowValueBoxNumberSort() {
        let rowValue1 = TaxSlipRowValue(box: "BOX1", value: nil, originalValue: nil)
        let rowValue2 = TaxSlipRowValue(box: "BOX2", value: nil, originalValue: nil)
        let rowValue3 = TaxSlipRowValue(box: "BOX3", value: nil, originalValue: nil)

        XCTAssertTrue(rowValueBoxNumberSort(rowValue1, rowValue2))
        XCTAssertTrue(rowValueBoxNumberSort(rowValue1, rowValue3))
        XCTAssertTrue(rowValueBoxNumberSort(rowValue2, rowValue3))

        let rowValue4 = TaxSlipRowValue(box: "BOX1", value: nil, originalValue: nil)
        let rowValue5 = TaxSlipRowValue(box: "BOX10", value: nil, originalValue: nil)

        XCTAssertTrue(rowValueBoxNumberSort(rowValue4, rowValue5))
        XCTAssertFalse(rowValueBoxNumberSort(rowValue5, rowValue4))
    }

    func testBoxes() throws {
        let entries = [
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 2", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil)
        ]
        let taxSlip: TaxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        XCTAssertEqual(taxSlip.boxes, ["Box 1", "Box 2"])
    }

    func testSymbols() throws {
        let entries = [
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 2", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 2", value: MultiCurrencyAmount(), originalValue: nil),
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        XCTAssertEqual(taxSlip.symbols, ["A", "B"])
    }

    func testEntriesWithAndWithoutSymbol() {
        let entries = [
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 2", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: nil, name: "Name A", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil),
        ]
        XCTAssertThrowsError(try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries))
    }

    func testRows() throws {
        let amount = Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount

        let entries = [
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 1", value: amount, originalValue: nil),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 2", value: amount, originalValue: amount),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 2", value: amount, originalValue: nil),
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 1", value: amount, originalValue: nil),
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        let rows = taxSlip.rows
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].symbol, "A")
        XCTAssertEqual(rows[0].name, "Name A")
        XCTAssertEqual(rows[0].values.count, 2)
        XCTAssertEqual(rows[0].values[0].box, "Box 1")
        XCTAssertEqual(rows[0].values[0].value, amount)
        XCTAssertNil(rows[0].values[0].originalValue)
        XCTAssertEqual(rows[0].values[1].box, "Box 2")
        XCTAssertEqual(rows[0].values[1].value, amount + amount)
        XCTAssertEqual(rows[0].values[1].originalValue, amount)
        XCTAssertEqual(rows[1].symbol, "B")
        XCTAssertEqual(rows[1].name, "Name B")
        XCTAssertEqual(rows[1].values.count, 2)
        XCTAssertEqual(rows[1].values[0].box, "Box 1")
        XCTAssertEqual(rows[1].values[0].value, amount)
        XCTAssertNil(rows[1].values[1].originalValue)
        XCTAssertEqual(rows[1].values[1].box, "Box 2")
        XCTAssertEqual(rows[1].values[1].value, MultiCurrencyAmount())
        XCTAssertNil(rows[1].values[1].originalValue)
        XCTAssertNotEqual(rows[0].id, rows[1].id)
    }

    func testRowsWithoutSymbols() throws {
        let amount = Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount

        let entries = [
            TaxSlipEntry(symbol: nil, name: nil, box: "Box 1", value: amount, originalValue: nil),
            TaxSlipEntry(symbol: nil, name: nil, box: "Box 2", value: amount, originalValue: amount),
            TaxSlipEntry(symbol: nil, name: nil, box: "Box 2", value: amount, originalValue: nil),
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        let rows = taxSlip.rows
        XCTAssertEqual(rows.count, 1)
        XCTAssertNil(rows[0].symbol)
        XCTAssertNil(rows[0].name)
        XCTAssertEqual(rows[0].values.count, 2)
        XCTAssertEqual(rows[0].values[0].box, "Box 1")
        XCTAssertEqual(rows[0].values[0].value, amount)
        XCTAssertNil(rows[0].values[0].originalValue)
        XCTAssertEqual(rows[0].values[1].box, "Box 2")
        XCTAssertEqual(rows[0].values[1].value, amount + amount)
        XCTAssertEqual(rows[0].values[1].originalValue, amount)
    }

    func testSumRows() throws {
        let amount = Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount

        let entries = [
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 1", value: amount, originalValue: nil),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 2", value: amount, originalValue: amount),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 2", value: amount, originalValue: nil),
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 1", value: amount, originalValue: nil),
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        let sumRow = taxSlip.sumRow
        XCTAssertNil(sumRow.symbol)
        XCTAssertNil(sumRow.name)
        XCTAssertEqual(sumRow.values.count, 2)
        XCTAssertEqual(sumRow.values[0].box, "Box 1")
        XCTAssertEqual(sumRow.values[0].value, amount + amount)
        XCTAssertNil(sumRow.values[0].originalValue)
        XCTAssertEqual(sumRow.values[1].box, "Box 2")
        XCTAssertEqual(sumRow.values[1].value, amount + amount)
        XCTAssertEqual(sumRow.values[1].originalValue, amount)
    }

    func testTaxSlipStrings() throws {
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "", entries: [])
        XCTAssertNil(taxSlip.issuer)
        XCTAssertEqual(taxSlip.title, "Test")
        XCTAssertEqual(taxSlip.header, "Tax Slip Test - Tax year 2023")

        let taxSlip2 = try TaxSlip(name: "Test", year: 2_023, issuer: nil, entries: [])
        XCTAssertNil(taxSlip2.issuer)
        XCTAssertEqual(taxSlip2.title, "Test")
        XCTAssertEqual(taxSlip2.header, "Tax Slip Test - Tax year 2023")

        let taxSlip3 = try TaxSlip(name: "Test", year: 2_023, issuer: "Bank", entries: [])
        XCTAssertEqual(taxSlip3.issuer, "Bank")
        XCTAssertEqual(taxSlip3.title, "Bank Test")
        XCTAssertEqual(taxSlip3.header, "Bank Test - Tax year 2023")
    }

    func testRowValueDescription() {
        let amount1 = Amount(number: Decimal(-10), commoditySymbol: "USD").multiCurrencyAmount
        let amount2 = Amount(number: Decimal(12), commoditySymbol: "CAD").multiCurrencyAmount
        let rowValue = TaxSlipRowValue(box: "Box 2", value: amount1, originalValue: amount2)
        XCTAssertEqual(rowValue.description, "Box 2: 10.00 USD (12.00 CAD)")
    }

    func testRowValueDisplayValue() {
        let amount1 = Amount(number: Decimal(-5), commoditySymbol: "EUR").multiCurrencyAmount
        let amount2 = Amount(number: Decimal(8), commoditySymbol: "JPY").multiCurrencyAmount
        let rowValue1 = TaxSlipRowValue(box: "Box 3", value: amount1, originalValue: nil)
        XCTAssertEqual(rowValue1.displayValue, "5.00 EUR")

        let rowValue2 = TaxSlipRowValue(box: "Box 4", value: amount2, originalValue: amount1)
        XCTAssertEqual(rowValue2.displayValue, "8.00 JPY (5.00 EUR)")

        let rowValue3 = TaxSlipRowValue(box: "Box 4", value: nil, originalValue: nil)
        XCTAssertEqual(rowValue3.displayValue, "0.00")
    }

     func testRowDisplayName_noSymbolNoName() {
        let row = TaxSlipRow(symbol: nil, name: nil, values: [])
        XCTAssertNil(row.displayName)
    }

    func testRowDisplayName_symbolOnly() {
        let row = TaxSlipRow(symbol: "SYM", name: nil, values: [])
        XCTAssertEqual(row.displayName, "SYM")
    }

    func testRowDisplayName_symbolWithName() {
        let row = TaxSlipRow(symbol: "SYM", name: "NAME", values: [])
        XCTAssertEqual(row.displayName, "SYM (NAME)")
    }

    func testRowDescription() {
        let rva = TaxSlipRowValue(box: "A", value: Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil)
        let rvb = TaxSlipRowValue(box: "B", value: Amount(number: Decimal(20), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil)
        let rvc = TaxSlipRowValue(box: "C", value: Amount(number: Decimal(30), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil)

        let row = TaxSlipRow(symbol: "SYM", name: nil, values: [rvc, rva, rvb])
        XCTAssertEqual(row.description, "SYM:\nA: 10.00 USD\nB: 20.00 USD\nC: 30.00 USD")
    }

    func testRowDescription_emptyRow() {
        let row = TaxSlipRow(symbol: nil, name: nil, values: [])
        XCTAssertEqual(row.description, "")
    }

    func testTaxSlipDescriptionWithSymbold() throws {
        let entries = [
            TaxSlipEntry(symbol: "Sym1", name: "Name1", box: "101", value: Amount(number: Decimal(1_234.56), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil),
            TaxSlipEntry(symbol: "Sym1", name: "Name1", box: "102", value: Amount(number: Decimal(5_678.90), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil),
            TaxSlipEntry(symbol: "Sym2", name: "Name2", box: "201", value: Amount(number: Decimal(2_468.10), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil)
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_022, issuer: "Test Inc.", entries: entries)

        let expectedDescription = """
            Test Inc. Test - Tax year 2022
            Sym1 (Name1):
            101: 1234.56 USD
            102: 5678.90 USD
            201:
            Sym2 (Name2):
            101:
            102:
            201: 2468.10 USD
            Sum:
            101: 1234.56 USD
            102: 5678.90 USD
            201: 2468.10 USD
            """
        XCTAssertEqual(taxSlip.description, expectedDescription)
    }

    func testTaxSlipDescriptionWithoutSymbols() throws {
        let entries = [
            TaxSlipEntry(symbol: nil, name: nil, box: "101", value: Amount(number: Decimal(1_234.56), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil),
            TaxSlipEntry(symbol: nil, name: nil, box: "102", value: Amount(number: Decimal(5_678.90), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil),
            TaxSlipEntry(symbol: nil, name: nil, box: "201", value: Amount(number: Decimal(2_468.10), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil)
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_022, issuer: "Test Inc.", entries: entries)

        let expectedDescription = """
            Test Inc. Test - Tax year 2022
            101: 1234.56 USD
            102: 5678.90 USD
            201: 2468.10 USD
            """
        XCTAssertEqual(taxSlip.description, expectedDescription)
    }

}
