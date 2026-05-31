//
//  SheetParser.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-05.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//
// swiftlint:disable file_length

import Foundation

/// Errors while reading the sheet
public enum SheetParserError: LocalizedError, Equatable {
    /// The specified column is missing in the sheet
    case missingHeader(String)
    /// The provided value is invalid for this column
    case invalidValue(String)
    /// The value for the provided column is missing
    case missingValue(String)

    public var errorDescription: String? {
        switch self {
        case .missingHeader(message: let message):
            return "\(message)"
        case .invalidValue(message: let message):
            return "\(message)"
        case .missingValue(message: let message):
            return "\(message)"
        }
    }
}

enum SheetParser { // swiftlint:disable:this type_body_length

    enum Payer {
        case one
        case two
    }

    struct TransactionData {
        let date: Date
        let payee: String
        let narration: String
        let category: String
        let amount: Decimal
        let amount1: Decimal
        let amount2: Decimal
        let paidBy: Payer
    }

    struct ParsedData {
        let rows: [SheetCellsFormatter.ParsedRow]
        let runningTotal: Decimal?
        let errors: [SheetParserError]
        let layout: SheetCellsFormatter.Layout?
    }

    private struct ParsedRowsResult {
        let rows: [Result<SheetCellsFormatter.ParsedRow, SheetParserError>]
        let layout: SheetCellsFormatter.Layout?
    }

    /// Resolved column indices for a total amount format sheet.
    ///
    /// Caches all required column positions so that each row can be parsed without
    /// re-scanning the header.
    private struct TotalAmountFormatIndices {
        let date: Int
        let payee: Int
        let amount: Int
        let category: Int
        let payer: Int
        let narration: Int
        let amount1: Int
        let amount2: Int
        let otherPersonName: String
        let maxIndex: Int
    }

    /// Resolved column indices for a share amount format sheet.
    ///
    /// Caches the required column positions, including the `Share Other Person` column,
    /// so that each row can be parsed without re-scanning the header.
    private struct ShareAmountFormatIndices {
        let date: Int
        let payee: Int
        let category: Int
        let payer: Int
        let narration: Int
        let shareOtherPerson: Int
        let maxIndex: Int
    }

    static func parseSheetData(_ data: [[String]], name: String, negateRunningTotal: Bool = false) -> ParsedData {
        var lines = removeEmptyRows(data)
        guard !lines.isEmpty else {
            return ParsedData(rows: [], runningTotal: nil, errors: [], layout: nil)
        }
        let rawHeadings = lines.removeFirst()
        let headings = rawHeadings.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let parsedRows = convertToParsedRows(headings: headings, rawHeadings: rawHeadings, data: lines, name: name)
        var rows = [SheetCellsFormatter.ParsedRow]()
        var errors = [SheetParserError]()
        parsedRows.rows.forEach {
            switch $0 {
            case .success(let row):
                rows.append(row)
            case .failure(let error):
                errors.append(error)
            }
        }
        rows = rows.sorted {
            $0.transactionData.date < $1.transactionData.date
        }
        let runningTotal = extractRunningTotal(headings: headings, data: lines, negate: negateRunningTotal)
        return ParsedData(rows: rows, runningTotal: runningTotal, errors: errors, layout: parsedRows.layout)
    }

    /// Dispatches sheet rows to the appropriate column-format parser.
    ///
    /// Detects the column format by checking for the presence of the `Share Other Person`
    /// header. If found, the share amount format parser is used; otherwise the total amount format
    /// parser is used.
    /// - Parameters:
    ///   - headings: The first row of the sheet, used as column headers.
    ///   - rawHeadings: The original, untrimmed column headers
    ///   - data: The remaining rows of the sheet.
    ///   - name: The ledger owner's name, used to identify which columns belong to which person.
    /// - Returns: ParsedRowsResult containing the parsed rows and the detected layout, or errors if the required headers are missing or any row contains invalid data.
    private static func convertToParsedRows(headings: [String], rawHeadings: [String], data: [[String]], name: String) -> ParsedRowsResult {
        if headings.contains("Share Other Person") {
            return parseRowsShareAmountFormat(headings: headings, rawHeadings: rawHeadings, data: data, name: name)
        }
        return parseRowsTotalAmountFormat(headings: headings, rawHeadings: rawHeadings, data: data, name: name)
    }

