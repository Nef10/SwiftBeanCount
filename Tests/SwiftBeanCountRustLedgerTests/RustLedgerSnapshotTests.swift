#if RustLedger
import Foundation
import SwiftBeanCountParser
@testable import SwiftBeanCountRustLedger
import Testing

private struct IncludedSourceFiles {
    let root: URL
    let child: URL
    let cleanup: () -> Void
}

@Suite
struct RustLedgerSnapshotTests {

    @Test
    func reparsingSourceChangesKeepsQuotedDirectivesAndPreviousSnapshot() {
        let authoredOption = "option \"title\" \"A \\\"quoted\\\" \\\\ path\""
        let authoredCustom = "2024-01-01 custom \"setting\" TRUE 42 Assets:Cash"
        let original = Parser.parse(string: "\(authoredOption)\n\(authoredCustom)\n")
        let updatedSource = "\(authoredOption)\n\(authoredCustom)\n2024-01-02 custom \"extra\" \"kept\"\n"
        let updated = Parser.parse(string: updatedSource)

        #expect(original.custom.count == 1)
        #expect(updated.custom.count == 2)
        #expect(original.description.contains(authoredOption))
        #expect(original.description.contains(authoredCustom))
        #expect(updated.errors.isEmpty)
    }

    @Test
    func includedDirectivesRemainInTheirSourceSnapshot() throws {
        let files = try includedSourceFiles()
        defer { files.cleanup() }
        let original = try Parser.parse(contentOf: files.root)
        try "2024-01-01 event \"location\" \"Victoria\"\n".write(to: files.child, atomically: true, encoding: .utf8)
        let updated = try Parser.parse(contentOf: files.root)

        #expect(original.events.map(\.value) == ["Vancouver"])
        #expect(updated.events.map(\.value) == ["Victoria"])
        #expect(original.retainedSourceDescription == "include \"child.bean\"\n")
        let transaction = try #require(original.transactions.first)
        #expect(original.transactions.count == 1)
        #expect(updated.transactions.isEmpty)
        #expect(transaction.postings.count == 2)
        #expect(try transaction.balance(in: original).isZeroWithTolerance())
        #expect(original.errors.isEmpty)
        #expect(updated.errors.isEmpty)
    }
}

private func includedSourceFiles() throws -> IncludedSourceFiles {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let root = directory.appendingPathComponent("main.bean")
    let child = directory.appendingPathComponent("child.bean")
    let source = """
    2024-01-01 event "location" "Vancouver"
    2024-01-01 open Assets:Cash USD
    2024-01-01 open Equity:Opening USD
    2024-01-02 * "Opening"
      Assets:Cash 1 USD
      Equity:Opening -1 USD
    """
    try source.write(to: child, atomically: true, encoding: .utf8)
    try "include \"child.bean\"\n".write(to: root, atomically: true, encoding: .utf8)
    let cleanup: () -> Void = { _ = try? FileManager.default.removeItem(at: directory) }
    return IncludedSourceFiles(root: root, child: child, cleanup: cleanup)
}

#endif
