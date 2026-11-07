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
        _ result: LedgerResult,
        sourceIndices: [UInt32: RustLedgerSourceIndex] = [:]
    ) -> RustLedgerAssembly {
        let builder = LedgerBuilder()
        let sourceLocations = RustLedgerSourceLocations(sources: result.sources, preindexed: sourceIndices)
        let errors = result.diagnostics.filter { $0.severity.lowercased() == "error" }
        let parsingErrors = errors
            .filter { ["parse", "load", "resolve"].contains($0.phase.lowercased()) }
            .map(RustLedgerValueMapper.diagnosticMessage)
        let projected = project(result, sourceLocations: sourceLocations, into: builder)
        let validationDiagnostics = errors.filter { !["parse", "load", "resolve"].contains($0.phase.lowercased()) }
        let diagnostics = RustLedgerDiagnosticMapper.messages(
            from: validationDiagnostics,
            result: result,
            sourceLocations: sourceLocations,
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
        sourceLocations: RustLedgerSourceLocations,
        into builder: LedgerBuilder
    ) -> (transactions: RustLedgerTransactionAssembler.Result, representationErrors: [String]) {
        var diagnostics = [String]()
        RustLedgerValueMapper.addCommodities(result.directives, to: builder, diagnostics: &diagnostics)
        let unsupportedAccounts = RustLedgerValueMapper.addAccounts(
            result.directives,
            postingAccounts: result.postings.map(\.account),
            options: result.options,
            to: builder,
            diagnostics: &diagnostics
        )
        RustLedgerValueMapper.addPricesAndBalances(result.directives, to: builder, diagnostics: &diagnostics)
        let transactions = RustLedgerTransactionAssembler.addTransactions(
            result.directives,
            postings: result.postings,
            context: .init(
                unrepresentableAccounts: unsupportedAccounts,
                sourceLocations: sourceLocations
            ),
            to: builder,
            diagnostics: &diagnostics
        )
        RustLedgerValueMapper.addSimpleDirectives(result, to: builder)
        return (transactions, diagnostics)
    }
}
#endif
