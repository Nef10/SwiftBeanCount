#if RustLedger
import SwiftBeanCountRustLedgerBindings

/// Authored UTF-8 positions shared by every diagnostic and posting lookup.
struct RustLedgerSourceIndex {
    private let byteCount: Int
    private let lineStarts: [Int]

    init(_ source: String) {
        byteCount = source.utf8.count
        var starts = [0]
        for (offset, byte) in source.utf8.enumerated() where byte == 10 {
            starts.append(offset + 1)
        }
        lineStarts = starts
    }

    func position(at sourceOffset: UInt64, clampToEnd: Bool = false) -> (line: Int, column: Int)? {
        guard let sourceOffset = Int(exactly: sourceOffset) else {
            return nil
        }
        let offset = clampToEnd ? min(sourceOffset, byteCount) : sourceOffset
        guard offset <= byteCount else {
            return nil
        }
        var lower = 0
        var upper = lineStarts.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if lineStarts[middle] <= offset {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return (lower, offset - lineStarts[lower - 1] + 1)
    }
}

struct RustLedgerSourceLocations {
    private let indices: [UInt32: RustLedgerSourceIndex]

    init(sources: [SourceFileRecord], preindexed: [UInt32: RustLedgerSourceIndex] = [:]) {
        var indices = preindexed
        for source in sources where indices[source.id] == nil {
            indices[source.id] = RustLedgerSourceIndex(source.content)
        }
        self.indices = indices
    }

    func line(sourceFileID: UInt32, offset: UInt64, clampToEnd: Bool = false) -> Int {
        indices[sourceFileID]?.position(at: offset, clampToEnd: clampToEnd)?.line ?? 1
    }
}
#endif
