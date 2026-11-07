#if RustLedger
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountRustLedgerBindings

enum RustLedgerTransactionAssembler {

    struct Result {
        let weights: [ProcessedPostingWeight]
        let transactionsByDirectiveID: [String: Transaction]
    }

    struct Context {
        let unrepresentableAccounts: Set<String>
        let sourceContents: [UInt32: String]

        func line(for directive: DirectiveRecord) -> Int {
            line(sourceFileID: directive.sourceFileId, offset: directive.startByte)
        }

        func line(for posting: PostingRecord) -> Int {
            line(sourceFileID: posting.sourceFileId, offset: posting.startByte)
        }

        private func line(sourceFileID: UInt32, offset sourceOffset: UInt64) -> Int {
            guard let source = sourceContents[sourceFileID],
                  let offset = Int(exactly: sourceOffset), offset <= source.utf8.count else {
                return 1
            }
            return source.utf8.prefix(offset).filter { $0 == 10 }.count + 1
        }
    }

    private struct TransactionProjection {
        let transaction: Transaction
        let weights: [ProcessedPostingWeight]
    }

    static func addTransactions(
        _ directives: [DirectiveRecord],
        postings: [PostingRecord],
        context: Context,
        to builder: LedgerBuilder,
        diagnostics: inout [String]
    ) -> Result {
        let postingsByDirective = Dictionary(grouping: postings, by: \.sourceDirectiveId)
        var weights = [ProcessedPostingWeight]()
        var transactionsByDirectiveID = [String: Transaction]()
        for directive in directives where directive.kind.lowercased() == "transaction" {
            let records = postingsByDirective[directive.recordId] ?? []
            guard let projection = makeTransaction(
                directive,
                postings: records,
                context: context,
                diagnostics: &diagnostics
            ) else {
                continue
            }
            builder.add(projection.transaction)
            weights.append(contentsOf: projection.weights)
            transactionsByDirectiveID[directive.recordId] = projection.transaction
        }
        return Result(weights: weights, transactionsByDirectiveID: transactionsByDirectiveID)
    }

    private static func makeTransaction(
        _ directive: DirectiveRecord,
        postings: [PostingRecord],
        context: Context,
        diagnostics: inout [String]
    ) -> TransactionProjection? {
        guard let date = RustLedgerValueMapper.date(from: directive) else {
            diagnostics.append("RustLedger returned a transaction with an invalid date (\(RustLedgerValueMapper.sourceLocation(directive))).")
            return nil
        }
        guard let flag = transactionFlag(directive) else {
            diagnostics.append("RustLedger returned an unsupported transaction flag at \(RustLedgerValueMapper.sourceLocation(directive)).")
            return nil
        }
        guard let projectedPostings = makePostings(
            directive,
            postings: postings,
            context: context,
            diagnostics: &diagnostics
        ) else {
            return nil
        }
        let transactionMetadata = transactionMetadata(directive, date: date, flag: flag)
        let transaction = Transaction(metaData: transactionMetadata, postings: projectedPostings.postings)
        let weights = makeWeights(transaction.postings, records: projectedPostings.records, diagnostics: &diagnostics)
        return TransactionProjection(transaction: transaction, weights: weights)
    }

    private static func makePostings(
        _ directive: DirectiveRecord,
        postings: [PostingRecord],
        context: Context,
        diagnostics: inout [String]
    ) -> (records: [PostingRecord], postings: [Posting])? {
        let byID = Dictionary(uniqueKeysWithValues: postings.map { ($0.recordId, $0) })
        var records = [PostingRecord]()
        var sourcePostings = [Posting]()
        for postingID in directive.postingIds {
            guard let record = byID[postingID] else {
                diagnostics.append("RustLedger omitted processed posting \(postingID) from transaction \(directive.recordId).")
                return nil
            }
            guard let posting = makePosting(
                record,
                sourceLine: context.line(for: record),
                transaction: directive,
                unrepresentableAccounts: context.unrepresentableAccounts,
                diagnostics: &diagnostics
            ) else {
                continue
            }
            records.append(record)
            sourcePostings.append(posting)
        }
        return (records, sourcePostings)
    }

