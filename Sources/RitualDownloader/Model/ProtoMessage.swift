// Protobuf wire decoding retains unknown fields; no generated schema is available.
import Foundation

struct ProtoField {
    let number: Int
    let wire: Int
    let integer: UInt64?
    let bytes: Data?
    let encoded: Data

    static func varint(_ number: Int, _ value: UInt64) -> Self {
        Self(number: number, wire: 0, integer: value, bytes: nil, encoded: encodeVarint(UInt64(number) << 3) + encodeVarint(value))
    }
    static func bytes(_ number: Int, _ value: Data) -> Self {
        Self(number: number, wire: 2, integer: nil, bytes: value, encoded: encodeVarint((UInt64(number) << 3) | 2) + encodeVarint(UInt64(value.count)) + value)
    }
    static func string(_ number: Int, _ value: String) -> Self { .bytes(number, Data(value.utf8)) }

    private static func encodeVarint(_ value: UInt64) -> Data {
        var remaining = value
        var output = Data()
        repeat {
            let low = UInt8(remaining & 127)
            remaining >>= 7
            output.append(remaining == 0 ? low : low | 128)
        } while remaining != 0
        return output
    }
}

struct ProtoMessage {
    let fields: [ProtoField]
    var encoded: Data { fields.reduce(into: Data()) { $0.append($1.encoded) } }

    init(fields: [ProtoField]) { self.fields = fields }

    // The wire reader keeps all bounds checks together.
    // swiftlint:disable:next function_body_length
    init(_ data: Data) throws {
        let buffer = [UInt8](data)
        var cursor = 0
        func varint() throws -> UInt64 {
            var value: UInt64 = 0
            for offset in 0..<10 {
                guard cursor < buffer.count else {
                    throw RitualDownloadError.invalidResponse("Truncated protobuf varint")
                }
                let byte = buffer[cursor]
                cursor += 1
                guard offset != 9 || byte <= 1 else {
                    throw RitualDownloadError.invalidResponse("Overflowing protobuf varint")
                }
                value |= UInt64(byte & 127) << (offset * 7)
                if byte & 128 == 0 {
                    return value
                }
            }
            throw RitualDownloadError.invalidResponse("Invalid protobuf varint")
        }
        func take(_ count: Int) throws -> Data {
            guard count >= 0, count <= buffer.count - cursor else {
                throw RitualDownloadError.invalidResponse("Truncated protobuf field")
            }
            let value = Data(buffer[cursor..<cursor + count])
            cursor += count
            return value
        }
        var fields: [ProtoField] = []
        while cursor < buffer.count {
            let start = cursor
            let tag = try varint()
            let number64 = tag >> 3
            guard number64 > 0, number64 <= 0x1fff_ffff else {
                throw RitualDownloadError.invalidResponse("Invalid protobuf field number")
            }
            let wire = Int(tag & 7)
            var integer: UInt64?
            var bytes: Data?
            switch wire {
            case 0:
                integer = try varint()
            case 1:
                bytes = try take(8)
            case 2:
                let length = try varint()
                guard length <= UInt64(buffer.count - cursor) else {
                    throw RitualDownloadError.invalidResponse("Invalid protobuf byte length")
                }
                bytes = try take(Int(length))
            case 5:
                bytes = try take(4)
            default:
                throw RitualDownloadError.invalidResponse("Unsupported protobuf wire type \(wire)")
            }
            fields.append(ProtoField(number: Int(number64), wire: wire, integer: integer, bytes: bytes, encoded: Data(buffer[start..<cursor])))
        }
        self.fields = fields
    }

    func integer(_ number: Int) -> UInt64? {
        fields.first { $0.number == number && $0.wire == 0 }?.integer
    }

    func bytes(_ number: Int) -> Data? {
        fields.first { $0.number == number && $0.wire == 2 }?.bytes
    }

    func string(_ number: Int) -> String? {
        bytes(number).flatMap { String(data: $0, encoding: .utf8) }
    }

    func message(_ number: Int) throws -> Self {
        guard let data = bytes(number) else {
            throw RitualDownloadError.invalidResponse("Missing protobuf message \(number)")
        }
        return try Self(data)
    }

    func messages(_ number: Int) throws -> [Self] {
        try fields.filter { $0.number == number && $0.wire == 2 }.map { try Self($0.bytes!) }
    }

    func text(_ path: [Int]) throws -> String? {
        guard let number = path.first else {
            return nil
        }
        if path.count == 1 {
            return string(number)
        }
        guard let bytes = bytes(number) else {
            return nil
        }
        return try Self(bytes).text(Array(path.dropFirst()))
    }

    func replacing(_ number: Int, with replacement: ProtoField?) -> Self {
        var output: [ProtoField] = []
        var inserted = false
        for field in fields {
            if field.number == number {
                if !inserted, let replacement {
                    output.append(replacement)
                }
                inserted = true
            } else {
                output.append(field)
            }
        }
        if !inserted, let replacement {
            output.append(replacement)
        }
        return Self(fields: output)
    }
}
