#if RustLedger
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountRustLedgerBindings

/// Renders a narrow set of rustledger diagnostics using SwiftBeanCount's
/// established public wording. The Rust records remain the source of truth;
/// only known differences in implicit-account and plugin presentation are
/// translated here.
enum RustLedgerDiagnosticMapper {

    static func messages(
        from records: [DiagnosticRecord],
        result: LedgerResult,
        sourceLocations: RustLedgerSourceLocations,
        transactionsByDirectiveID: [String: Transaction]
    ) -> [String] {
        let errors = records.filter { $0.severity.lowercased() == "error" }
        let implicitAccountErrors = errors.filter { $0.message.contains(" was never opened") }
        let visible = errors.filter { record in
            !implicitAccountErrors.contains(record) && commodityMessage(record, result: result) == nil
        }
        let transactionMessages = visible.compactMap { transactionMessage($0, result: result, transactionsByDirectiveID: transactionsByDirectiveID) }
        let ordinaryMessages = visible.filter { transactionMessage($0, result: result, transactionsByDirectiveID: transactionsByDirectiveID) == nil }
            .map(RustLedgerValueMapper.diagnosticMessage)
        let pluginMessages = errors.compactMap { commodityMessage($0, result: result) }
        return transactionMessages + ordinaryMessages + pluginMessages + structuralMessages(in: result, sourceLocations: sourceLocations)
    }

    private static func structuralMessages(in result: LedgerResult, sourceLocations: RustLedgerSourceLocations) -> [String] {
        result.directives.compactMap { directive -> String? in
            guard directive.kind.lowercased() == "transaction", directive.postingIds.isEmpty else {
                return nil
            }
            let line = sourceLocations.line(sourceFileID: directive.sourceFileId, offset: directive.startByte, clampToEnd: true)
            return "Transaction has no postings (line \(line))"
        }
    }

    static func accountStructureMessages(
        _ name: String,
        openings: [DirectiveRecord],
        closings: [DirectiveRecord]
    ) -> [String] {
        var messages = [String]()
        if openings.isEmpty, !closings.isEmpty {
            messages.append("Account \(name) is closed without an opening declaration.")
        }
        if openings.count > 1 {
            messages.append("Account \(name) has multiple opening declarations.")
        }
        if closings.count > 1 {
            messages.append("Account \(name) has multiple closing declarations.")
        }
        return messages
    }

    private static func isMissingCommodityDiagnostic(_ record: DiagnosticRecord) -> Bool {
        record.message.hasPrefix("Missing Commodity directive for '")
    }

    private static func commodityMessage(_ record: DiagnosticRecord, result: LedgerResult) -> String? {
        guard isMissingCommodityDiagnostic(record),
              result.plugins.contains(where: { $0.name == "beancount.plugins.check_commodity" }),
              let symbol = record.message.split(separator: "'").dropFirst().first else {
            return nil
        }
        return "Commodity \(symbol) does not have an opening date"
    }

    private static func transactionMessage(
        _ record: DiagnosticRecord,
        result: LedgerResult,
        transactionsByDirectiveID: [String: Transaction]
    ) -> String? {
        guard record.message.hasPrefix("Transaction does not balance: residual "),
              let sourceFileID = record.sourceFileId,
              let startByte = record.startByte,
              let directive = result.directives.first(where: {
                  $0.sourceFileId == sourceFileID && $0.startByte == startByte && $0.kind.lowercased() == "transaction"
              }),
              let transaction = transactionsByDirectiveID[directive.recordId],
              let detail = balanceDetail(record.message, directive: directive, result: result) else {
            return nil
        }
        return "\(transaction) is not balanced - \(detail)"
    }

    private static func balanceDetail(_ message: String, directive: DirectiveRecord, result: LedgerResult) -> String? {
        let parts = message.split(separator: " ")
        guard parts.count >= 7, let rawNumber = parts[5].split(separator: "/").first,
              let value = Decimal(string: String(rawNumber), locale: Locale(identifier: "en_US_POSIX")),
              let currencyPart = parts[6].split(separator: "/").first else {
            return nil
        }
        let currency = String(currencyPart)
        guard !usesCustomTolerance(result.options) else {
            return nil
        }
        let weights = result.postings.filter { $0.sourceDirectiveId == directive.recordId }
        guard !weights.isEmpty,
              weights.allSatisfy({ posting in
                  guard let units = posting.units, let weight = posting.exactWeight else {
                      return false
                  }
                  return !posting.hasCost && posting.price == nil && units.currency == currency && weight.currency == currency
              }),
              let digits = swiftPrecision(weights.compactMap { $0.exactWeight.flatMap { Int(exactly: $0.scale) } }) else {
            return nil
        }
        let normalized = normalizedNumber(value)
        guard digits > 0 else {
            return "\(normalized) \(currency) too much"
        }
        let tolerance = decimalString(Decimal(sign: .plus, exponent: -digits - 1, significand: 5))
        return "\(normalized) \(currency) too much (\(tolerance) tolerance)"
    }

    private static func usesCustomTolerance(_ options: [OptionRecord]) -> Bool {
        options.contains { ["inferred_tolerance_default", "inferred_tolerance_max", "tolerance"].contains($0.name) }
    }

    private static func swiftPrecision(_ scales: [Int]) -> Int? {
        scales.reduce(nil as Int?) { current, next in
            guard next >= 0 else {
                return nil
            }
            guard let current else {
                return next
            }
            return current == 0 || next == 0 ? 0 : max(current, next)
        }
    }

    private static func normalizedNumber(_ value: Decimal) -> String {
        var mutableValue = value
        var text = NSDecimalString(&mutableValue, Locale(identifier: "en_US_POSIX"))
        while text.contains("."), text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text == "-0" ? "0" : text
    }

    private static func decimalString(_ value: Decimal) -> String {
        var mutableValue = value
        return NSDecimalString(&mutableValue, Locale(identifier: "en_US_POSIX"))
    }
}
#endif
