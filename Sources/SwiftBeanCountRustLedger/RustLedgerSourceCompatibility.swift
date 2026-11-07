#if RustLedger
import Foundation
import SwiftBeanCountRustLedgerBindings

private struct RustLedgerNormalizationBuffer {
    var output = [UInt8]()
    var boundaries = [Int]()
    var quoted = false
    var escaped = false

    mutating func appendBody(_ bytes: [UInt8], from start: Int, sourceOffset: Int) {
        var inComment = false
        for (index, byte) in bytes.enumerated() where index >= start {
            if !inComment, byte == 34, !escaped {
                quoted.toggle()
            }
            if !quoted, byte == 59 {
                inComment = true
            }
            let normalized = byte == 9 && !quoted && !inComment ? 32 : byte
            append(normalized, mappingTo: sourceOffset + index)
            escaped = byte == 92 && !escaped
            if byte != 92 {
                escaped = false
            }
        }
    }

    mutating func append(_ byte: UInt8, mappingTo originalOffset: Int) {
        if boundaries.isEmpty {
            boundaries.append(originalOffset)
        }
        output.append(byte)
        boundaries.append(originalOffset + 1)
    }

    mutating func append(_ bytes: [UInt8], mappingTo originalOffset: Int) {
        for byte in bytes {
            append(byte, mappingTo: originalOffset)
        }
    }
}

/// Applies the small amount of source normalization needed for the existing
/// parser contract while keeping Rust's source coordinates tied to authored
/// bytes. The authored source is restored in the returned source snapshot.
enum RustLedgerSourceCompatibility {

    // The source-normalization helpers are grouped by operation to keep the
    // byte mapping logic together.
    // swiftlint:disable type_contents_order
    struct PreparedSource {
        let source: String
        private let original: String
        private let normalizedBoundaryToOriginal: [Int]

        init(_ original: String) {
            self.original = original
            let normalized = Self.normalize(original)
            self.source = normalized.source
            self.normalizedBoundaryToOriginal = normalized.offsets
        }

        // swiftlint:disable function_body_length
        private static func normalize(_ original: String) -> (source: String, offsets: [Int]) {
            let input = Array(original.utf8)
            let lines = Self.lines(in: input)
            var buffer = RustLedgerNormalizationBuffer()
            var inIndentedBlock = false
            var inTransaction = false
            var hasPosting = false

            for (index, line) in lines.enumerated() {
                let lineBytes = Array(input[line.fullRange])
                if buffer.quoted {
                    buffer.appendBody(lineBytes, from: 0, sourceOffset: line.fullRange.lowerBound)
                    continue
                }

                let body = Array(input[line.bodyRange])
                let prefixCount = body.prefix { $0 == 32 || $0 == 9 }.count
                let trimmed = body.dropFirst(prefixCount)
                let isBlank = trimmed.isEmpty
                let isComment = trimmed.first == 59
                if !isBlank, !isComment, prefixCount == 0 {
                    inTransaction = Self.isTransactionHeader(trimmed)
                    hasPosting = false
                    inIndentedBlock = true
                }

                let nextIsIndented = Self.hasIndentedContent(after: index, in: lines, bytes: input)

                if isBlank || isComment, inIndentedBlock, nextIsIndented {
                    continue
                }

                if prefixCount > 0, !isBlank, !isComment {
                    let isMetadata = Self.isMetadata(trimmed)
                    let indentation = inTransaction && hasPosting && isMetadata ? 4 : 2
                    buffer.append(Array(repeating: 32, count: indentation), mappingTo: line.fullRange.lowerBound)
                    if !buffer.boundaries.isEmpty {
                        buffer.boundaries[buffer.boundaries.count - 1] = line.fullRange.lowerBound + prefixCount
                    }
                    buffer.appendBody(lineBytes, from: prefixCount, sourceOffset: line.fullRange.lowerBound)
                    if inTransaction && !isMetadata {
                        hasPosting = true
                    }
                } else {
                    buffer.appendBody(lineBytes, from: 0, sourceOffset: line.fullRange.lowerBound)
                }
            }

            if buffer.boundaries.isEmpty {
                buffer.boundaries = [0]
            } else {
                buffer.boundaries[buffer.boundaries.count - 1] = input.count
            }
            return (String(bytes: buffer.output, encoding: .utf8) ?? original, buffer.boundaries)
        }
        // swiftlint:enable function_body_length

        private static func hasIndentedContent(
            after index: Int,
            in lines: [(bodyRange: Range<Int>, fullRange: Range<Int>)],
            bytes input: [UInt8]
        ) -> Bool {
            guard let next = lines.dropFirst(index + 1).first(where: { line in
                let bytes = input[line.bodyRange]
                return !bytes.allSatisfy { $0 == 32 || $0 == 9 } && bytes.first != 59
            }) else {
                return false
            }
            let bytes = input[next.bodyRange]
            return bytes.first == 32 || bytes.first == 9
        }

        private static func isMetadata(_ bytes: ArraySlice<UInt8>) -> Bool {
            guard let colon = bytes.firstIndex(of: 58) else {
                return false
            }
            let following = bytes.index(after: colon)
            guard following == bytes.endIndex || bytes[following] == 32 || bytes[following] == 9 else {
                return false
            }
            return !bytes[..<colon].contains { $0 == 32 || $0 == 9 }
        }

