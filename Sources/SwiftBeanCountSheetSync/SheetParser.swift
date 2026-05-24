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

enum SheetParser {

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

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    static func parseSheet(_ data: ([[String]]), name: String, negateRunningTotal: Bool = false, completion: ([TransactionData], Decimal?, [SheetParserError]) -> Void) {
        var lines = removeEmptyRows(data)
        guard !lines.isEmpty else {
            completion([], nil, [])
            return
        }
        let headings = lines.removeFirst().map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var transactionData = [TransactionData]()
        var errors = [SheetParserError]()
        convertToTransactionData(headings: headings, data: lines, name: name).forEach {
            switch $0 {
            case .success(let transaction):
                transactionData.append(transaction)
            case .failure(let error):
                errors.append(error)
            }
        }
        transactionData = transactionData.sorted {
            $0.date < $1.date
        }
        let runningTotal = extractRunningTotal(headings: headings, data: lines, negate: negateRunningTotal)
        completion(transactionData, runningTotal, errors)
    }

    /// Dispatches sheet rows to the appropriate column-format parser.
    ///
    /// Detects the column format by checking for the presence of the `Share Other Person`
    /// header. If found, the share amount format parser is used; otherwise the total amount format
    /// parser is used. This detection is independent of whether the sheet covers one month
    /// or many months.
    /// - Parameters:
    ///   - headings: The first row of the sheet, used as column headers.
    ///   - data: The remaining rows of the sheet.
    ///   - name: The ledger owner's name, used to identify which columns belong to which person.
    /// - Returns: One result per row; failures carry a `SheetParserError`.
    private static func convertToTransactionData(headings: [String], data: [[String]], name: String) -> [Result<TransactionData, SheetParserError>] {
        if headings.contains("Share Other Person") {
            return convertToTransactionDataShareAmountFormat(headings: headings, data: data, name: name)
        }
        return convertToTransactionDataTotalAmountFormat(headings: headings, data: data, name: name)
    }

    /// Parses all rows of a total amount format sheet into `TransactionData` values.
    /// - Parameters:
    ///   - headings: Column header row.
    ///   - data: Data rows (excluding the header row).
    ///   - name: The ledger owner's name.
    /// - Returns: One result per row.
    private static func convertToTransactionDataTotalAmountFormat(headings: [String], data: [[String]], name: String) -> [Result<TransactionData, SheetParserError>] {
        guard let indices = totalAmountFormatIndices(headings: headings, data: data, name: name) else {
            return [.failure(.missingHeader("Missing Header! Headers: \(headings)"))]
        }
        return data.enumerated().map { index, row in
            parseTotalAmountFormatRow(row, indices: indices, name: name, line: index + 2) // +2 to account for header row and 0-based index
        }
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
    /// - Returns: A success with the parsed data, or a failure with a `SheetParserError`.
    private static func parseTotalAmountFormatRow(_ row: [String], indices: TotalAmountFormatIndices, name: String, line: Int) -> Result<TransactionData, SheetParserError> {
        guard row.count >= indices.maxIndex + 1 else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Missing Value(s) in row: \(row.joined(separator: " "))"))
        }
        guard let date = dateFormatter.date(from: row[indices.date].trimmingCharacters(in: .whitespacesAndNewlines)) else {
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
        return .success(TransactionData(
            date: date,
            payee: payee,
            narration: narration,
            category: category,
            amount: amount,
            amount1: amount1,
            amount2: amount2,
            paidBy: paidBy
        ))
    }

    /// Parses all rows of a share amount format sheet into `TransactionData` values.
    /// - Parameters:
    ///   - headings: Column header row.
    ///   - data: Data rows (excluding the header row).
    ///   - name: The ledger owner's name.
    /// - Returns: One result per row.
    private static func convertToTransactionDataShareAmountFormat(headings: [String], data: [[String]], name: String) -> [Result<TransactionData, SheetParserError>] {
        guard let indices = shareAmountFormatIndices(headings: headings) else {
            return [.failure(.missingHeader("Missing Header! Headers: \(headings)"))]
        }
        return data.enumerated().map { index, row in
            parseShareAmountFormatRow(row, indices: indices, name: name, line: index + 2) // +2 to account for header row and 0-based index
        }
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

    /// Parses a single share amount format row into a `TransactionData` value.
    ///
    /// When the owner paid, the total amount is derived from the equal-split assumption:
    /// `total = 2 × shareOtherPerson`.
    /// - Parameters:
    ///   - row: The raw string values for one sheet row.
    ///   - indices: Pre-resolved column indices for this sheet.
    ///   - name: The ledger owner's name, used to determine who paid.
    /// - Returns: A success with the parsed data, or a failure with a `SheetParserError`.
    private static func parseShareAmountFormatRow(_ row: [String], indices: ShareAmountFormatIndices, name: String, line: Int) -> Result<TransactionData, SheetParserError> {
        guard row.count >= indices.maxIndex + 1 else {
            return .failure(.invalidValue("Line \(line): Parsing Error! Missing Value(s) in row: \(row.joined(separator: " "))"))
        }
        guard let date = dateFormatter.date(from: row[indices.date].trimmingCharacters(in: .whitespacesAndNewlines)) else {
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
        return .success(TransactionData(
            date: date,
            payee: payee,
            narration: narration,
            category: category,
            amount: amount,
            amount1: amount1,
            amount2: amount2,
            paidBy: paidBy
        ))
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

}