    /// Parses all rows of a total amount format sheet into a `ParsedRowsResult`.
    /// - Parameters:
    ///   - headings: Column header row.
    ///   - rawHeadings: The original, untrimmed column headers as they appear in the sheet, used for error messages and layout metadata.
    ///   - data: Data rows (excluding the header row).
    ///   - name: The ledger owner's name.
    /// - Returns: ParsedRowsResult containing the parsed rows and the detected layout, or errors if the required headers are missing or any row contains invalid data.
    private static func parseRowsTotalAmountFormat(headings: [String], rawHeadings: [String], data: [[String]], name: String) -> ParsedRowsResult {
        guard let indices = totalAmountFormatIndices(headings: headings, data: data, name: name) else {
            return ParsedRowsResult(
                rows: [.failure(.missingHeader("Missing Header! Headers: \(headings)"))],
                layout: nil
            )
        }
        let layout = SheetCellsFormatter.Layout(
            format: .totalAmount,
            columns: [
                SheetCellsFormatter.Column(header: rawHeadings[indices.date], index: indices.date, role: .date),
                SheetCellsFormatter.Column(header: rawHeadings[indices.payee], index: indices.payee, role: .payee),
                SheetCellsFormatter.Column(header: rawHeadings[indices.amount], index: indices.amount, role: .amount),
                SheetCellsFormatter.Column(header: rawHeadings[indices.category], index: indices.category, role: .category),
                SheetCellsFormatter.Column(header: rawHeadings[indices.payer], index: indices.payer, role: .payer),
                SheetCellsFormatter.Column(header: rawHeadings[indices.narration], index: indices.narration, role: .narration)
            ].sorted { $0.index < $1.index },
            otherPersonName: indices.otherPersonName
        )
        let rows = data.enumerated().map { index, row in
            parseTotalAmountRow(row, indices: indices, name: name, line: index + 2) // +2 to account for header row and 0-based index
        }
        return ParsedRowsResult(rows: rows, layout: layout)
    }

    /// Resolves column positions for a total amount format sheet.
    ///
    /// Required columns: `Date`, one of `Paid to`/`Payee`, `Amount`, `Category`,
    /// one of `Who paid`/`Payor`, one of `Comment`/`Description`, `Part <name>`,
    /// and `Part <otherPerson>` (the second name is derived from the data rows).
    /// - Parameters:
    ///   - headings: Column header row.
    ///   - data: Data rows, used to infer the second person's name from the payer column.
    ///   - name: The ledger owner's name.
    /// - Returns: Resolved indices, or `nil` if any required column is missing.
    private static func totalAmountFormatIndices(headings: [String], data: [[String]], name: String) -> TotalAmountFormatIndices? {
        guard let dateIndex = headings.firstIndex(of: "Date"),
              let payeeIndex = firstIndex(ofAlternatives: ["Paid to", "Payee"], in: headings),
              let amountIndex = headings.firstIndex(of: "Amount"),
              let categoryIndex = headings.firstIndex(of: "Category"),
              let payerIndex = firstIndex(ofAlternatives: ["Who paid", "Payor"], in: headings),
              let narrationIndex = firstIndex(ofAlternatives: ["Comment", "Description"], in: headings),
              let payer2 = (data.first {
                  $0.count > payerIndex && $0[payerIndex].trimmingCharacters(in: .whitespacesAndNewlines) != name
              })?[payerIndex].trimmingCharacters(in: .whitespacesAndNewlines),
              let amount1Index = headings.firstIndex(of: "Part \(name)"),
              let amount2Index = headings.firstIndex(of: "Part \(payer2)")
        else {
            return nil
        }
        let maxIndex = max(dateIndex, payeeIndex, amountIndex, categoryIndex, payerIndex, narrationIndex, amount1Index, amount2Index)
        return TotalAmountFormatIndices(
            date: dateIndex,
            payee: payeeIndex,
            amount: amountIndex,
            category: categoryIndex,
            payer: payerIndex,
            narration: narrationIndex,
            amount1: amount1Index,
            amount2: amount2Index,
            otherPersonName: payer2,
            maxIndex: maxIndex
        )
    }

