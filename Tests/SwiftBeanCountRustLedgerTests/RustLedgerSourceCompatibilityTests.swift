#if RustLedger
import Foundation
@testable import SwiftBeanCountRustLedger
import SwiftBeanCountRustLedgerBindings
import Testing

@Suite
struct RustLedgerSourceCompatibilityTests {

    @Test
    func sourceIndicesKeepFileBoundariesAndInvalidOffsetBehavior() {
        let sources = [
            SourceFileRecord(id: 1, path: "first.bean", content: "é\r\n\nz"),
            SourceFileRecord(id: 2, path: "second.bean", content: "single line")
        ]
        let locations = RustLedgerSourceLocations(sources: sources)
        #expect(locations.line(sourceFileID: 1, offset: 4) == 2)
        #expect(locations.line(sourceFileID: 1, offset: 5) == 3)
        #expect(locations.line(sourceFileID: 2, offset: 5) == 1)
        #expect(locations.line(sourceFileID: 1, offset: 99) == 1)
        #expect(locations.line(sourceFileID: 1, offset: 99, clampToEnd: true) == 3)
        #expect(locations.line(sourceFileID: 1, offset: UInt64.max, clampToEnd: true) == 1)
        #expect(locations.line(sourceFileID: 99, offset: 5) == 1)
        #expect(RustLedgerSourceIndex("").position(at: 0)?.line == 1)
        #expect(RustLedgerSourceIndex("a\n").position(at: 2)?.line == 2)
    }

    @Test
    func postingAndEmptyTransactionErrorsUseAuthoredLines() {
        let source = "; é\r\n2024-01-01 * \"x\"\r\n\tAssets:Stock 1 HOOL {-10 USD}\r\n\tAssets:Cash 10 USD\r\n2024-01-02 * \"Empty\""
        let prepared = RustLedgerSourceCompatibility.prepare(source)
        let result = prepared.restore(parseSource(source: prepared.source))
        let ledger = RustParser.assemble(
            result,
            authoredSource: source,
            sourceIndices: [result.sources[0].id: prepared.sourceIndex]
        )
        #expect(ledger.parsingErrors.contains { $0.hasPrefix("Invalid Cost, negative amount:") && $0.hasSuffix("(line 3)") })
        #expect(ledger.ledgerErrors.contains("Transaction has no postings (line 5)"))
    }

    @Test
    func diagnosticLocationsMatchAuthoredUTF8Boundaries() throws {
        let source = "2024-01-01 event \"é\" \"λ\"\r\n\r\n2024-01-02 * \"Test\"\r\n\tAssets:Cash 1 USD\r\n\r\n; comment\r\n\tEquity:Opening -1 USD\r\n"
        let prepared = RustLedgerSourceCompatibility.prepare(source)
        var result = parseSource(source: prepared.source)
        let sourceID = try #require(result.sources.first?.id)
        result.diagnostics = (0...prepared.source.utf8.count).map { offset in
            DiagnosticRecord(
                phase: "validate",
                severity: "warning",
                code: "TEST",
                message: "Test location",
                sourceFileId: sourceID,
                startByte: UInt64(offset),
                endByte: UInt64(offset),
                path: nil,
                line: nil,
                column: nil
            )
        }
        let restored = prepared.restore(result)
        let bytes = Array(source.utf8)
        #expect(restored.sources.first?.content == source)
        for diagnostic in restored.diagnostics {
            let offset = Int(try #require(diagnostic.startByte))
            let preceding = bytes[..<offset]
            let lineStart = preceding.lastIndex(of: 10).map { $0 + 1 } ?? 0
            #expect(diagnostic.line == UInt32(preceding.filter { $0 == 10 }.count + 1))
            #expect(diagnostic.column == UInt32(offset - lineStart + 1))
        }
    }
}
#endif
