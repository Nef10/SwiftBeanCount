
// swiftlint:disable:next type_body_length

import Foundation
@testable import SwiftBeanCountTax
import SwiftBeanCountModel
import Testing

@Suite
struct TaxSlipTests {

   @Test
   func testExtractInt() {
        #expect(extractInt(from: "123") == 123)
        #expect(extractInt(from: "123abc456") == 123_456)
        #expect(extractInt(from: "abc123def") == 123)
        #expect(extractInt(from: "" == nil))
        #expect(extractInt(from: "abc" == nil))
    }

   @Test
   func testBoxNumberSort() {
        #expect(boxNumberSort("1", "2"))
        #expect(!(boxNumberSort("2", "1")))
        #expect(boxNumberSort("A1", "A2"))
        #expect(!(boxNumberSort("A2", "A1")))
        #expect(boxNumberSort("A1B", "A2B"))
        #expect(!(boxNumberSort("A2B", "A1B")))
        #expect(boxNumberSort("A10", "A20"))
        #expect(!(boxNumberSort("A20", "A10")))
        #expect(boxNumberSort("A10B", "A20B"))
        #expect(!(boxNumberSort("A20B", "A10B")))
        #expect(boxNumberSort("A", "B"))
        #expect(!(boxNumberSort("B", "A")))
        #expect(boxNumberSort("a", "b"))
        #expect(!(boxNumberSort("b", "a")))
    }

   @Test
   func testAddOriginalValues() {
        let amount = Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount
        let entry1 = TaxSlipEntry(symbol: nil, name: nil, box: "1", value: amount, originalValue: nil)
        let entry2 = TaxSlipEntry(symbol: nil, name: nil, box: "2", value: amount, originalValue: Amount(number: Decimal(20), commoditySymbol: "CAD").multiCurrencyAmount)

        // Test case where sum and entry original values are nil
        #expect(addOriginalValues(nil, entry1 == nil))

        // Test case where entry original value is nil but sum has value
        #expect(addOriginalValues(amount == entry1), amount)

        // Test case where entry original value is not nil and sum is nil
        #expect(addOriginalValues(nil == entry2), entry2.originalValue)

        // Test case where entry and sum original values are not nil
        #expect(addOriginalValues(amount == entry2), (amount + entry2.originalValue!))
    }

   @Test
   func testRowValueBoxNumberSort() {
        let rowValue1 = TaxSlipRowValue(box: "BOX1", value: nil, originalValue: nil)
        let rowValue2 = TaxSlipRowValue(box: "BOX2", value: nil, originalValue: nil)
        let rowValue3 = TaxSlipRowValue(box: "BOX3", value: nil, originalValue: nil)

        #expect(rowValueBoxNumberSort(rowValue1, rowValue2))
        #expect(rowValueBoxNumberSort(rowValue1, rowValue3))
        #expect(rowValueBoxNumberSort(rowValue2, rowValue3))

        let rowValue4 = TaxSlipRowValue(box: "BOX1", value: nil, originalValue: nil)
        let rowValue5 = TaxSlipRowValue(box: "BOX10", value: nil, originalValue: nil)

        #expect(rowValueBoxNumberSort(rowValue4, rowValue5))
        #expect(!(rowValueBoxNumberSort(rowValue5, rowValue4)))
    }

   @Test
   func testBoxes() throws {
        let entries = [
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 2", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil)
        ]
        let taxSlip: TaxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        #expect(taxSlip.boxes == ["Box 1", "Box 2"])
    }