    private static func transactionMetadata(
        _ directive: DirectiveRecord,
        date: Date,
        flag: Flag
    ) -> TransactionMetaData {
        TransactionMetaData(
            date: date,
            payee: directive.payee ?? "",
            narration: directive.narration ?? "",
            flag: flag,
            tags: directive.tags.map { tag in
                Tag(name: tag.hasPrefix("#") ? String(tag.dropFirst()) : tag)
            },
            metaData: RustLedgerValueMapper.metadata(directive.metadata)
        )
    }

    private static func makeWeights(
        _ postings: [TransactionPosting],
        records: [PostingRecord],
        diagnostics: inout [String]
    ) -> [ProcessedPostingWeight] {
        zip(postings, records).compactMap { posting, record -> ProcessedPostingWeight? in
            guard let weight = try? RustLedgerValueMapper.exactWeight(record.exactWeight) else {
                diagnostics.append("RustLedger did not return an exact accounting weight for posting \(record.recordId).")
                return nil
            }
            return ProcessedPostingWeight(posting: posting, amount: weight)
        }
    }

    private static func makePosting(
        _ record: PostingRecord,
        sourceLine: @autoclosure () -> Int,
        transaction: DirectiveRecord,
        unrepresentableAccounts: Set<String>,
        diagnostics: inout [String]
    ) -> Posting? {
        guard let account = try? AccountName(record.account), let units = try? RustLedgerValueMapper.amount(record.units) else {
            let location = RustLedgerValueMapper.sourceLocation(transaction)
            diagnostics.append("Transaction at \(location) has an unavailable or unrepresentable posting in \(record.account).")
            return nil
        }
        guard !unrepresentableAccounts.contains(record.account) else {
            diagnostics.append("Posting in account \(record.account) cannot be represented by the Swift model.")
            return nil
        }
        let cost: Cost?
        do {
            cost = try makeCost(record)
        } catch {
            diagnostics.append("\(swiftCostErrorDescription(record, original: error.localizedDescription)) (line \(sourceLine()))")
            return nil
        }
        return makeModelPosting(record, account: account, units: units, cost: cost, diagnostics: &diagnostics)
    }

    private static func makeCost(_ record: PostingRecord) throws -> Cost? {
        guard record.hasCost || record.cost != nil || record.costDate != nil || record.costLabel != nil else {
            return nil
        }
        let amount = try? RustLedgerValueMapper.amount(record.cost)
        return try Cost(amount: amount, date: record.costDate.flatMap(RustLedgerValueMapper.parseDate), label: record.costLabel)
    }

    private static func swiftCostErrorDescription(_ record: PostingRecord, original: String) -> String {
        guard let amount = try? RustLedgerValueMapper.amount(record.cost) else {
            return original
        }
        do {
            _ = try Cost(amount: amount, date: nil, label: nil)
            return original
        } catch {
            return error.localizedDescription
        }
    }

    private static func makeModelPosting(
        _ record: PostingRecord,
        account: AccountName,
        units: Amount,
        cost: Cost?,
        diagnostics: inout [String]
    ) -> Posting? {
        let price = try? RustLedgerValueMapper.amount(record.price)
        let priceType = postingPriceType(record)
        do {
            let posting = try Posting(
                accountName: account,
                amount: units,
                price: price,
                priceType: priceType,
                cost: cost,
                metaData: RustLedgerValueMapper.metadata(record.metadata)
            )
            if let flag = record.flag {
                diagnostics.append("Posting flag \(flag) at \(sourceLocation(record)) is not represented by the Swift posting model.")
            }
            return posting
        } catch {
            diagnostics.append("RustLedger could not represent posting \(record.recordId): \(error.localizedDescription)")
            return nil
        }
    }

    private static func postingPriceType(_ record: PostingRecord) -> PostingPriceType? {
        guard record.price != nil else {
            return nil
        }
        return record.priceIsTotal ? .total : .perUnit
    }

    private static func transactionFlag(_ directive: DirectiveRecord) -> Flag? {
        if directive.flag == "P", directive.synthetic {
            return .complete
        }
        return directive.flag.flatMap(Flag.init(rawValue:))
    }

    private static func sourceLocation(_ record: PostingRecord) -> String {
        "source \(record.sourceFileId) bytes \(record.startByte)-\(record.endByte)"
    }

}
#endif
