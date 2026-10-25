import Foundation
import Testing

@testable import RitualDownloader

private func responseFixture(_ name: String) throws -> Data {
    try Data(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Fixtures/" + name))
}

private func messageByReplacing(_ message: ProtoMessage, path: [Int], with replacement: ProtoField?) throws -> ProtoMessage {
    guard let number = path.first else {
        return message
    }
    if path.count == 1 {
        return message.replacing(number, with: replacement)
    }
    let child = try message.message(number)
    let updated = try messageByReplacing(child, path: Array(path.dropFirst()), with: replacement)
    return message.replacing(number, with: .bytes(number, updated.encoded))
}

@Suite
struct RitualResponseValidationTests {
    @Test
    func malformedResponseStructuresAreRejected() throws {
        let id = String(repeating: "a", count: 32)
        let history = try ProtoMessage(responseFixture("history-1.pb"))
        let receipt = try ProtoMessage(responseFixture("receipt-a.pb"))

        #expect(throws: RitualDownloadError.self) {
            _ = try RitualResponseDecoder.history(history.replacing(6, with: .varint(6, 42)).encoded)
        }
        #expect(throws: RitualDownloadError.self) {
            let value = try messageByReplacing(history, path: [49, 1], with: .string(1, "other"))
            _ = try RitualResponseDecoder.history(value.encoded)
        }
        #expect(throws: RitualDownloadError.self) {
            let value = try messageByReplacing(history, path: [49, 2, 1, 1, 90, 8], with: nil)
            _ = try RitualResponseDecoder.history(value.encoded)
        }
        #expect(throws: RitualDownloadError.self) {
            _ = try RitualResponseDecoder.receipt(receipt.replacing(6, with: .varint(6, 200)).encoded, receiptID: id)
        }
        #expect(throws: RitualDownloadError.self) {
            let value = try messageByReplacing(receipt, path: [212, 1, 3, 2, 1, 1], with: .string(1, "0"))
            _ = try RitualResponseDecoder.receipt(value.encoded, receiptID: id)
        }
        #expect(throws: RitualDownloadError.self) {
            let value = try messageByReplacing(receipt, path: [212, 1, 3, 2, 2], with: nil)
            _ = try RitualResponseDecoder.receipt(value.encoded, receiptID: id)
        }

        let value = try messageByReplacing(receipt, path: [212, 1, 4, 1, 1, 1], with: nil)
        #expect(try RitualResponseDecoder.receipt(value.encoded, receiptID: id).totals.isEmpty)
    }
}
