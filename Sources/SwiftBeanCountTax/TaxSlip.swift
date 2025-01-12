import Foundation
import SwiftBeanCountModel

/// Extracts a number from a string by removing all non-digits
/// - Parameter string: string to extract the number from
/// - Returns: Int which would be extracted - if the string does not contain any digits, nil
func extractInt(from string: String) -> Int? {
    Int(string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
}

/// For sorting two string based on the number in them
///
/// In case there is not a number is both strings, the strings are compared instead.
/// In case there is a number in one string but not in the other, the string with the number is considered smaller.
///
/// - Parameters:
///   - box1: string 1
///   - box2: string 2
/// - Returns: Bool if the number in string 1 is smaller then the number in string 2
func boxNumberSort(_ box1: String, _ box2: String) -> Bool {
    let number1 = extractInt(from: box1)
    let number2 = extractInt(from: box2)
    if let number1, let number2 {
        return number1 < number2
    }
    if number1 != nil {
        return true
    }
    if number2 != nil {
        return false
    }
    return box1.lowercased() < box2.lowercased()
}

func addOriginalValues(_ sum: MultiCurrencyAmount?, _ entry: TaxSlipEntry) -> MultiCurrencyAmount? {
    if let sum, let originalValue = entry.originalValue {
        return sum + originalValue
    }
    if sum == nil && entry.originalValue == nil {
        return nil
    }
    if sum == nil {
        return entry.originalValue
    }
    return sum
}

/// For sorting two `RowValue`s based on the box number
/// - Parameters:
///   - rowValue1: row value 1
///   - rowValue2: row value 2
/// - Returns: Bool if the nubmer from the box of the first row value is smaller then the second
func rowValueBoxNumberSort(_ rowValue1: TaxSlipRowValue, _ rowValue2: TaxSlipRowValue) -> Bool {
    boxNumberSort(rowValue1.box, rowValue2.box)
}

/// One Row of a `TaxSlip`
public struct TaxSlipRow: Identifiable {
    /// If the slip is split by symbol (e.g. Stock), the symbol
    public let symbol: String?
    /// If the slip is split by symbol (e.g. Stock), the name of it
    public let name: String?
    /// Values in the row
    public let values: [TaxSlipRowValue]
    public let id = UUID()
}

/// A Value on a `TaxSlip`
public struct TaxSlipRowValue: Identifiable {
    /// Box on the tax slip
    public let box: String
    /// The value of this box
    ///
    /// This is converted to the configured currency of the slip, if possible
    public let value: MultiCurrencyAmount?
    /// The value without currency conversion
    public let originalValue: MultiCurrencyAmount?
    public let id = UUID()

    init(box: String, value: MultiCurrencyAmount?, originalValue: MultiCurrencyAmount?) {
        self.box = box
        self.value = value
        self.originalValue = originalValue
    }

    init(box: String, entries: [TaxSlipEntry]) {
        self.init(box: box, value: entries.reduce(MultiCurrencyAmount()) { $0 + $1.value }, originalValue: entries.reduce(nil, addOriginalValues))
    }
}

struct TaxSlipEntry {
    let symbol: String?
    let name: String?
    let box: String
    let value: MultiCurrencyAmount
    let originalValue: MultiCurrencyAmount?

    init(symbol: String?, name: String?, box: String, value: MultiCurrencyAmount, originalValue: MultiCurrencyAmount?) {
        self.symbol = (symbol?.isEmpty ?? true) ? nil : symbol
        self.name = (name?.isEmpty ?? true) ? nil : name
        self.box = box
        self.value = value
        self.originalValue = originalValue
    }
}

/// A Tax Slip
///
/// One slip describes one year for one issuer
public struct TaxSlip: Identifiable {
    /// Name of the slip, e.g. T4
    public let name: String
    /// Tax year the slip is for
    public let year: Int
    /// Issuer, e.g. your bank or employer
    public let issuer: String?
    public let id = UUID()

    private let entries: [TaxSlipEntry]

    /// Boxes which have a value on the slip
    public var boxes: [String] {
        Array(Set(entries.map(\.box))).sorted(by: boxNumberSort)
    }

    /// Boxes with numbers in the name which have a value on the slip
    public var boxesWithNumbers: [String] {
        Array(Set(entries.map(\.box))).filter { extractInt(from: $0) != nil }.sorted(by: boxNumberSort)
    }

    /// Boxes without numbers in the name which have a value on the slip
    public var boxesWithoutNumbers: [String] {
        Array(Set(entries.map(\.box))).filter { extractInt(from: $0) == nil }.sorted(by: boxNumberSort)
    }

    /// If a slip is split by symbols (e.g. stocks), this contains the list of symbols, otherwise is is empty
    public var symbols: [String] {
        Array(Set(entries.compactMap { $0.symbol })).sorted()
    }

    /// Rows on the tax slip
    ///
    /// If the slip is not broken down by symbol, there is only a single row, otherwise one per symbol
    public var rows: [TaxSlipRow] {
        rowFrom(boxes: boxes)
    }

    /// Rows on the tax slip
    ///
    /// Only includes boxes with numbers in the name
    /// If the slip is not broken down by symbol, there is only a single row, otherwise one per symbol
    public var rowsWithBoxNumbers: [TaxSlipRow] {
        rowFrom(boxes: boxesWithNumbers)
    }

    /// Rows on the tax slip
    ///
    /// Only includes boxes without numbers in the name
    /// If the slip is not broken down by symbol, there is only a single row, otherwise one per symbol
    public var rowsWithoutBoxNumbers: [TaxSlipRow] {
        rowFrom(boxes: boxesWithoutNumbers)
    }

    /// Row with the sum of all values per box
    ///
    /// If the slip is broken down by symbol and e.g. for box 1 there is a value for two symbols, the sum row will contain the sum of these values for box 1
    /// In case the slip is not broken down by symbol. this is the same as the row
    public var sumRow: TaxSlipRow {
        sumRowFrom(boxes: boxes)
    }

    /// Row with the sum of all values per box
    ///
    /// Only includes boxes with numbers in the name
    /// If the slip is broken down by symbol and e.g. for box 1 there is a value for two symbols, the sum row will contain the sum of these values for box 1
    /// In case the slip is not broken down by symbol. this is the same as the row
    public var sumRowWithBoxNumbers: TaxSlipRow {
        sumRowFrom(boxes: boxesWithNumbers)
    }

    /// Row with the sum of all values per box
    ///
    /// Only includes boxes without numbers in the name
    /// If the slip is broken down by symbol and e.g. for box 1 there is a value for two symbols, the sum row will contain the sum of these values for box 1
    /// In case the slip is not broken down by symbol. this is the same as the row
    public var sumRowWithoutBoxNumbers: TaxSlipRow {
        sumRowFrom(boxes: boxesWithoutNumbers)
    }

    init(name: String, year: Int, issuer: String?, entries: [TaxSlipEntry]) throws {
        self.name = name
        self.year = year
        self.issuer = (issuer?.isEmpty ?? true) ? nil : issuer
        self.entries = entries
        guard entries.allSatisfy({ $0.symbol == nil }) || entries.allSatisfy({ $0.symbol != nil }) else {
            throw TaxErrors.entriesWithAndWithoutSymbol(name, year, issuer)
        }
    }

    private func rowFrom(boxes: [String]) -> [TaxSlipRow] {
        (symbols.isEmpty ? [nil] as [String?] : symbols).map { symbol in
            let values = boxes.map { box in
                TaxSlipRowValue(box: box, entries: entries.filter { $0.symbol == symbol && $0.box == box })
            }
            return TaxSlipRow(symbol: symbol, name: entries.first { $0.symbol == symbol }!.name, values: values)
        }
    }

    private func sumRowFrom( boxes: [String]) -> TaxSlipRow {
        let values = boxes.map { box in
            TaxSlipRowValue(box: box, entries: entries.filter { $0.box == box })
        }
        return TaxSlipRow(symbol: nil, name: nil, values: values)
    }
}

extension TaxSlipRow: CustomStringConvertible {
    /// Symbol and name for the row if existent
    public var displayName: String? {
        guard let symbol, !symbol.isEmpty else {
            return nil
        }
        if let name, !name.isEmpty {
            return "\(symbol) (\(name))"
        }
        return symbol
    }

    public var description: String {
        "\(displayName != nil ? "\(displayName!):\n" : "")\(values.sorted(by: rowValueBoxNumberSort).map(\.description).joined(separator: "\n") )"
    }
}

extension TaxSlipRowValue: CustomStringConvertible {
    /// Value and original value if existent
    public var displayValue: String {
        "\(value != nil ? value!.string : "0.00")\(originalValue != nil ? " (\(originalValue!.string))" : "")"
    }

    public var description: String {
        "\(box): \(displayValue)".trimmingCharacters(in: .whitespaces)
    }
}

extension TaxSlip: CustomStringConvertible {
    /// Title of the tax slip, the issuer and the name
    public var title: String {
        "\(issuer != nil ? "\(issuer!) " : "")\(name)"
    }

    /// Header for the tax slip, the issuer, name and tax year
    public var header: String {
        "\(issuer ?? "Tax Slip") \(name) - Tax year \(year)"
    }

    public var description: String {
        "\(header)\n\(rows.map(\.description).joined(separator: "\n"))\(symbols.isEmpty ? "" : "\nSum:\n\(sumRow.description)")"
    }
}

extension MultiCurrencyAmount {
    /// String which lists the absolut value of each amount in the MultiCurrencyAmount, separated by +
    ///
    /// E.g. 10.00 CAD + 15.22 USD
    public var string: String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return amounts.map { "\($0.value.isSignMinus ? formatter.string(for: -$0.value)! : formatter.string(for: $0.value)!) \($0.key)" }.joined(separator: " + ")
    }
}