   @Test
   func testBoxesNumbers() throws {
        let entries = [
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil)
        ]
        let taxSlip: TaxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        #expect(taxSlip.boxes == ["Box 1", "Box"])
        #expect(taxSlip.boxesWithNumbers == ["Box 1"])
        #expect(taxSlip.boxesWithoutNumbers == ["Box"])
    }

   @Test
   func testSymbols() throws {
        let entries = [
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 2", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 2", value: MultiCurrencyAmount(), originalValue: nil),
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        #expect(taxSlip.symbols == ["A", "B"])
    }

   @Test
   func testEntriesWithAndWithoutSymbol() {
        let entries = [
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 2", value: MultiCurrencyAmount(), originalValue: nil),
            TaxSlipEntry(symbol: nil, name: "Name A", box: "Box 1", value: MultiCurrencyAmount(), originalValue: nil),
        ]
        do { _ = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries; Issue.record("Expected error") } catch { })
    }

   @Test
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
        #expect(rows.count == 2)
        #expect(rows[0].symbol == "A")
        #expect(rows[0].name == "Name A")
        #expect(rows[0].values.count == 2)
        #expect(rows[0].values[0].box == "Box 1")
        #expect(rows[0].values[0].value == amount)
        #expect(rows[0].values[0].originalValue == nil)
        #expect(rows[0].values[1].box == "Box 2")
        #expect(rows[0].values[1].value == amount + amount)
        #expect(rows[0].values[1].originalValue == amount)
        #expect(rows[1].symbol == "B")
        #expect(rows[1].name == "Name B")
        #expect(rows[1].values.count == 2)
        #expect(rows[1].values[0].box == "Box 1")
        #expect(rows[1].values[0].value == amount)
        #expect(rows[1].values[1].originalValue == nil)
        #expect(rows[1].values[1].box == "Box 2")
        #expect(rows[1].values[1].value == MultiCurrencyAmount())
        #expect(rows[1].values[1].originalValue == nil)
        #expect(rows[0].id != rows[1].id)
    }

   @Test
   func testRowsWithoutSymbols() throws {
        let amount = Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount

        let entries = [
            TaxSlipEntry(symbol: nil, name: nil, box: "Box 1", value: amount, originalValue: nil),
            TaxSlipEntry(symbol: nil, name: nil, box: "Box 2", value: amount, originalValue: amount),
            TaxSlipEntry(symbol: nil, name: nil, box: "Box 2", value: amount, originalValue: nil),
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        let rows = taxSlip.rows
        #expect(rows.count == 1)
        #expect(rows[0].symbol == nil)
        #expect(rows[0].name == nil)
        #expect(rows[0].values.count == 2)
        #expect(rows[0].values[0].box == "Box 1")
        #expect(rows[0].values[0].value == amount)
        #expect(rows[0].values[0].originalValue == nil)
        #expect(rows[0].values[1].box == "Box 2")
        #expect(rows[0].values[1].value == amount + amount)
        #expect(rows[0].values[1].originalValue == amount)
    }

   @Test
   func testRowsNumbers() throws {
        let amount = Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount

        let entries = [
            TaxSlipEntry(symbol: nil, name: nil, box: "Box", value: amount, originalValue: nil),
            TaxSlipEntry(symbol: nil, name: nil, box: "Box 1", value: amount, originalValue: amount),
            TaxSlipEntry(symbol: nil, name: nil, box: "Box 1", value: amount, originalValue: nil),
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        var rows = taxSlip.rowsWithBoxNumbers
        #expect(rows.count == 1)
        #expect(rows[0].symbol == nil)
        #expect(rows[0].name == nil)
        #expect(rows[0].values.count == 1)
        #expect(rows[0].values[0].box == "Box 1")
        #expect(rows[0].values[0].value == amount + amount)
        #expect(rows[0].values[0].originalValue == amount)

        rows = taxSlip.rowsWithoutBoxNumbers
        #expect(rows.count == 1)
        #expect(rows[0].symbol == nil)
        #expect(rows[0].name == nil)
        #expect(rows[0].values.count == 1)
        #expect(rows[0].values[0].box == "Box")
        #expect(rows[0].values[0].value == amount)
        #expect(rows[0].values[0].originalValue == nil)
    }

   @Test
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
        #expect(sumRow.symbol == nil)
        #expect(sumRow.name == nil)
        #expect(sumRow.values.count == 2)
        #expect(sumRow.values[0].box == "Box 1")
        #expect(sumRow.values[0].value == amount + amount)
        #expect(sumRow.values[0].originalValue == nil)
        #expect(sumRow.values[1].box == "Box 2")
        #expect(sumRow.values[1].value == amount + amount)
        #expect(sumRow.values[1].originalValue == amount)
    }

   @Test
   func testSumRowsNumbers() throws {
        let amount = Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount

        let entries = [
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box 1", value: amount, originalValue: nil),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box", value: amount, originalValue: amount),
            TaxSlipEntry(symbol: "A", name: "Name A", box: "Box", value: amount, originalValue: nil),
            TaxSlipEntry(symbol: "B", name: "Name B", box: "Box 1", value: amount, originalValue: nil),
        ]
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "Test Issuer", entries: entries)
        var sumRow = taxSlip.sumRowWithBoxNumbers
        #expect(sumRow.symbol == nil)
        #expect(sumRow.name == nil)
        #expect(sumRow.values.count == 1)
        #expect(sumRow.values[0].box == "Box 1")
        #expect(sumRow.values[0].value == amount + amount)
        #expect(sumRow.values[0].originalValue == nil)

        sumRow = taxSlip.sumRowWithoutBoxNumbers
        #expect(sumRow.symbol == nil)
        #expect(sumRow.name == nil)
        #expect(sumRow.values.count == 1)
        #expect(sumRow.values[0].box == "Box")
        #expect(sumRow.values[0].value == amount + amount)
        #expect(sumRow.values[0].originalValue == amount)
    }

   @Test
   func testTaxSlipStrings() throws {
        let taxSlip = try TaxSlip(name: "Test", year: 2_023, issuer: "", entries: [])
        #expect(taxSlip.issuer == nil)
        #expect(taxSlip.title == "Test")
        #expect(taxSlip.header == "Tax Slip Test - Tax year 2023")

        let taxSlip2 = try TaxSlip(name: "Test", year: 2_023, issuer: nil, entries: [])
        #expect(taxSlip2.issuer == nil)
        #expect(taxSlip2.title == "Test")
        #expect(taxSlip2.header == "Tax Slip Test - Tax year 2023")

        let taxSlip3 = try TaxSlip(name: "Test", year: 2_023, issuer: "Bank", entries: [])
        #expect(taxSlip3.issuer == "Bank")
        #expect(taxSlip3.title == "Bank Test")
        #expect(taxSlip3.header == "Bank Test - Tax year 2023")
    }

   @Test
   func testRowValueDescription() {
        let amount1 = Amount(number: Decimal(-10), commoditySymbol: "USD").multiCurrencyAmount
        let amount2 = Amount(number: Decimal(12), commoditySymbol: "CAD").multiCurrencyAmount
        let rowValue = TaxSlipRowValue(box: "Box 2", value: amount1, originalValue: amount2)
        #expect(rowValue.description == "Box 2: 10.00 USD (12.00 CAD)")
    }

   @Test
   func testRowValueDisplayValue() {
        let amount1 = Amount(number: Decimal(-5), commoditySymbol: "EUR").multiCurrencyAmount
        let amount2 = Amount(number: Decimal(8), commoditySymbol: "JPY").multiCurrencyAmount
        let rowValue1 = TaxSlipRowValue(box: "Box 3", value: amount1, originalValue: nil)
        #expect(rowValue1.displayValue == "5.00 EUR")

        let rowValue2 = TaxSlipRowValue(box: "Box 4", value: amount2, originalValue: amount1)
        #expect(rowValue2.displayValue == "8.00 JPY (5.00 EUR)")

        let rowValue3 = TaxSlipRowValue(box: "Box 4", value: nil, originalValue: nil)
        #expect(rowValue3.displayValue == "0.00")
    }

    @Test
    func testRowDisplayName_noSymbolNoName() {
        let row = TaxSlipRow(symbol: nil, name: nil, values: [])
        #expect(row.displayName == nil)
    }

   @Test
   func testRowDisplayName_symbolOnly() {
        let row = TaxSlipRow(symbol: "SYM", name: nil, values: [])
        #expect(row.displayName == "SYM")
    }

   @Test
   func testRowDisplayName_symbolWithName() {
        let row = TaxSlipRow(symbol: "SYM", name: "NAME", values: [])
        #expect(row.displayName == "SYM (NAME)")
    }

   @Test
   func testRowDescription() {
        let rva = TaxSlipRowValue(box: "A", value: Amount(number: Decimal(10), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil)
        let rvb = TaxSlipRowValue(box: "B", value: Amount(number: Decimal(20), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil)
        let rvc = TaxSlipRowValue(box: "C", value: Amount(number: Decimal(30), commoditySymbol: "USD").multiCurrencyAmount, originalValue: nil)

        let row = TaxSlipRow(symbol: "SYM", name: nil, values: [rvc, rva, rvb])
        #expect(row.description == "SYM:\nA: 10.00 USD\nB: 20.00 USD\nC: 30.00 USD")
    }

   @Test
   func testRowDescription_emptyRow() {
        let row = TaxSlipRow(symbol: nil, name: nil, values: [])
        #expect(row.description == "")
    }

   @Test
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
        #expect(taxSlip.description == expectedDescription)
    }

   @Test
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
        #expect(taxSlip.description == expectedDescription)
    }

}
