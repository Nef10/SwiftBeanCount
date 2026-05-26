//
//  SheetCellsFormatter.swift
//  SwiftBeanCountSheetSync
//
//  Created by GitHub Copilot.
//

import Foundation
import SwiftBeanCountModel

enum SheetCellsFormatter {

    enum Format {
        case totalAmount
        case shareAmount
    }

    enum ColumnRole {
        case date
        case payee
        case amount
        case category
        case payer
        case narration
        case shareOtherPerson
    }

    struct Column {
        let header: String
        let index: Int
        let role: ColumnRole
    }

    struct Layout {
        let format: Format
        let columns: [Column]
        let otherPersonName: String?

        var headers: [String] {
            columns.map(\.header)
        }
    }

    struct ParsedRow {
        let transactionData: SheetParser.TransactionData
        let rawRow: [String]
    }

    struct MappedRow {
        let transaction: Transaction
        let rawRow: [String]
    }

    struct UploadResult {
        let transactions: [Transaction]
        let sheetCells: [[String]]
        let errors: [SheetParserError]
    }
}

#if os(macOS) || os(iOS)

extension SheetCellsFormatter {

    private static let sheetDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func buildDownloadSheetCells(layout: Layout?, rows: [MappedRow]) -> [[String]] {
        guard let layout else {
            return []
        }
        return [layout.headers] + rows.map { projectedRow($0.rawRow, layout: layout) }
    }

    static func buildUploadSheetCells(
        syncer: GenericSyncer,
        layout: Layout?,
        transactions: [Transaction],
        ledgerSettings: LedgerSettings
    ) throws -> UploadResult {
        guard let layout else {
            throw SyncError.missingSheetLayout
        }
        var rows = [[String]]()
        var formattedTransactions = [Transaction]()
        var errors = [SheetParserError]()
        formattedTransactions.reserveCapacity(transactions.count)
        rows.reserveCapacity(transactions.count + 1)
        rows.append(layout.headers)
        for transaction in transactions {
            do {
                rows.append(try renderedRow(syncer: syncer, for: transaction, layout: layout, ledgerSettings: ledgerSettings))
                formattedTransactions.append(transaction)
            } catch {
                errors.append(uploadError(for: transaction, error: error))
            }
        }
        return UploadResult(transactions: formattedTransactions, sheetCells: rows, errors: errors)
    }

    private static func projectedRow(_ rawRow: [String], layout: Layout) -> [String] {
        layout.columns.map { column in
            rawRow.count > column.index ? rawRow[column.index] : ""
        }
    }

    private static func uploadError(for transaction: Transaction, error: Error) -> SheetParserError {
        let transactionIdentifier = "\(sheetDateFormatter.string(from: transaction.metaData.date)) \(transaction.metaData.payee)"
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        return .invalidValue("Upload transaction \(transactionIdentifier) failed: \(message)")
    }

    private static func renderedRow(
        syncer: GenericSyncer,
        for transaction: Transaction,
        layout: Layout,
        ledgerSettings: LedgerSettings
    ) throws -> [String] {
        let values = try renderedValues(syncer: syncer, for: transaction, layout: layout, ledgerSettings: ledgerSettings)
        return layout.columns.map { values[$0.role, default: ""] }
    }

    private static func renderedValues(
        syncer: GenericSyncer,
        for transaction: Transaction,
        layout: Layout,
        ledgerSettings: LedgerSettings
    ) throws -> [ColumnRole: String] {
        let baseValues = try baseValues(syncer: syncer, for: transaction, layout: layout, ledgerSettings: ledgerSettings)
        let specificValues = try formatSpecificValues(syncer: syncer, for: transaction, layout: layout, ledgerSettings: ledgerSettings)
        return baseValues.merging(specificValues) { current, _ in current }
    }