        private static func isTransactionHeader(_ bytes: ArraySlice<UInt8>) -> Bool {
            let text = String(bytes: Array(bytes), encoding: .utf8) ?? ""
            let components = text.split(whereSeparator: \.isWhitespace)
            guard components.count > 1, components[0].count == 10,
                  components[0].filter({ $0 == "-" }).count == 2 else {
                return false
            }
            return components[1].count == 1
        }

        func restore(_ result: LedgerResult) -> LedgerResult {
            let rootID = result.sources.first?.id ?? 0
            return Self.restore(result, preparedByID: [rootID: self])
        }

        static func restore(_ result: LedgerResult, preparedByID: [UInt32: Self]) -> LedgerResult {
            var result = result
            result.sources = result.sources.map { file in
                guard let prepared = preparedByID[file.id] else {
                    return file
                }
                var file = file
                file.content = prepared.original
                return file
            }
            result.directives = result.directives.map { Self.mapDirective($0, preparedByID: preparedByID) }
            result.balanceDirectives = result.balanceDirectives.map { Self.mapDirective($0, preparedByID: preparedByID) }
            result.postings = result.postings.map { Self.mapPosting($0, preparedByID: preparedByID) }
            result.balancePostings = result.balancePostings.map { Self.mapPosting($0, preparedByID: preparedByID) }
            result.options = result.options.map { Self.mapOption($0, preparedByID: preparedByID) }
            result.plugins = result.plugins.map { Self.mapPlugin($0, preparedByID: preparedByID) }
            result.diagnostics = result.diagnostics.map { diagnostic in
                var diagnostic = diagnostic
                if let prepared = diagnostic.sourceFileId.flatMap({ preparedByID[$0] }) {
                    diagnostic.startByte = prepared.originalOffset(diagnostic.startByte)
                    diagnostic.endByte = prepared.originalOffset(diagnostic.endByte)
                    if let startByte = diagnostic.startByte,
                       let position = prepared.lineAndColumn(at: startByte) {
                        diagnostic.line = position.line
                        diagnostic.column = position.column
                    }
                }
                return diagnostic
            }
            return result
        }

        private static func mapDirective(_ record: DirectiveRecord, preparedByID: [UInt32: Self]) -> DirectiveRecord {
            var record = record
            if let prepared = preparedByID[record.sourceFileId] {
                record.startByte = prepared.originalOffset(record.startByte) ?? record.startByte
                record.endByte = prepared.originalOffset(record.endByte) ?? record.endByte
            }
            return record
        }

        private static func mapPosting(_ record: PostingRecord, preparedByID: [UInt32: Self]) -> PostingRecord {
            var record = record
            if let prepared = preparedByID[record.sourceFileId] {
                record.startByte = prepared.originalOffset(record.startByte) ?? record.startByte
                record.endByte = prepared.originalOffset(record.endByte) ?? record.endByte
            }
            return record
        }

        private static func mapOption(_ record: OptionRecord, preparedByID: [UInt32: Self]) -> OptionRecord {
            var record = record
            if let prepared = preparedByID[record.sourceFileId] {
                record.startByte = prepared.originalOffset(record.startByte) ?? record.startByte
                record.endByte = prepared.originalOffset(record.endByte) ?? record.endByte
            }
            return record
        }

        private static func mapPlugin(_ record: PluginRecord, preparedByID: [UInt32: Self]) -> PluginRecord {
            var record = record
            if let prepared = preparedByID[record.sourceFileId] {
                record.startByte = prepared.originalOffset(record.startByte) ?? record.startByte
                record.endByte = prepared.originalOffset(record.endByte) ?? record.endByte
            }
            return record
        }

        private func originalOffset(_ value: UInt64?) -> UInt64? {
            guard let value, let offset = Int(exactly: value), normalizedBoundaryToOriginal.indices.contains(offset) else {
                return nil
            }
            return UInt64(normalizedBoundaryToOriginal[offset])
        }

        private func lineAndColumn(at value: UInt64) -> (line: UInt32, column: UInt32)? {
            let bytes = Array(original.utf8)
            guard let offset = Int(exactly: value), offset <= bytes.count,
                  let line = UInt32(exactly: bytes[..<offset].filter { $0 == 10 }.count + 1) else {
                return nil
            }
            let lineStart = bytes[..<offset].lastIndex(of: 10).map { $0 + 1 } ?? 0
            guard let column = UInt32(exactly: offset - lineStart + 1) else {
                return nil
            }
            return (line, column)
        }

        private static func lines(in bytes: [UInt8]) -> [(bodyRange: Range<Int>, fullRange: Range<Int>)] {
            guard !bytes.isEmpty else {
                return []
            }
            var result = [(Range<Int>, Range<Int>)]()
            var start = 0
            for index in bytes.indices where bytes[index] == 10 {
                let bodyEnd = index > start && bytes[index - 1] == 13 ? index - 1 : index
                result.append((start..<bodyEnd, start..<(index + 1)))
                start = index + 1
            }
            if start < bytes.count {
                result.append((start..<bytes.count, start..<bytes.count))
            }
            return result
        }
    }
    // swiftlint:enable type_contents_order

    static func prepare(_ source: String) -> PreparedSource {
        PreparedSource(source)
    }
}
#endif