    /// Parses a single total amount format row into a `TransactionData` value.
    /// - Parameters:
    ///   - row: The raw string values for one sheet row.
    ///   - indices: Pre-resolved column indices for this sheet.
    ///   - name: The ledger owner's name, used to determine who paid.
    ///   - line: The line number in the sheet (for error reporting).
    /// - Returns: A success with the parsed row, or a failure with a `SheetParserError`
    private static func parseTotalAmountRow(_ row: [String], indices: TotalAmountFormatIndices, name: String, line: Int)
        -> Result<SheetCellsFormatter.ParsedRow, SheetParserError> {
        guard row.count >= indices.maxIndex + 1 else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Missing Value(s) in row: \(row.joined(separator: " "))"))
        }
        guard let date = parseDate(row[indices.date]) else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Invalid Date: \(row[indices.date])"))
        }
        guard let amount = getDecimalFromString(row[indices.amount]) else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Invalid Number: \(row[indices.amount])"))
        }
        guard let amount1 = getDecimalFromString(row[indices.amount1]) else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Invalid Number: \(row[indices.amount1])"))
        }
        guard let amount2 = getDecimalFromString(row[indices.amount2]) else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Invalid Number: \(row[indices.amount2])"))
        }
        let payee = row[indices.payee].trimmingCharacters(in: .whitespacesAndNewlines)
        let narration = row[indices.narration].trimmingCharacters(in: .whitespacesAndNewlines)
        let category = row[indices.category].trimmingCharacters(in: .whitespacesAndNewlines)
        let paidBy: Payer = row[indices.payer].trimmingCharacters(in: .whitespacesAndNewlines) == name ? .one : .two
        let transactionData = TransactionData(
            date: date,
            payee: payee,
            narration: narration,
            category: category,
            amount: amount,
            amount1: amount1,
            amount2: amount2,
            paidBy: paidBy
        )
        return .success(SheetCellsFormatter.ParsedRow(transactionData: transactionData, rawRow: row))
    }

    /// Parses all rows of a share amount format sheet into a `ParsedRowsResult`.
    /// - Parameters:
    ///   - headings: Column header row.
    ///   - rawHeadings: Original column header row as it appears in the sheet.
    ///   - data: Data rows (excluding the header row).
    ///   - name: The ledger owner's name.
    /// - Returns: One result per row.
    private static func parseRowsShareAmountFormat(headings: [String], rawHeadings: [String], data: [[String]], name: String) -> ParsedRowsResult {
        guard let indices = shareAmountFormatIndices(headings: headings) else {
            return ParsedRowsResult(
                rows: [.failure(.missingHeader("Missing Header! Headers: \(headings)"))],
                layout: nil
            )
        }
        let layout = SheetCellsFormatter.Layout(
            format: .shareAmount,
            columns: [
                SheetCellsFormatter.Column(header: rawHeadings[indices.date], index: indices.date, role: .date),
                SheetCellsFormatter.Column(header: rawHeadings[indices.payee], index: indices.payee, role: .payee),
                SheetCellsFormatter.Column(header: rawHeadings[indices.category], index: indices.category, role: .category),
                SheetCellsFormatter.Column(header: rawHeadings[indices.payer], index: indices.payer, role: .payer),
                SheetCellsFormatter.Column(header: rawHeadings[indices.narration], index: indices.narration, role: .narration),
                SheetCellsFormatter.Column(header: rawHeadings[indices.shareOtherPerson], index: indices.shareOtherPerson, role: .shareOtherPerson)
            ].sorted { $0.index < $1.index },
            otherPersonName: otherPersonName(data: data, payerIndex: indices.payer, name: name)
        )
        let rows = data.enumerated().map { index, row in
            parseShareAmountRow(row, indices: indices, name: name, line: index + 2) // +2 to account for header row and 0-based index
        }
        return ParsedRowsResult(rows: rows, layout: layout)
    }

    /// Resolves column positions for a share amount format sheet.
    ///
    /// Required columns: `Date`, one of `Payee`/`Paid to`, `Category`,
    /// one of `Payor`/`Who paid`, one of `Description`/`Comment`,
    /// and `Share Other Person`.
    /// - Parameter headings: Column header row.
    /// - Returns: Resolved indices, or `nil` if any required column is missing.
    private static func shareAmountFormatIndices(headings: [String]) -> ShareAmountFormatIndices? {
        guard let dateIndex = headings.firstIndex(of: "Date"),
              let payeeIndex = firstIndex(ofAlternatives: ["Payee", "Paid to"], in: headings),
              let categoryIndex = headings.firstIndex(of: "Category"),
              let payerIndex = firstIndex(ofAlternatives: ["Payor", "Who paid"], in: headings),
              let narrationIndex = firstIndex(ofAlternatives: ["Description", "Comment"], in: headings),
              let shareOtherPersonIndex = headings.firstIndex(of: "Share Other Person")
        else {
            return nil
        }
        let maxIndex = max(dateIndex, payeeIndex, categoryIndex, payerIndex, narrationIndex, shareOtherPersonIndex)
        return ShareAmountFormatIndices(
            date: dateIndex,
            payee: payeeIndex,
            category: categoryIndex,
            payer: payerIndex,
            narration: narrationIndex,
            shareOtherPerson: shareOtherPersonIndex,
            maxIndex: maxIndex
        )
    }

    /// Parses a single share amount format row into a `ParsedRow` value.
    ///
    /// When the owner paid, the total amount is derived from the equal-split assumption:
    /// `total = 2 × shareOtherPerson`.
    /// - Parameters:
    ///   - row: The raw string values for one sheet row.
    ///   - indices: Pre-resolved column indices for this sheet.
    ///   - name: The ledger owner's name, used to determine who paid.
    ///   - line: The line number in the sheet (for error reporting).
    /// - Returns: A success with the parsed row, or a failure with a `SheetParserError`.
    private static func parseShareAmountRow(_ row: [String], indices: ShareAmountFormatIndices, name: String, line: Int)
        -> Result<SheetCellsFormatter.ParsedRow, SheetParserError> {
        guard row.count >= indices.maxIndex + 1 else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Missing Value(s) in row: \(row.joined(separator: " "))"))
        }
        guard let date = parseDate(row[indices.date]) else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Invalid Date: \(row[indices.date])"))
        }
        guard let shareOtherPerson = getDecimalFromString(row[indices.shareOtherPerson]) else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Invalid Number: \(row[indices.shareOtherPerson])"))
        }
        let payee = row[indices.payee].trimmingCharacters(in: .whitespacesAndNewlines)
        let narration = row[indices.narration].trimmingCharacters(in: .whitespacesAndNewlines)
        let category = row[indices.category].trimmingCharacters(in: .whitespacesAndNewlines)
        let paidBy: Payer = row[indices.payer].trimmingCharacters(in: .whitespacesAndNewlines) == name ? .one : .two
        // When the name person paid, assume an equal split to derive the full amount
        let amount1 = shareOtherPerson
        let amount2: Decimal = paidBy == .one ? shareOtherPerson : 0
        let amount: Decimal = paidBy == .one ? shareOtherPerson * 2 : 0
        let transactionData = TransactionData(
            date: date,
            payee: payee,
            narration: narration,
            category: category,
            amount: amount,
            amount1: amount1,
            amount2: amount2,
            paidBy: paidBy
        )
        return .success(SheetCellsFormatter.ParsedRow(transactionData: transactionData, rawRow: row))
    }

    /// Extracts the most recent running total from a `Running Total` column.
    ///
    /// When `negate` is `true` the extracted value is negated before being returned.
    /// - Parameters:
    ///   - headings: Column header row.
    ///   - data: Data rows (excluding the header row).
    ///   - negate: When `true`, the running total value is negated.
    /// - Returns: The running total (optionally negated), or `nil` if absent or unparseable.
    private static func extractRunningTotal(headings: [String], data: [[String]], negate: Bool) -> Decimal? {
        guard let index = headings.firstIndex(of: "Running Total") else {
            return nil
        }
        return data.reversed().compactMap { $0.count > index ? getDecimalFromString($0[index]) : nil }.first.map { negate ? -$0 : $0 }
    }

    /// Returns the index of the first alternative column name found in the headings.
    ///
    /// Tries each name in `alternatives` in order and returns the index of the first match.
    /// - Parameters:
    ///   - alternatives: Ordered list of acceptable column names to search for.
    ///   - headings: The sheet's column header row.
    /// - Returns: The index of the first matched alternative, or `nil` if none are present.
    private static func firstIndex(ofAlternatives alternatives: [String], in headings: [String]) -> Int? {
        for alternative in alternatives {
            if let index = headings.firstIndex(of: alternative) {
                return index
            }
        }
        return nil
    }

    private static func parseDate(_ string: String) -> Date? {
        let parts = string.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .current
        let dateComponents = DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: day, hour: 0, minute: 0, second: 0)
        return calendar.date(from: dateComponents)
    }

    private static func removeEmptyRows(_ values: [[String]]) -> [[String]] {
        values.filter {
            !$0.allSatisfy {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.trimmingCharacters(in: .whitespacesAndNewlines) == "-"
            }
        }
    }

    private static func getDecimalFromString(_ string: String) -> Decimal? {
        var amountString = string.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        guard !amountString.isEmpty else {
            return nil
        }
        var sign = FloatingPointSign.plus
        // Handle parentheses notation for negative values: "(100.00)"
        if amountString.starts(with: "(") && amountString.last == ")" {
            amountString = String(amountString.dropFirst().dropLast())
            sign = .minus
        }
        // Handle leading minus sign before optional currency prefix: "-CA$30.63" or "-100.00"
        if amountString.starts(with: "-") {
            amountString = String(amountString.dropFirst())
            sign = .minus
        }
        // Strip currency prefix up to and including the first '$': "CA$15.34" -> "15.34"
        if let dollarIndex = amountString.firstIndex(of: "$") {
            amountString = String(amountString[amountString.index(after: dollarIndex)...])
        }
        var exponent = 0
        if let range = amountString.firstIndex(of: ".") {
            let beforeDot = amountString[..<range]
            let afterDot = amountString[amountString.index(range, offsetBy: 1)...]
            amountString = String(beforeDot + afterDot)
            exponent = afterDot.count
        }
        guard let int = UInt64(amountString) else {
            return nil
        }
        return Decimal(sign: sign, exponent: -exponent, significand: Decimal(int))
    }

    private static func otherPersonName(data: [[String]], payerIndex: Int, name: String) -> String? {
        let row = data.first { row in
            guard row.count > payerIndex else {
                return false
            }
            let payer = row[payerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            return !payer.isEmpty && payer != name
        }
        return row?[payerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