    private static func baseValues(
        syncer: GenericSyncer,
        for transaction: Transaction,
        layout: Layout,
        ledgerSettings: LedgerSettings
    ) throws -> [ColumnRole: String] {
        let category = try categoryValue(for: transaction, ledgerSettings: ledgerSettings)
        let payer = try payerValue(syncer: syncer, for: transaction, layout: layout, ledgerSettings: ledgerSettings)
        return [
            .date: sheetDateFormatter.string(from: transaction.metaData.date),
            .payee: transaction.metaData.payee,
            .category: category,
            .payer: payer,
            .narration: transaction.metaData.narration
        ]
    }

    private static func formatSpecificValues(
        syncer: GenericSyncer,
        for transaction: Transaction,
        layout: Layout,
        ledgerSettings: LedgerSettings
    ) throws -> [ColumnRole: String] {
        switch layout.format {
        case .totalAmount:
            return [.amount: try totalAmountValue(syncer: syncer, for: transaction)]
        case .shareAmount:
            return [.shareOtherPerson: try shareAmountValue(syncer: syncer, for: transaction, ledgerSettings: ledgerSettings)]
        }
    }

    private static func categoryValue(
        for transaction: Transaction,
        ledgerSettings: LedgerSettings
    ) throws -> String {
        let expensePostings = transaction.postings.filter { $0.accountName.accountType == .expense }
        guard expensePostings.count == 1,
              let expensePosting = expensePostings.first
        else {
            throw SyncError.unableToFormatTransaction("Transactions must have exactly one expense posting")
        }
        return ledgerSettings.accountNameCategories[expensePosting.accountName.fullName] ?? ""
    }

    private static func payerValue(
        syncer: GenericSyncer,
        for transaction: Transaction,
        layout: Layout,
        ledgerSettings: LedgerSettings
    ) throws -> String {
        if let ownPosting = syncer.ownAccountPosting(transaction) {
            guard ownPosting.amount.number < 0 else {
                throw SyncError.unableToFormatTransaction("Owner payment posting must be negative")
            }
            return ledgerSettings.name
        }

        if let sharedPosting = syncer.sharedAccountPosting(transaction, ledgerSettings: ledgerSettings) {
            if sharedPosting.amount.number > 0 {
                return ledgerSettings.name
            }
            guard let otherPersonName = layout.otherPersonName else {
                throw SyncError.missingOtherPersonName
            }
            return otherPersonName
        }

        if let spend = syncer.moneySpend(transaction, ledgerSettings: ledgerSettings), spend.number < 0 {
            return ledgerSettings.name
        }

        guard let otherPersonName = layout.otherPersonName else {
            throw SyncError.missingOtherPersonName
        }
        return otherPersonName
    }

    private static func totalAmountValue(
        syncer: GenericSyncer,
        for transaction: Transaction
    ) throws -> String {
        guard let ownPosting = syncer.ownAccountPosting(transaction) else {
            throw SyncError.unableToFormatTransaction(
                "Cannot derive the total amount for a total-amount sheet when the owner did not pay"
            )
        }
        let amount = Amount(
            number: abs(ownPosting.amount.number),
            commoditySymbol: ownPosting.amount.commoditySymbol,
            decimalDigits: ownPosting.amount.decimalDigits
        )
        return amount.amountString
    }

    private static func shareAmountValue(
        syncer: GenericSyncer,
        for transaction: Transaction,
        ledgerSettings: LedgerSettings
    ) throws -> String {
        if let sharedPosting = syncer.sharedAccountPosting(transaction, ledgerSettings: ledgerSettings) {
            let amount = Amount(
                number: abs(sharedPosting.amount.number),
                commoditySymbol: sharedPosting.amount.commoditySymbol,
                decimalDigits: sharedPosting.amount.decimalDigits
            )
            return amount.amountString
        }

        guard let spend = syncer.moneySpend(transaction, ledgerSettings: ledgerSettings) else {
            throw SyncError.unableToFormatTransaction(
                "Cannot derive the shared amount for a share-amount sheet without a shared-account posting or payment amount"
            )
        }

        let amount = Amount(
            number: abs(spend.number) / 2,
            commoditySymbol: spend.commoditySymbol,
            decimalDigits: spend.decimalDigits
        )
        return amount.amountString
    }

}

#endif
