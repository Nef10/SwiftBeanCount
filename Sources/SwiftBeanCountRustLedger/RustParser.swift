#if RustLedger
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountRustLedgerBindings
#if canImport(OSLog)
import OSLog
#endif

/// The only bridge from the parser facade to rustledger. Every public parse
/// operation goes through the complete loader, including booking and validation.
package enum RustParser {

    package static func parse(string: String) -> Ledger {
        let prepared = RustLedgerSourceCompatibility.prepare(string)
        let loaded = loadText(source: prepared.source, sourcePath: nil)
        return assemble(
            prepared.restore(loaded),
            authoredSource: string,
            sourceIndices: [loaded.sources.first?.id ?? 0: prepared.sourceIndex]
        )
    }

    package static func parse(contentOf path: URL) throws -> Ledger {
        // Preserve the established root-file read error behavior and UTF-8
        // contract before asking rustledger to resolve the full include graph.
        _ = try String(contentsOf: path)
        let sources = try readSourceFiles(path: path.path)
        let preparedByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, RustLedgerSourceCompatibility.prepare($0.content)) })
        let preparedSources = sources.map { source in
            SourceFileRecord(id: source.id, path: source.path, content: preparedByID[source.id]?.source ?? source.content)
        }
        let rootSource = sources.first { $0.path == path.path } ?? sources.first
        let result = loadSources(sources: preparedSources, rootPath: rootSource?.path ?? path.path)
        let restored = RustLedgerSourceCompatibility.PreparedSource.restore(result, preparedByID: preparedByID)
        return assemble(restored, authoredSource: rootSource?.content, sourceIndices: preparedByID.mapValues(\.sourceIndex))
    }

    static func assemble(
        _ result: LedgerResult,
        authoredSource: String?,
        sourceIndices: [UInt32: RustLedgerSourceIndex] = [:]
    ) -> Ledger {
        let assembly = RustLedgerAssembler.assemble(result, sourceIndices: sourceIndices)
        let projection = ProcessedLedgerProjection(
            diagnostics: assembly.diagnostics,
            exactWeights: assembly.exactWeights,
            sourceDescription: authoredSource ?? result.sources.first?.content
        )
        emitWarnings(in: result)
        return assembly.builder.build(processed: projection)
    }

    private static func emitWarnings(in result: LedgerResult) {
        #if canImport(OSLog)
        let logger = Logger(subsystem: "org.swiftbeancount", category: "RustLedger")
        for diagnostic in result.diagnostics where diagnostic.severity.lowercased() == "warning" {
            logger.warning("[\(diagnostic.code, privacy: .public)] \(diagnostic.message, privacy: .public)")
        }
        #else
        _ = result
        #endif
    }
}
#endif
