#if RustLedger
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountRustLedgerBindings

struct RustLedgerAssembly {
    let builder: LedgerBuilder
    let diagnostics: [String]
    let exactWeights: [ProcessedPostingWeight]
}

/// Projects rustledger's already-processed records into SwiftBeanCount's
/// existing model. This file does no parsing, booking, or validation.
enum RustLedgerAssembler {

    static func assemble(
        _ result: LedgerResult
    ) -> RustLedgerAssembly {
        let builder = LedgerBuilder()
        let errors = result.diagnostics.filter { $0.severity.lowercased() == "error" }
        let parsingErrors = errors
            .filter { ["parse", "load", "resolve"].contains($0.phase.lowercased()) }
            .map(RustLedgerValueMapper.diagnosticMessage)
        let projected = project(result, into: builder)
        let validationDiagnostics = errors.filter { !["parse", "load", "resolve"].contains($0.phase.lowercased()) }
        let diagnostics = RustLedgerDiagnosticMapper.messages(
            from: validationDiagnostics,
            result: result,
            transactionsByDirectiveID: projected.transactions.transactionsByDirectiveID
        )
        let allParsingErrors = parsingErrors + projected.representationErrors
        builder.parsingErrors.append(contentsOf: allParsingErrors)
        return RustLedgerAssembly(
            builder: builder,
            diagnostics: diagnostics,
            exactWeights: projected.transactions.weights
        )
    }

    private static func project(
        _ result: LedgerResult,
        into builder: LedgerBuilder
    ) -> (transactions: RustLedgerTransactionAssembler.Result, representationErrors: [String]) {
        var diagnostics = [String]()
        RustLedgerValueMapper.addCommodities(result.balanceDirectives, to: builder, diagnostics: &diagnostics)
        let unsupportedAccounts = RustLedgerValueMapper.addAccounts(
            result.balanceDirectives,
            postingAccounts: result.balancePostings.map(\.account),
            options: result.options,
            to: builder,
            diagnostics: &diagnostics
        )
        RustLedgerValueMapper.addPricesAndBalances(result.balanceDirectives, to: builder, diagnostics: &diagnostics)
        let transactions = RustLedgerTransactionAssembler.addTransactions(
            result.balanceDirectives,
            postings: result.balancePostings,
            context: .init(
                unrepresentableAccounts: unsupportedAccounts,
                sourceContents: Dictionary(uniqueKeysWithValues: result.sources.map { ($0.id, $0.content) })
            ),
            to: builder,
            diagnostics: &diagnostics
        )
        RustLedgerValueMapper.addSimpleDirectives(result, to: builder)
        return (transactions, diagnostics)
    }
}
#endif
