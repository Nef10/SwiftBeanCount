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

    private struct UploadRenderingContext {
        let expenseAmount: Amount
        let category: String
        let totalExpenseAmount: Decimal
    }

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
                let renderedRows = try renderedRows(
                    syncer: syncer,
                    for: transaction,
                    layout: layout,
                    ledgerSettings: ledgerSettings
                )
                guard !renderedRows.isEmpty else {
                    continue
                }
                rows += renderedRows
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

    private static func renderedRows(
        syncer: GenericSyncer,
        for transaction: Transaction,
        layout: Layout,
        ledgerSettings: LedgerSettings
    ) throws -> [[String]] {
        let contexts = try uploadRenderingContexts(for: transaction, ledgerSettings: ledgerSettings)
        return try contexts.map { context in
            let values = try renderedValues(
                syncer: syncer,
                for: transaction,
                context: context,
                layout: layout,
                ledgerSettings: ledgerSettings
            )
            return layout.columns.map { values[$0.role, default: ""] }
        }
    }

    private static func renderedValues(
        syncer: GenericSyncer,
        for transaction: Transaction,
        context: UploadRenderingContext,
        layout: Layout,
        ledgerSettings: LedgerSettings
    ) throws -> [ColumnRole: String] {
        let baseValues = try baseValues(
            syncer: syncer,
            for: transaction,
            context: context,
            layout: layout,
            ledgerSettings: ledgerSettings
        )
        let specificValues = try formatSpecificValues(
            syncer: syncer,
            for: transaction,
            context: context,
            layout: layout,
            ledgerSettings: ledgerSettings
        )
        return baseValues.merging(specificValues) { current, _ in current }
    }

    private static func baseValues(
        syncer: GenericSyncer,
        for transaction: Transaction,
        context: UploadRenderingContext,
        layout: Layout,
        ledgerSettings: LedgerSettings
    ) throws -> [ColumnRole: String] {
        let payer = try payerValue(syncer: syncer, for: transaction, layout: layout, ledgerSettings: ledgerSettings)
        return [
            .date: sheetDateFormatter.string(from: transaction.metaData.date),
            .payee: transaction.metaData.payee,
            .category: context.category,
            .payer: payer,
            .narration: transaction.metaData.narration
        ]
    }

    private static func formatSpecificValues(
        syncer: GenericSyncer,
        for transaction: Transaction,
        context: UploadRenderingContext,
        layout: Layout,
        ledgerSettings: LedgerSettings
    ) throws -> [ColumnRole: String] {
        switch layout.format {
        case .totalAmount:
            return [
                .amount: try totalAmountValue(
                    syncer: syncer,
                    for: transaction,
                    expenseAmount: context.expenseAmount,
                    totalExpenseAmount: context.totalExpenseAmount,
                    ledgerSettings: ledgerSettings
                )
            ]
        case .shareAmount:
            return [
                .shareOtherPerson: try shareAmountValue(
                    syncer: syncer,
                    for: transaction,
                    expenseAmount: context.expenseAmount,
                    totalExpenseAmount: context.totalExpenseAmount,
                    ledgerSettings: ledgerSettings
                )
            ]
        }
    }

    private static func uploadRenderingContexts(
        for transaction: Transaction,
        ledgerSettings: LedgerSettings
    ) throws -> [UploadRenderingContext] {
        let expensePostings = transaction.postings.filter { $0.accountName.accountType == .expense }
        guard !expensePostings.isEmpty else {
            throw SyncError.unableToFormatTransaction("Transactions must have at least one expense posting")
        }
        let totalExpenseAmount = expensePostings.reduce(Decimal.zero) { $0 + $1.amount.number }
        if expensePostings.count == 1, let posting = expensePostings.first {
            return [
                UploadRenderingContext(
                    expenseAmount: posting.amount,
                    category: ledgerSettings.accountNameCategories[posting.accountName.fullName, default: ""],
                    totalExpenseAmount: totalExpenseAmount
                )
            ]
        }

        return expensePostings.compactMap { posting in
            if let category = ledgerSettings.accountNameCategories[posting.accountName.fullName] {
                return UploadRenderingContext(
                    expenseAmount: posting.amount,
                    category: category,
                    totalExpenseAmount: totalExpenseAmount
                )
            }
            return nil
        }
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
        for transaction: Transaction,
        expenseAmount: Amount,
        totalExpenseAmount: Decimal,
        ledgerSettings: LedgerSettings
    ) throws -> String {
        guard let ownPosting = syncer.ownAccountPosting(transaction),
              let amount = syncer.amountInSheetCurrency(ownPosting, ledgerSettings: ledgerSettings)
        else {
            throw SyncError.unableToFormatTransaction(
                "Cannot derive the total amount for a total-amount sheet when the owner did not pay"
            )
        }
        return proportionalAmountString(
            sourceAmount: amount,
            expenseAmount: expenseAmount,
            totalExpenseAmount: totalExpenseAmount
        )
    }

    private static func shareAmountValue(
        syncer: GenericSyncer,
        for transaction: Transaction,
        expenseAmount: Amount,
        totalExpenseAmount: Decimal,
        ledgerSettings: LedgerSettings
    ) throws -> String {
        if let sharedPosting = syncer.sharedAccountPosting(transaction, ledgerSettings: ledgerSettings) {
            guard let amount = syncer.amountInSheetCurrency(sharedPosting, ledgerSettings: ledgerSettings) else {
                throw SyncError.unableToFormatTransaction(
                    "Cannot derive the shared amount for a share-amount sheet in the sheet currency"
                )
            }
            return proportionalAmountString(
                sourceAmount: amount,
                expenseAmount: expenseAmount,
                totalExpenseAmount: totalExpenseAmount
            )
        }

        guard let spend = syncer.moneySpend(transaction, ledgerSettings: ledgerSettings) else {
            throw SyncError.unableToFormatTransaction(
                "Cannot derive the shared amount for a share-amount sheet without a shared-account posting or payment amount"
            )
        }

        let amount = Amount(
            number: proportionalAmount(
                sourceNumber: spend.number,
                expenseNumber: expenseAmount.number,
                totalExpenseAmount: totalExpenseAmount
            ) / 2,
            commoditySymbol: spend.commoditySymbol,
            decimalDigits: spend.decimalDigits
        )
        return amount.amountString
    }

    private static func proportionalAmountString(
        sourceAmount: Amount,
        expenseAmount: Amount,
        totalExpenseAmount: Decimal
    ) -> String {
        let amount = Amount(
            number: proportionalAmount(
                sourceNumber: sourceAmount.number,
                expenseNumber: expenseAmount.number,
                totalExpenseAmount: totalExpenseAmount
            ),
            commoditySymbol: sourceAmount.commoditySymbol,
            decimalDigits: sourceAmount.decimalDigits
        )
        return amount.amountString
    }

    private static func proportionalAmount(
        sourceNumber: Decimal,
        expenseNumber: Decimal,
        totalExpenseAmount: Decimal
    ) -> Decimal {
        guard totalExpenseAmount != .zero else {
            return abs(sourceNumber)
        }
        return abs(sourceNumber) * expenseNumber / totalExpenseAmount
    }

}

#endif
