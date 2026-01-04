//
//  SheetParser.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-05.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

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

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    static func parseSheet(_ data: ([[String]]), name: String, completion: ([TransactionData], [SheetParserError]) -> Void) {
        var lines = removeEmptyRows(data)
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
        completion(transactionData, errors)
    }

    private static func convertToTransactionData(headings: [String], data: [[String]], name: String) -> [Result<TransactionData, SheetParserError>] {
        guard let dateIndex = headings.firstIndex(of: "Date"), let payeeIndex = headings.firstIndex(of: "Paid to"),
            let amountIndex = headings.firstIndex(of: "Amount"), let categoryIndex = headings.firstIndex(of: "Category"),
            let payerIndex = headings.firstIndex(of: "Who paid"), let narrationIndex = headings.firstIndex(of: "Comment"),
            let payer2 = (data.first { $0[payerIndex] != name })?[payerIndex], let amount1Index = headings.firstIndex(of: "Part \(name)"),
            let amount2Index = headings.firstIndex(of: "Part \(payer2)") else {
            return [.failure(.missingHeader("Missing Header! Headers: \(headings)"))]
        }
        let maxIndex = max(dateIndex, payeeIndex, amountIndex, categoryIndex, payerIndex, narrationIndex, amount1Index, amount2Index)
        return data.map { row -> (Result<TransactionData, SheetParserError>) in
            guard row.count >= maxIndex + 1 else {
                return .failure(.invalidValue("Parsing Error! Missing Value(s) in row: \(row.joined(separator: " "))"))
            }
            guard let date = dateFormatter.date(from: row[dateIndex]) else {
                return .failure(.invalidValue("Parsing Error! Invalid Date: \(row[dateIndex])"))
            }
            guard let amount = getDecimalFromString(row[amountIndex]) else {
                return .failure(.invalidValue("Parsing Error! Invalid Number: \(row[amountIndex])"))
            }
            guard let amount1 = getDecimalFromString(row[amount1Index]) else {
                return .failure(.invalidValue("Parsing Error! Invalid Number: \(row[amount1Index])"))
            }
            guard let amount2 = getDecimalFromString(row[amount2Index]) else {
                return .failure(.invalidValue("Parsing Error! Invalid Number: \(row[amount2Index])"))
            }
            let payee = row[payeeIndex], narration = row[narrationIndex], category = row[categoryIndex]
            let payedBy: Payer = row[payerIndex] == name ? .one : .two
            let data = TransactionData(date: date, payee: payee, narration: narration, category: category, amount: amount, amount1: amount1, amount2: amount2, paidBy: payedBy)
            return .success(data)
        }
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
        if amountString.starts(with: "(") && amountString.last == ")" {
            amountString = String(amountString.dropFirst().dropLast())
            sign = .minus
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
